local engine = require("smart_highlighter.core.engine")
local config = require("smart_highlighter.config")

local M = {}

---@type string? Currently loaded project root directory
M.current_loaded_root = nil

---@type string? Currently loaded git branch name
M.current_loaded_branch = nil

---@type userdata? UV timer for debounced auto-save
local auto_save_timer = nil

---@type userdata? UV fs_event watcher for .git
local head_watcher = nil

---@type userdata? UV timer for debounced branch switch
local switch_debounce_timer = nil

---Get session storage directory path in stdpath("state")
---@return string
local function get_storage_dir()
  local base = vim.fn.stdpath("state") .. "/smart-highlighter"
  if vim.fn.isdirectory(base) == 0 then
    vim.fn.mkdir(base, "p")
  end
  return base
end

---Sanitize branch/string for safe filesystem path
---@param name string
---@return string
local function sanitize_name(name)
  return (name:gsub("[^%w%._%-]", "_"))
end

---Find root directory of the current repository/project
---@param start_path? string Optional file or directory path
---@return string root_dir
function M.find_project_root(start_path)
  start_path = start_path or vim.api.nvim_buf_get_name(0)
  if not start_path or start_path == "" then
    start_path = vim.fn.getcwd()
  end

  local root = vim.fs.root(start_path, {
    ".git",
    ".hg",
    ".svn",
    ".smart-highlighter.json",
    ".smart-bookmarks.json",
    ".smart-bookmarks-highlighter.json",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "pyproject.toml",
  })

  return root or vim.fn.getcwd()
end

---Resolve the real .git directory path (supports standard repos, worktrees, submodules)
---@param root string
---@return string? git_dir
function M.resolve_git_dir(root)
  local git_path = root .. "/.git"
  local stat = vim.uv.fs_stat(git_path)
  if not stat then
    return nil
  end
  if stat.type == "directory" then
    return git_path
  elseif stat.type == "file" then
    local f = io.open(git_path, "r")
    if f then
      local line = f:read("*l") or ""
      f:close()
      local gitdir = line:match("^gitdir:%s*(.-)%s*$")
      if gitdir then
        if vim.fn.isabsolutepath(gitdir) == 1 then
          return vim.fs.normalize(gitdir)
        else
          return vim.fs.normalize(root .. "/" .. gitdir)
        end
      end
    end
  end
  return nil
end

---Get current git branch name via pure Lua file read (zero shell fork overhead: <0.05ms)
---@param root? string
---@return string? branch_name
function M.get_git_branch(root)
  root = root or M.find_project_root()
  local git_dir = M.resolve_git_dir(root)
  if not git_dir then
    return nil
  end

  local head_file = git_dir .. "/HEAD"
  local f = io.open(head_file, "r")
  if not f then
    return nil
  end
  local content = f:read("*l") or ""
  f:close()

  local branch = content:match("^ref:%s*refs/heads/(.-)%s*$")
  if branch and branch ~= "" then
    return branch
  end

  -- Detached HEAD: return shortened commit hash
  local commit = content:match("^(%x+)%s*$")
  if commit and #commit >= 7 then
    return "detached-" .. commit:sub(1, 8)
  end

  return "HEAD"
end

---Get git-private branch-scoped session file path inside .git/smart-highlighter/
---Never tracked by Git, zero working tree dirt, zero checkout conflicts!
---@param root string
---@param branch? string
---@return string? session_path
function M.get_git_session_file(root, branch)
  local git_dir = M.resolve_git_dir(root)
  if not git_dir then
    return nil
  end
  local b = branch or M.get_git_branch(root) or "default"
  local safe_b = sanitize_name(b)
  local store_dir = git_dir .. "/smart-highlighter"
  return vim.fs.normalize(store_dir .. "/" .. safe_b .. ".json")
end

---Get project-local session file path (working tree)
---@param custom_root? string
---@param custom_filename? string
---@return string file_path, string root_dir
function M.get_project_file(custom_root, custom_filename)
  local root = custom_root or M.find_project_root()
  local p_opts = (config.options and config.options.persistence) or {}
  local fname = custom_filename or (type(p_opts) == "table" and p_opts.file) or ".smart-highlighter.json"
  return vim.fs.normalize(root .. "/" .. fname), root
end

---Get unique state file path in stdpath("state") with optional branch scoping
---@param custom_cwd? string
---@param branch? string
---@return string
function M.get_state_file(custom_cwd, branch)
  local cwd = custom_cwd or vim.fn.getcwd()
  local safe_name = cwd:gsub("[/\\]", "_")
  if branch and branch ~= "" then
    safe_name = safe_name .. "__" .. sanitize_name(branch)
  end
  return get_storage_dir() .. "/" .. safe_name .. ".json"
end

---Get primary session target file according to persistence configuration
---@param custom_root? string
---@param custom_filename? string
---@return string file_path, string root_dir
function M.get_target_session_file(custom_root, custom_filename)
  local root = custom_root or M.find_project_root()
  local p_opts = (config.options and config.options.persistence) or {}
  local mode = (type(p_opts) == "table" and p_opts.mode) or "git"
  local branch_scoped = (type(p_opts) == "table" and p_opts.branch_scoped ~= false)

  if custom_filename and custom_filename ~= "" then
    return vim.fs.normalize(root .. "/" .. custom_filename), root
  end

  local branch = branch_scoped and M.get_git_branch(root) or nil

  if mode == "git" then
    local git_file = M.get_git_session_file(root, branch)
    if git_file then
      return git_file, root
    end
    -- Fallback to state directory if not a git repository
    return M.get_state_file(root, branch), root
  elseif mode == "project" then
    local fname = (type(p_opts) == "table" and p_opts.file) or ".smart-highlighter.json"
    return vim.fs.normalize(root .. "/" .. fname), root
  elseif mode == "state" then
    return M.get_state_file(root, branch), root
  end

  return vim.fs.normalize(root .. "/.smart-highlighter.json"), root
end

---Stop active git HEAD watcher and debouncers
function M.stop_head_watcher()
  if switch_debounce_timer then
    switch_debounce_timer:stop()
    switch_debounce_timer:close()
    switch_debounce_timer = nil
  end
  if head_watcher then
    head_watcher:stop()
    head_watcher:close()
    head_watcher = nil
  end
end

---Start reactive libuv fs_event watcher on git directory for zero-overhead branch switching
---@param root string
function M.start_head_watcher(root)
  local p_opts = (config.options and config.options.persistence) or {}
  if type(p_opts) == "table" and (p_opts.enabled == false or p_opts.watch_head == false) then
    return
  end

  local git_dir = M.resolve_git_dir(root)
  if not git_dir then
    return
  end

  M.stop_head_watcher()

  head_watcher = vim.uv.new_fs_event()
  -- Watch the git directory so atomic renames to HEAD are captured reliably
  local ok, _ = head_watcher:start(git_dir, {}, vim.schedule_wrap(function(err_evt, filename, _)
    if err_evt then
      return
    end

    -- Only react if HEAD or refs were modified
    if filename and filename ~= "HEAD" and filename ~= "HEAD.lock" and not filename:match("^refs") then
      return
    end

    if switch_debounce_timer then
      switch_debounce_timer:stop()
    else
      switch_debounce_timer = vim.uv.new_timer()
    end

    switch_debounce_timer:start(150, 0, vim.schedule_wrap(function()
      local new_branch = M.get_git_branch(root)
      if new_branch and new_branch ~= M.current_loaded_branch then
        -- Branch switch detected!
        -- 1. Flush any pending changes to current branch session
        M.flush_save()
        local prev_branch = M.current_loaded_branch or "unknown"
        M.current_loaded_branch = new_branch

        -- 2. Load session for new branch
        M.load_session(nil, true)

        vim.notify(
          string.format("[SmartHighlight] Git branch switched: '%s' ➜ '%s'. Loaded branch session.", prev_branch, new_branch),
          vim.log.levels.INFO
        )
      end
    end))
  end))

  if not ok then
    -- Non-fatal: if fs_event fails, continue normally without watcher
  end
end

---Request debounced auto-save if auto_persist is active
function M.request_auto_save()
  local p_opts = (config.options and config.options.persistence) or {}
  if type(p_opts) == "boolean" and not p_opts then
    return
  end
  if type(p_opts) == "table" and (p_opts.enabled == false or p_opts.auto_persist == false) then
    return
  end

  if auto_save_timer then
    auto_save_timer:stop()
  else
    auto_save_timer = vim.uv.new_timer()
  end

  auto_save_timer:start(300, 0, vim.schedule_wrap(function()
    M.save_session(nil, true)
  end))
end

---Immediately flush pending auto-save
function M.flush_save()
  if auto_save_timer and auto_save_timer:is_active() then
    auto_save_timer:stop()
  end
  local p_opts = (config.options and config.options.persistence) or {}
  if type(p_opts) == "table" and p_opts.enabled ~= false and p_opts.auto_persist ~= false then
    M.save_session(nil, true)
  end
end

---Toggle auto-persist mode on or off
---@param state? boolean|string "on"|"off"|"toggle"
---@return boolean new_state
function M.toggle_auto_persist(state)
  if type(config.options.persistence) ~= "table" then
    config.options.persistence = vim.deepcopy(config.defaults.persistence)
  end

  local cur = config.options.persistence.auto_persist ~= false
  local target
  if state == "on" or state == true then
    target = true
  elseif state == "off" or state == false then
    target = false
  else
    target = not cur
  end

  config.options.persistence.auto_persist = target
  local p_mode = config.options.persistence.mode or "git"
  local target_desc = (p_mode == "git") and ".git/smart-highlighter (private per branch)"
    or (p_mode == "project" and "repo root file" or "state cache")
  local desc = target and string.format("ENABLED (Auto-saving to %s)", target_desc) or "DISABLED"
  vim.notify(string.format("[SmartHighlight] Auto-persist is now %s", desc), vim.log.levels.INFO)
  if target then
    M.save_session(nil, false)
  end
  return target
end

---Build export payload from current slots and bookmarks
---@param root string Project root for relative path calculation
---@param branch? string Optional git branch name
---@return table payload
local function build_payload(root, branch)
  local export_slots = {}
  for _, slot in pairs(engine.slots) do
    table.insert(export_slots, {
      id = slot.id,
      pattern = slot.pattern,
      is_regex = slot.is_regex,
      whole_word = slot.whole_word,
      case_sensitive = slot.case_sensitive,
      enabled = slot.enabled,
      scope = slot.scope,
      name = slot.name,
      color_idx = slot.color_idx,
    })
  end

  local ok_bm, bookmarks_mod = pcall(require, "smart_highlighter.core.bookmarks")
  local export_bm = {}
  if ok_bm and bookmarks_mod and bookmarks_mod.bookmarks then
    for _, bm in ipairs(bookmarks_mod.bookmarks) do
      local rel_file = vim.fs.relpath(root, bm.file) or vim.fn.fnamemodify(bm.file, ":.")
      table.insert(export_bm, {
        file = rel_file,
        abs_file = bm.file,
        line = bm.line,
        col = bm.col,
        text = bm.text,
        note = bm.note,
        tag = bm.tag or "GENERAL",
        created_at = bm.created_at,
      })
    end
  end

  return {
    version = 3,
    root = root,
    branch = branch,
    updated_at = os.time(),
    slots = export_slots,
    bookmarks = export_bm,
  }
end

---Save current active slots and bookmarks to session file (git-local, project file, or state cache)
---@param target_file? string Explicit file path to save into (e.g. for export)
---@param silent? boolean If true, suppresses notify popup
---@return boolean ok, string msg
function M.save_session(target_file, silent)
  local root = M.find_project_root()
  local branch = M.get_git_branch(root)
  local p_opts = (config.options and config.options.persistence) or {}
  local mode = (type(p_opts) == "table" and p_opts.mode) or "git"
  local payload = build_payload(root, branch)
  local encoded = vim.fn.json_encode(payload)

  local files_to_write = {}

  if target_file and target_file ~= "" then
    table.insert(files_to_write, vim.fs.normalize(target_file))
  else
    local primary_file = M.get_target_session_file(root)
    table.insert(files_to_write, primary_file)

    if mode == "both" then
      local state_file = M.get_state_file(root, branch)
      if state_file ~= primary_file then
        table.insert(files_to_write, state_file)
      end
    end
  end

  local written = 0
  for _, fpath in ipairs(files_to_write) do
    local parent = vim.fs.dirname(fpath)
    if parent and vim.fn.isdirectory(parent) == 0 then
      vim.fn.mkdir(parent, "p")
    end

    local f = io.open(fpath, "w")
    if f then
      f:write(encoded)
      f:close()
      written = written + 1
    end
  end

  if written == 0 then
    local err = "Failed to write session file to disk"
    if not silent then
      vim.notify("[SmartHighlight] " .. err, vim.log.levels.ERROR)
    end
    return false, err
  end

  M.current_loaded_root = root
  M.current_loaded_branch = branch

  local dest_desc
  if target_file then
    dest_desc = vim.fn.fnamemodify(target_file, ":~:.")
  elseif mode == "git" and branch then
    dest_desc = string.format(".git/smart-highlighter/%s.json (branch '%s')", sanitize_name(branch), branch)
  elseif mode == "project" then
    dest_desc = ".smart-highlighter.json (repo root)"
  else
    dest_desc = "state cache"
  end

  local msg = string.format("Persisted %d highlights & %d bookmarks to %s", #payload.slots, #payload.bookmarks, dest_desc)

  if not silent then
    vim.notify("[SmartHighlight] " .. msg, vim.log.levels.INFO)
  end

  return true, msg
end

---Load slots and bookmarks from file or auto-discovered project root / git branch
---@param source_file? string Explicit file path to load from (e.g. for import)
---@param silent? boolean If true, suppresses notify popup
---@return boolean ok, string msg
function M.load_session(source_file, silent)
  local root = M.find_project_root()
  local branch = M.get_git_branch(root)
  local p_opts = (config.options and config.options.persistence) or {}
  local file_to_read = nil

  if source_file and source_file ~= "" then
    file_to_read = vim.fs.normalize(source_file)
  else
    -- Priority 1: Configured target session file (.git/smart-highlighter/<branch>.json if mode="git")
    local primary_file = M.get_target_session_file(root)
    if vim.fn.filereadable(primary_file) == 1 then
      file_to_read = primary_file
    end

    -- Priority 2: Fallback to branch-scoped state file
    if not file_to_read and branch then
      local state_branch_file = M.get_state_file(root, branch)
      if vim.fn.filereadable(state_branch_file) == 1 then
        file_to_read = state_branch_file
      end
    end

    -- Priority 3: Fallback to project root file (.smart-highlighter.json)
    if not file_to_read then
      local proj_file = M.get_project_file(root)
      if vim.fn.filereadable(proj_file) == 1 then
        file_to_read = proj_file
      end
    end

    -- Priority 4: Alternative legacy repo-local filenames
    if not file_to_read then
      local alts = {
        root .. "/.smart-bookmarks.json",
        root .. "/.smart-bookmarks-highlighter.json",
      }
      for _, alt in ipairs(alts) do
        if vim.fn.filereadable(alt) == 1 then
          file_to_read = alt
          break
        end
      end
    end

    -- Priority 5: Global state cache (unscoped)
    if not file_to_read then
      local state_file = M.get_state_file(root)
      if vim.fn.filereadable(state_file) == 1 then
        file_to_read = state_file
      end
    end
  end

  if not file_to_read or vim.fn.filereadable(file_to_read) == 0 then
    local branch_info = branch and string.format(" for branch '%s'", branch) or ""
    local msg = "No saved highlights or bookmarks found" .. branch_info
    if not silent and source_file then
      vim.notify("[SmartHighlight] " .. msg, vim.log.levels.WARN)
    end
    -- Still mark root & branch and arm watcher
    M.current_loaded_root = root
    M.current_loaded_branch = branch
    M.start_head_watcher(root)
    return false, msg
  end

  local f = io.open(file_to_read, "r")
  if not f then
    return false, "Could not open session file"
  end
  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return false, "Empty session file"
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= "table" then
    return false, "Corrupted session file"
  end

  -- Clear previous state before restoring
  engine.clear_all()

  local slots_data = data
  local bm_data = {}
  if data.version and data.slots then
    slots_data = data.slots
    bm_data = data.bookmarks or {}
  end

  for _, item in ipairs(slots_data) do
    if item.pattern then
      engine.add_slot(item.pattern, {
        id = item.id,
        is_regex = item.is_regex,
        whole_word = item.whole_word,
        case_sensitive = item.case_sensitive,
        scope = item.scope,
        name = item.name,
      })
    end
  end

  local ok_bm, bookmarks_mod = pcall(require, "smart_highlighter.core.bookmarks")
  if ok_bm and bookmarks_mod then
    bookmarks_mod.clear_all()
    for _, item in ipairs(bm_data) do
      local file_path = item.file or item.abs_file or item.path
      if file_path and item.line then
        -- If path is relative, resolve it against project root
        local is_abs = (vim.fn.isabsolutepath(file_path) == 1)
        if not is_abs then
          file_path = vim.fs.normalize(root .. "/" .. file_path)
        end
        bookmarks_mod.set_bookmark(
          file_path,
          item.line,
          item.col or 0,
          item.text or "",
          item.note or item.text,
          item.tag
        )
      end
    end
    bookmarks_mod.render_all_buffers()
  end

  M.current_loaded_root = root
  M.current_loaded_branch = branch
  M.start_head_watcher(root)

  local src_desc = vim.fn.fnamemodify(file_to_read, ":~:.")
  local msg = string.format("Restored %d highlights & %d bookmarks from %s", #slots_data, #bm_data, src_desc)

  if not silent then
    vim.notify("[SmartHighlight] " .. msg, vim.log.levels.INFO)
  end

  return true, msg
end

---Check if project root or git branch has changed, flush previous project if needed, and load new root
---@param new_path? string
function M.check_and_switch_project(new_path)
  local new_root = M.find_project_root(new_path)
  local new_branch = M.get_git_branch(new_root)

  if M.current_loaded_root and M.current_loaded_root == new_root and M.current_loaded_branch == new_branch then
    return
  end

  local p_opts = (config.options and config.options.persistence) or {}
  if type(p_opts) == "table" and (p_opts.enabled == false or p_opts.auto_load == false) then
    M.current_loaded_root = new_root
    M.current_loaded_branch = new_branch
    return
  end

  -- Flush any pending save for previous root/branch
  if M.current_loaded_root then
    M.flush_save()
  end

  M.current_loaded_root = new_root
  M.current_loaded_branch = new_branch
  M.load_session(nil, true)
  M.start_head_watcher(new_root)
end

return M
