local palette = require("smart_highlighter.core.palette")
local config = require("smart_highlighter.config")

local M = {}

---@class Bookmark
---@field id integer
---@field file string
---@field line integer 1-indexed
---@field col integer 0-indexed
---@field text string Code/line text
---@field note string Custom annotation or fallback text
---@field tag string Tag prefix (e.g. "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL")
---@field created_at integer

---@type Bookmark[]
M.bookmarks = {}

---@type integer
M.ns_id = vim.api.nvim_create_namespace("smart_highlighter_bookmarks_ns")

---@type string? Active filter tag or nil for all
M.active_filter = nil

local next_id = 1

M.TAG_ORDER = { "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }

M.TAG_ALIASES = {
  todo = "TODO",
  task = "TODO",
  ["do"] = "TODO",
  fixme = "FIXME",
  fix = "FIXME",
  bug = "FIXME",
  issue = "FIXME",
  error = "FIXME",
  warn = "WARN",
  warning = "WARN",
  caution = "WARN",
  alert = "WARN",
  note = "NOTE",
  info = "NOTE",
  idea = "NOTE",
  tip = "NOTE",
  hack = "HACK",
  perf = "HACK",
  optimize = "HACK",
  workaround = "HACK",
}

---Normalize file path
---@param path string
---@return string
local function normalize_path(path)
  return vim.fs.normalize(path)
end

---Detect and normalize tag from note and code text
---@param note string
---@param text? string
---@return string tag, string clean_note
function M.detect_tag(note, text)
  local function test_str(str)
    if not str or str == "" then
      return nil, str
    end

    -- Strip leading comment characters: //, /*, *, #, --, ;, <!--
    local cleaned = str:gsub("^%s*[%/][%/]%s*", "")
      :gsub("^%s*[%/]%*%s*", "")
      :gsub("^%s*%*%s*", "")
      :gsub("^%s*#%s*", "")
      :gsub("^%s*%-%-%s*", "")
      :gsub("^%s*;%s*", "")
      :gsub("^%s*<!%-%-%s*", "")
    cleaned = vim.trim(cleaned)

    -- 1. Check bracketed prefix: [TAG] or (TAG)
    local tag_cand, rest = cleaned:match("^[%[%(]([%a%d_-]+)[%]%)]%s*:?%s*(.*)$")
    if tag_cand then
      local lower = tag_cand:lower()
      if M.TAG_ALIASES[lower] then
        local tag = M.TAG_ALIASES[lower]
        return tag, (rest and rest ~= "" and rest or cleaned)
      end
    end

    -- 2. Check TAG: or TAG -:
    tag_cand, rest = cleaned:match("^([%a%d_-]+)%s*[:%-]%s*(.*)$")
    if tag_cand then
      local lower = tag_cand:lower()
      if M.TAG_ALIASES[lower] then
        local tag = M.TAG_ALIASES[lower]
        return tag, (rest and rest ~= "" and rest or cleaned)
      end
    end

    -- 3. Check leading word if matches tag alias
    tag_cand, rest = cleaned:match("^([%a%d_-]+)%s+(.*)$")
    if tag_cand then
      local lower = tag_cand:lower()
      if M.TAG_ALIASES[lower] then
        local tag = M.TAG_ALIASES[lower]
        return tag, (rest and rest ~= "" and rest or cleaned)
      end
    end

    -- 4. Check entire word if single tag keyword
    local lower = cleaned:lower()
    if M.TAG_ALIASES[lower] then
      return M.TAG_ALIASES[lower], cleaned
    end

    return nil, str
  end

  -- Check note first
  local tag, clean_note = test_str(note)
  if tag then
    return tag, clean_note
  end

  -- Fallback to checking code text if note didn't match a known tag
  if text and text ~= "" then
    local tag_from_text, _ = test_str(text)
    if tag_from_text then
      return tag_from_text, note
    end
  end

  return "GENERAL", note
end

---Get text for cursor line or visual selection
---@return string text, boolean is_visual
local function get_target_text()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local _, csrow, cscol, _ = unpack(vim.fn.getpos("'<"))
    local _, cerow, cecol, _ = unpack(vim.fn.getpos("'>"))
    if csrow == cerow then
      local line = vim.api.nvim_buf_get_lines(0, csrow - 1, csrow, false)[1] or ""
      local sel = string.sub(line, cscol, cecol)
      if sel ~= "" then
        return vim.trim(sel), true
      end
    end
  end

  local cur_line = vim.api.nvim_get_current_line()
  local trimmed = vim.trim(cur_line)
  if trimmed ~= "" then
    return trimmed, false
  end

  local cword = vim.fn.expand("<cword>")
  return cword ~= "" and cword or "[Empty Line]", false
end

---Find bookmark index by file and line
---@param file string
---@param line integer
---@return integer? idx, Bookmark? bookmark
function M.find_by_location(file, line)
  local norm_file = normalize_path(file)
  for idx, bm in ipairs(M.bookmarks) do
    if normalize_path(bm.file) == norm_file and bm.line == line then
      return idx, bm
    end
  end
  return nil, nil
end

---Find bookmark index by ID
---@param id integer
---@return integer? idx, Bookmark? bookmark
function M.find_by_id(id)
  for idx, bm in ipairs(M.bookmarks) do
    if bm.id == id then
      return idx, bm
    end
  end
  return nil, nil
end

---Render bookmark extmarks on a buffer with tag-aware styling
---@param buf integer
function M.render_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end

  pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns_id, 0, -1)

  local buf_file = vim.api.nvim_buf_get_name(buf)
  if buf_file == "" then
    return
  end
  local norm_file = normalize_path(buf_file)
  local line_count = vim.api.nvim_buf_line_count(buf)

  local bm_opts = (config.options and config.options.bookmarks) or {}
  local show_virt = (bm_opts.virt_text ~= false)
  local show_line = (bm_opts.line_highlight ~= false)
  local default_sign = bm_opts.sign_text or "🔖"

  for _, bm in ipairs(M.bookmarks) do
    if normalize_path(bm.file) == norm_file and bm.line >= 1 and bm.line <= line_count then
      local row = bm.line - 1
      local tag = bm.tag or "GENERAL"
      local style = (palette.TAG_STYLES and palette.TAG_STYLES[tag]) or {
        icon = default_sign,
        label = tag,
      }
      local sign_icon = style.icon or default_sign

      local extmark_opts = {
        priority = 250,
      }

      if default_sign and default_sign ~= "" then
        extmark_opts.sign_text = sign_icon
        extmark_opts.sign_hl_group = "SmartBookmarkSign_" .. tag
      end

      if show_line then
        extmark_opts.line_hl_group = "SmartBookmarkLine_" .. tag
      end

      if show_virt then
        local display_note = bm.note ~= "" and bm.note or bm.text
        if #display_note > 50 then
          display_note = display_note:sub(1, 47) .. "..."
        end

        local badge_text = string.format(" %s [%s] ", sign_icon, tag)
        extmark_opts.virt_text = {
          { badge_text, "SmartBookmarkBadge_" .. tag },
          { " " .. display_note, "SmartBookmarkVirt_" .. tag },
        }
        extmark_opts.virt_text_pos = "eol"
      end

      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, row, 0, extmark_opts)
    end
  end
end

---Render bookmarks in all loaded buffers
function M.render_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      M.render_buffer(buf)
    end
  end
end

---Add or update a bookmark at a specific position
---@param file string
---@param line integer
---@param col integer
---@param text string
---@param note? string
---@param explicit_tag? string
---@return Bookmark
function M.set_bookmark(file, line, col, text, note, explicit_tag)
  local norm_file = normalize_path(file)
  local effective_note = (note and vim.trim(note) ~= "") and vim.trim(note) or text
  local detected_tag = explicit_tag or M.detect_tag(effective_note, text)

  local idx, existing = M.find_by_location(norm_file, line)
  if existing then
    existing.text = text
    existing.note = effective_note
    existing.tag = detected_tag
    existing.col = col
    M.render_all_buffers()
    return existing
  end

  local bm = {
    id = next_id,
    file = norm_file,
    line = line,
    col = col,
    text = text,
    note = effective_note,
    tag = detected_tag,
    created_at = os.time(),
  }
  next_id = next_id + 1

  table.insert(M.bookmarks, bm)
  M.render_all_buffers()
  return bm
end

---Remove a bookmark by ID or by file/line
---@param id_or_file integer|string
---@param line? integer
---@return boolean
function M.remove_bookmark(id_or_file, line)
  if type(id_or_file) == "number" and not line then
    local idx = M.find_by_id(id_or_file)
    if idx then
      table.remove(M.bookmarks, idx)
      M.render_all_buffers()
      return true
    end
    return false
  end

  local idx = M.find_by_location(tostring(id_or_file), line)
  if idx then
    table.remove(M.bookmarks, idx)
    M.render_all_buffers()
    return true
  end
  return false
end

---Clear all bookmarks
function M.clear_all()
  M.bookmarks = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns_id, 0, -1)
    end
  end
end

---Toggle bookmark on current cursor line with interactive note prompt
---@param custom_note? string If passed, uses this note directly without prompting
function M.toggle_interactive(custom_note)
  local cur_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(cur_buf)
  if not file or file == "" then
    vim.notify("[SmartBookmark] Cannot bookmark an unnamed buffer. Save the file first.", vim.log.levels.WARN)
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local line = cur[1]
  local col = cur[2]
  local target_text = get_target_text()

  local idx, existing = M.find_by_location(file, line)

  if custom_note ~= nil then
    if existing and custom_note == "" then
      M.remove_bookmark(existing.id)
      vim.notify(string.format("[SmartBookmark] Removed bookmark at Line %d", line), vim.log.levels.INFO)
      return
    end
    local bm = M.set_bookmark(file, line, col, target_text, custom_note)
    local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
    local icon = style.icon or "🔖"
    vim.notify(
      string.format("[SmartBookmark] %s Saved [%s] #%d: '%s' (Line %d)", icon, bm.tag, bm.id, bm.note, line),
      vim.log.levels.INFO
    )
    return
  end

  -- If bookmark already exists on this line, prompt to edit note or delete
  if existing then
    vim.ui.input({
      prompt = string.format("🔖 Bookmark exists [%s: '%s']. Enter new note, or leave blank to delete: ", existing.tag, existing.note),
      default = existing.note,
    }, function(input)
      if input == nil then
        return -- Cancelled
      end
      input = vim.trim(input)
      if input == "" then
        M.remove_bookmark(existing.id)
        vim.notify(string.format("[SmartBookmark] Removed bookmark at Line %d", line), vim.log.levels.INFO)
      else
        local tag = M.detect_tag(input, existing.text)
        existing.note = input
        existing.tag = tag
        M.render_all_buffers()
        local style = (palette.TAG_STYLES and palette.TAG_STYLES[tag]) or {}
        local icon = style.icon or "🔖"
        vim.notify(string.format("[SmartBookmark] %s Updated Bookmark #%d [%s]: '%s'", icon, existing.id, tag, existing.note), vim.log.levels.INFO)
      end
    end)
    return
  end

  -- Prompt for new bookmark note
  vim.ui.input({
    prompt = "🔖 Bookmark Note (supports TODO:, FIXME:, WARN:, NOTE:, HACK: or empty for line): ",
  }, function(input)
    if input == nil then
      return -- Cancelled
    end
    local note = vim.trim(input)
    local bm = M.set_bookmark(file, line, col, target_text, note)
    local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
    local icon = style.icon or "🔖"
    vim.notify(string.format("[SmartBookmark] %s Added [%s] Bookmark #%d: '%s' (Line %d)", icon, bm.tag, bm.id, bm.note, line), vim.log.levels.INFO)
  end)
end

---Quick toggle bookmark on current line without prompting (immediately uses highlighted/line text)
function M.quick_toggle()
  local cur_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(cur_buf)
  if not file or file == "" then
    vim.notify("[SmartBookmark] Cannot bookmark an unnamed buffer. Save the file first.", vim.log.levels.WARN)
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local line = cur[1]
  local col = cur[2]

  local idx, existing = M.find_by_location(file, line)
  if existing then
    M.remove_bookmark(existing.id)
    vim.notify(string.format("[SmartBookmark] Removed bookmark at Line %d", line), vim.log.levels.INFO)
  else
    local target_text = get_target_text()
    local bm = M.set_bookmark(file, line, col, target_text, target_text)
    local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
    local icon = style.icon or "🔖"
    vim.notify(string.format("[SmartBookmark] %s [%s] Bookmarked Line %d: '%s'", icon, bm.tag, line, bm.note), vim.log.levels.INFO)
  end
end

---Get bookmark counts grouped by tag
---@param scope? "all"|"current"
---@return table<string, integer> counts, integer total
function M.get_tag_counts(scope)
  scope = scope or "all"
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  local counts = { ALL = 0 }
  for _, t in ipairs(M.TAG_ORDER) do
    counts[t] = 0
  end

  for _, bm in ipairs(M.bookmarks) do
    if scope == "all" or normalize_path(bm.file) == cur_file then
      counts.ALL = counts.ALL + 1
      local t = bm.tag or "GENERAL"
      counts[t] = (counts[t] or 0) + 1
    end
  end

  return counts, counts.ALL
end

---Jump to a bookmark location
---@param bm Bookmark
local function jump_to_bookmark(bm)
  local norm_target = normalize_path(bm.file)
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  if cur_file ~= norm_target then
    vim.cmd(string.format("edit %s", vim.fn.fnameescape(bm.file)))
  end

  pcall(vim.api.nvim_win_set_cursor, 0, { bm.line, bm.col })
  vim.cmd("normal! zvzz")
  local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
  local icon = style.icon or "🔖"
  vim.notify(
    string.format("[SmartBookmark #%d] %s [%s] %s (Line %d)", bm.id, icon, bm.tag, bm.note, bm.line),
    vim.log.levels.INFO
  )
end

---Jump to next bookmark, optionally filtered by tag
---@param forward boolean
---@param filter_tag? string Optional tag to restrict jump to (e.g. "TODO", "FIXME")
function M.jump(forward, filter_tag)
  local target_tag = filter_tag or M.active_filter
  if target_tag and target_tag:upper() == "ALL" then
    target_tag = nil
  end
  if target_tag then
    target_tag = target_tag:upper()
  end

  local candidates = {}
  for _, bm in ipairs(M.bookmarks) do
    if not target_tag or bm.tag == target_tag then
      table.insert(candidates, bm)
    end
  end

  if #candidates == 0 then
    local desc = target_tag and string.format("with tag [%s]", target_tag) or ""
    vim.notify(string.format("[SmartBookmark] No active bookmarks found %s", desc), vim.log.levels.WARN)
    return
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))
  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_line = cur[1]

  -- Sort candidates by file, then line
  local sorted = vim.deepcopy(candidates)
  table.sort(sorted, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.line < b.line
  end)

  local target = nil
  if forward then
    -- 1. Next in same file
    for _, bm in ipairs(sorted) do
      if normalize_path(bm.file) == cur_file and bm.line > cur_line then
        target = bm
        break
      end
    end
    -- 2. In subsequent files
    if not target then
      for _, bm in ipairs(sorted) do
        if normalize_path(bm.file) > cur_file then
          target = bm
          break
        end
      end
    end
    -- 3. Wrap around to beginning
    if not target then
      target = sorted[1]
    end
  else
    -- 1. Previous in same file
    for i = #sorted, 1, -1 do
      local bm = sorted[i]
      if normalize_path(bm.file) == cur_file and bm.line < cur_line then
        target = bm
        break
      end
    end
    -- 2. In preceding files
    if not target then
      for i = #sorted, 1, -1 do
        local bm = sorted[i]
        if normalize_path(bm.file) < cur_file then
          target = bm
          break
        end
      end
    end
    -- 3. Wrap around to end
    if not target then
      target = sorted[#sorted]
    end
  end

  if target then
    jump_to_bookmark(target)
  end
end

---Interactive tag filter selector
---@param on_select fun(tag: string?) Callback invoked with selected tag, or nil for ALL
function M.select_tag_filter(on_select)
  local counts, total = M.get_tag_counts("all")
  local items = {
    { tag = nil, label = string.format("🌐 All Bookmarks (%d)", total) },
  }

  for _, tag in ipairs(M.TAG_ORDER) do
    local c = counts[tag] or 0
    if c > 0 then
      local style = (palette.TAG_STYLES and palette.TAG_STYLES[tag]) or {}
      local icon = style.icon or "🔖"
      table.insert(items, {
        tag = tag,
        label = string.format("%s %s (%d)", icon, tag, c),
      })
    end
  end

  if #items == 1 and total == 0 then
    vim.notify("[SmartBookmark] No bookmarks in workspace to filter", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Filter Bookmarks by Tag: ",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    M.active_filter = choice.tag
    if on_select then
      on_select(choice.tag)
    end
  end)
end

---Open bookmarks in the bottom Quickfix-style list pane with tag filtering & keymaps
---@param scope? "all"|"current"
---@param tag? string Optional tag filter
function M.open_bottom_pane(scope, tag)
  scope = scope or "all"
  local filter_tag = tag or M.active_filter
  if filter_tag and (filter_tag:upper() == "ALL" or filter_tag == "") then
    filter_tag = nil
  end
  if filter_tag then
    filter_tag = filter_tag:upper()
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  local list = {}
  for _, bm in ipairs(M.bookmarks) do
    local match_scope = (scope == "all" or normalize_path(bm.file) == cur_file)
    local match_tag = (not filter_tag or bm.tag == filter_tag)

    if match_scope and match_tag then
      local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
      local icon = style.icon or "🔖"
      table.insert(list, {
        filename = bm.file,
        lnum = bm.line,
        col = bm.col + 1,
        text = string.format("[%s %s #%d: %s] %s", icon, bm.tag, bm.id, bm.note, bm.text),
      })
    end
  end

  if #list == 0 then
    local tag_desc = filter_tag and string.format("with tag [%s]", filter_tag) or ""
    local scope_desc = scope == "all" and "in project" or "in current buffer"
    vim.notify(string.format("[SmartBookmark] No bookmarks found %s %s", tag_desc, scope_desc), vim.log.levels.WARN)
    return
  end

  table.sort(list, function(a, b)
    if a.filename ~= b.filename then
      return a.filename < b.filename
    end
    return a.lnum < b.lnum
  end)

  vim.fn.setqflist(list, "r")
  local filter_label = filter_tag and string.format(" [Tag: %s]", filter_tag) or " [All Tags]"
  local scope_label = scope == "all" and "All Files" or "Current File"
  local title = string.format("Smart Bookmarks [%s%s] (t: Filter Tag | a: All | q: Close)", scope_label, filter_label)
  vim.fn.setqflist({}, "a", { title = title })

  local height = math.min(10, math.max(4, #list))
  vim.cmd(string.format("botright copen %d", height))

  local qf_win = vim.api.nvim_get_current_win()
  local qf_buf = vim.api.nvim_win_get_buf(qf_win)

  -- Bind interactive controls inside the bottom pane
  local k_opts = { buffer = qf_buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", "<cmd>cclose<cr>", k_opts)
  vim.keymap.set("n", "<Esc>", "<cmd>cclose<cr>", k_opts)

  -- 't' key: switch tag filter
  vim.keymap.set("n", "t", function()
    M.select_tag_filter(function(chosen_tag)
      M.open_bottom_pane(scope, chosen_tag)
    end)
  end, k_opts)

  -- 'a' key: show all tags
  vim.keymap.set("n", "a", function()
    M.active_filter = nil
    M.open_bottom_pane(scope, nil)
  end, k_opts)

  vim.notify(string.format("[SmartBookmark] %d bookmarks loaded in bottom list (Press 't' to filter by tag)", #list), vim.log.levels.INFO)
end

---Search bookmarks via Telescope, Snacks, or Bottom Pane
---@param opts? { scope?: "all"|"current", tag?: string }
function M.search_picker(opts)
  opts = opts or {}
  local scope = opts.scope or "all"
  local filter_tag = opts.tag or M.active_filter
  if filter_tag and (filter_tag:upper() == "ALL" or filter_tag == "") then
    filter_tag = nil
  end
  if filter_tag then
    filter_tag = filter_tag:upper()
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  local results = {}
  for _, bm in ipairs(M.bookmarks) do
    local match_scope = (scope == "all" or normalize_path(bm.file) == cur_file)
    local match_tag = (not filter_tag or bm.tag == filter_tag)

    if match_scope and match_tag then
      local style = (palette.TAG_STYLES and palette.TAG_STYLES[bm.tag]) or {}
      local icon = style.icon or "🔖"
      table.insert(results, {
        id = bm.id,
        filename = bm.file,
        row = bm.line,
        col = bm.col,
        text = bm.text,
        note = bm.note,
        tag = bm.tag,
        icon = icon,
        short_name = vim.fn.fnamemodify(bm.file, ":~:."),
      })
    end
  end

  if #results == 0 then
    local tag_desc = filter_tag and string.format("with tag [%s]", filter_tag) or ""
    local scope_desc = scope == "all" and "in project" or "in current buffer"
    vim.notify(string.format("[SmartBookmark] No bookmarks found %s %s", tag_desc, scope_desc), vim.log.levels.WARN)
    return
  end

  -- 1. Telescope integration
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if has_telescope then
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local entry_display = require("telescope.pickers.entry_display")

    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 4 }, -- ID
        { width = 10 }, -- Tag badge with icon
        { width = 28 }, -- Note
        { width = 30 }, -- File:Line
        { remaining = true }, -- Code snippet
      },
    })

    local function make_display(entry)
      local r = entry.value
      return displayer({
        { string.format("#%d", r.id), "Comment" },
        { string.format("%s %s", r.icon, r.tag), "SmartBookmarkVirt_" .. r.tag },
        { r.note, "Normal" },
        { string.format("%s:%d", r.short_name, r.row), "Directory" },
        { r.text, "SmartHighlightDisabled" },
      })
    end

    local title_scope = scope == "all" and "All Files" or "Current Buffer"
    local title_tag = filter_tag and string.format("[%s]", filter_tag) or "[All Tags]"

    pickers.new({}, {
      prompt_title = string.format("Smart Bookmarks %s %s (C-t: Tag Filter | C-b: Bottom Pane)", title_scope, title_tag),
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = string.format("%s %s %s %s %s", entry.id, entry.tag, entry.note, entry.short_name, entry.text),
            filename = entry.filename,
            lnum = entry.row,
            col = entry.col + 1,
          }
        end,
      }),
      previewer = conf.values.grep_previewer({}),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Ctrl+B switches to bottom pane
        map({ "i", "n" }, "<C-b>", function()
          local actions = require("telescope.actions")
          actions.close(prompt_bufnr)
          M.open_bottom_pane(scope, filter_tag)
        end)
        -- Ctrl+T switches tag filter
        map({ "i", "n" }, "<C-t>", function()
          local actions = require("telescope.actions")
          actions.close(prompt_bufnr)
          M.select_tag_filter(function(chosen_tag)
            M.search_picker({ scope = scope, tag = chosen_tag })
          end)
        end)
        return true
      end,
    }):find()
    return
  end

  -- 2. Snacks.picker fallback
  if _G.Snacks and _G.Snacks.picker then
    local items = {}
    for _, r in ipairs(results) do
      table.insert(items, {
        file = r.filename,
        pos = { r.row, r.col },
        line = r.text,
        text = string.format("%s [%s] %s: %s", r.icon, r.tag, r.note, r.text),
        item = r,
      })
    end
    _G.Snacks.picker.pick({
      title = string.format("Smart Bookmarks %s", filter_tag and ("[" .. filter_tag .. "]") or ""),
      items = items,
      format = "file",
    })
    return
  end

  -- 3. Bottom pane fallback
  M.open_bottom_pane(scope, filter_tag)
end

return M
