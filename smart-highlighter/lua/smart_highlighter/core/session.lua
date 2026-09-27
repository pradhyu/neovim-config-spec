local engine = require("smart_highlighter.core.engine")
local config = require("smart_highlighter.config")

local M = {}

---@type string? Currently loaded project root directory
M.current_loaded_root = nil

---@type userdata? UV timer for debounced auto-save
local auto_save_timer = nil

---Get session storage directory path in stdpath("state")
---@return string
local function get_storage_dir()
  local base = vim.fn.stdpath("state") .. "/smart-highlighter"
  if vim.fn.isdirectory(base) == 0 then
    vim.fn.mkdir(base, "p")
  end
  return base
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

---Get project-local session file path
---@param custom_root? string
---@param custom_filename? string
---@return string file_path, string root_dir
function M.get_project_file(custom_root, custom_filename)
  local root = custom_root or M.find_project_root()
  local p_opts = (config.options and config.options.persistence) or {}
  local fname = custom_filename or (type(p_opts) == "table" and p_opts.file) or ".smart-highlighter.json"
  return vim.fs.normalize(root .. "/" .. fname), root
end

---Get unique hash or filename for global state directory
---@param custom_cwd? string
---@return string
function M.get_state_file(custom_cwd)
  local cwd = custom_cwd or vim.fn.getcwd()
  local safe_name = cwd:gsub("[/\\]", "_") .. ".json"
  return get_storage_dir() .. "/" .. safe_name
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
  local desc = target and "ENABLED (Auto-saving bookmarks & highlights to repo root)" or "DISABLED"
  vim.notify(string.format("[SmartHighlight] Auto-persist is now %s", desc), vim.log.levels.INFO)
  if target then
    M.save_session(nil, false)
  end
  return target
end

---Build export payload from current slots and bookmarks
---@param root string Project root for relative path calculation
---@return table payload
local function build_payload(root)
  local export_slots = {}
  for id, slot in pairs(engine.slots) do
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
    updated_at = os.time(),
    slots = export_slots,
    bookmarks = export_bm,
  }
end

---Save current active slots and bookmarks to session file (project-local and/or state cache)
---@param target_file? string Explicit file path to save into (e.g. for export)
---@param silent? boolean If true, suppresses notify popup
---@return boolean ok, string msg
function M.save_session(target_file, silent)
  local root = M.find_project_root()
  local p_opts = (config.options and config.options.persistence) or {}
  local mode = (type(p_opts) == "table" and p_opts.mode) or "project"
  local payload = build_payload(root)
  local encoded = vim.fn.json_encode(payload)

  local files_to_write = {}

  if target_file and target_file ~= "" then
    table.insert(files_to_write, vim.fs.normalize(target_file))
  else
    if mode == "project" or mode == "both" then
      local proj_file = M.get_project_file(root)
      table.insert(files_to_write, proj_file)
    end
    if mode == "state" or mode == "both" then
      local state_file = M.get_state_file()
      table.insert(files_to_write, state_file)
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

  local dest_desc = target_file and vim.fn.fnamemodify(target_file, ":~:.")
    or (mode == "project" and ".smart-highlighter.json (repo root)" or "state cache")
  local msg = string.format("Persisted %d highlights & %d bookmarks to %s", #payload.slots, #payload.bookmarks, dest_desc)

  if not silent then
    vim.notify("[SmartHighlight] " .. msg, vim.log.levels.INFO)
  end

  return true, msg
end

---Load slots and bookmarks from file or auto-discovered project root
---@param source_file? string Explicit file path to load from (e.g. for import)
---@param silent? boolean If true, suppresses notify popup
---@return boolean ok, string msg
function M.load_session(source_file, silent)
  local root = M.find_project_root()
  local p_opts = (config.options and config.options.persistence) or {}
  local file_to_read = nil

  if source_file and source_file ~= "" then
    file_to_read = vim.fs.normalize(source_file)
  else
    -- Priority 1: Configured project file in repo root
    local proj_file = M.get_project_file(root)
    if vim.fn.filereadable(proj_file) == 1 then
      file_to_read = proj_file
    else
      -- Priority 2: Alternative repo-local filenames
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

    -- Priority 3: State cache
    if not file_to_read then
      local state_file = M.get_state_file()
      if vim.fn.filereadable(state_file) == 1 then
        file_to_read = state_file
      end
    end
  end

  if not file_to_read or vim.fn.filereadable(file_to_read) == 0 then
    local msg = "No saved highlights or bookmarks found for current workspace"
    if not silent and source_file then
      vim.notify("[SmartHighlight] " .. msg, vim.log.levels.WARN)
    end
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

  local src_desc = vim.fn.fnamemodify(file_to_read, ":~:.")
  local msg = string.format("Restored %d highlights & %d bookmarks from %s", #slots_data, #bm_data, src_desc)

  if not silent then
    vim.notify("[SmartHighlight] " .. msg, vim.log.levels.INFO)
  end

  return true, msg
end

---Check if project root has changed, flush previous project if needed, and load new root
---@param new_path? string
function M.check_and_switch_project(new_path)
  local new_root = M.find_project_root(new_path)
  if M.current_loaded_root and M.current_loaded_root == new_root then
    return
  end

  local p_opts = (config.options and config.options.persistence) or {}
  if type(p_opts) == "table" and (p_opts.enabled == false or p_opts.auto_load == false) then
    M.current_loaded_root = new_root
    return
  end

  -- Flush any pending save for previous root
  if M.current_loaded_root then
    M.flush_save()
  end

  M.current_loaded_root = new_root
  M.load_session(nil, true)
end

return M
