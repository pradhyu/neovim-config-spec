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
---@field created_at integer

---@type Bookmark[]
M.bookmarks = {}

---@type integer
M.ns_id = vim.api.nvim_create_namespace("smart_highlighter_bookmarks_ns")

local next_id = 1

---Normalize file path
---@param path string
---@return string
local function normalize_path(path)
  return vim.fs.normalize(path)
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

---Render bookmark extmarks on a buffer
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
  local sign_text = bm_opts.sign_text or "🔖"
  local show_virt = (bm_opts.virt_text ~= false)
  local show_line = (bm_opts.line_highlight ~= false)

  for _, bm in ipairs(M.bookmarks) do
    if normalize_path(bm.file) == norm_file and bm.line >= 1 and bm.line <= line_count then
      local row = bm.line - 1
      local extmark_opts = {
        priority = 250,
      }

      if sign_text and sign_text ~= "" then
        extmark_opts.sign_text = sign_text
        extmark_opts.sign_hl_group = "SmartBookmarkSign"
      end

      if show_line then
        extmark_opts.line_hl_group = "SmartBookmarkLine"
      end

      if show_virt then
        local display_note = bm.note ~= "" and bm.note or bm.text
        if #display_note > 45 then
          display_note = display_note:sub(1, 42) .. "..."
        end
        extmark_opts.virt_text = { { " 🔖 " .. display_note, "SmartBookmarkVirtText" } }
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
---@return Bookmark
function M.set_bookmark(file, line, col, text, note)
  local norm_file = normalize_path(file)
  local effective_note = (note and vim.trim(note) ~= "") and vim.trim(note) or text

  local idx, existing = M.find_by_location(norm_file, line)
  if existing then
    existing.text = text
    existing.note = effective_note
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
    vim.notify(string.format("[SmartBookmark] Saved Bookmark #%d: '%s' (Line %d)", bm.id, bm.note, line), vim.log.levels.INFO)
    return
  end

  -- If bookmark already exists on this line, prompt to edit note or delete
  if existing then
    vim.ui.input({
      prompt = string.format("🔖 Bookmark exists ('%s'). Enter new note, or leave blank to delete: ", existing.note),
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
        existing.note = input
        M.render_all_buffers()
        vim.notify(string.format("[SmartBookmark] Updated Bookmark #%d note: '%s'", existing.id, existing.note), vim.log.levels.INFO)
      end
    end)
    return
  end

  -- Prompt for new bookmark note
  vim.ui.input({
    prompt = "🔖 Bookmark Note (leave empty to use highlighted text): ",
  }, function(input)
    if input == nil then
      return -- Cancelled
    end
    local note = vim.trim(input)
    local bm = M.set_bookmark(file, line, col, target_text, note)
    vim.notify(string.format("[SmartBookmark] 🔖 Added Bookmark #%d: '%s' (Line %d)", bm.id, bm.note, line), vim.log.levels.INFO)
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
    vim.notify(string.format("[SmartBookmark] 🔖 Bookmarked Line %d: '%s'", line, bm.note), vim.log.levels.INFO)
  end
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
  vim.notify(string.format("[SmartBookmark #%d] 🔖 %s (Line %d)", bm.id, bm.note, bm.line), vim.log.levels.INFO)
end

---Jump to next bookmark (in current file or across all files)
---@param forward boolean
function M.jump(forward)
  if #M.bookmarks == 0 then
    vim.notify("[SmartBookmark] No active bookmarks found", vim.log.levels.WARN)
    return
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))
  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_line = cur[1]

  -- Sort all bookmarks by file, then line
  local sorted = vim.deepcopy(M.bookmarks)
  table.sort(sorted, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.line < b.line
  end)

  local target = nil
  if forward then
    -- 1. Try to find next in same file
    for _, bm in ipairs(sorted) do
      if normalize_path(bm.file) == cur_file and bm.line > cur_line then
        target = bm
        break
      end
    end
    -- 2. Try to find in subsequent files
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
    -- 1. Try to find previous in same file
    for i = #sorted, 1, -1 do
      local bm = sorted[i]
      if normalize_path(bm.file) == cur_file and bm.line < cur_line then
        target = bm
        break
      end
    end
    -- 2. Try to find in preceding files
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

---Open bookmarks in the bottom Quickfix pane
---@param scope? "all"|"current"
function M.open_bottom_pane(scope)
  scope = scope or "all"
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  local list = {}
  for _, bm in ipairs(M.bookmarks) do
    if scope == "all" or normalize_path(bm.file) == cur_file then
      local short_name = vim.fn.fnamemodify(bm.file, ":~:.")
      table.insert(list, {
        filename = bm.file,
        lnum = bm.line,
        col = bm.col + 1,
        text = string.format("[🔖 #%d: %s] %s", bm.id, bm.note, bm.text),
      })
    end
  end

  if #list == 0 then
    local desc = scope == "all" and "project" or "current buffer"
    vim.notify(string.format("[SmartBookmark] No bookmarks in %s", desc), vim.log.levels.WARN)
    return
  end

  table.sort(list, function(a, b)
    if a.filename ~= b.filename then
      return a.filename < b.filename
    end
    return a.lnum < b.lnum
  end)

  vim.fn.setqflist(list, "r")
  local title = scope == "all" and "Smart Bookmarks [All Files]" or "Smart Bookmarks [Current File]"
  vim.fn.setqflist({}, "a", { title = title })

  local height = math.min(10, math.max(4, #list))
  vim.cmd(string.format("botright copen %d", height))

  local qf_win = vim.api.nvim_get_current_win()
  local qf_buf = vim.api.nvim_win_get_buf(qf_win)
  vim.keymap.set("n", "q", "<cmd>cclose<cr>", { buffer = qf_buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>cclose<cr>", { buffer = qf_buf, silent = true, nowait = true })

  vim.notify(string.format("[SmartBookmark] Opened %d bookmarks in bottom buffer pane", #list), vim.log.levels.INFO)
end

---Search bookmarks via Telescope, Snacks, or Bottom Pane
---@param opts? { scope?: "all"|"current" }
function M.search_picker(opts)
  opts = opts or {}
  local scope = opts.scope or "all"
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_file = normalize_path(vim.api.nvim_buf_get_name(cur_buf))

  local results = {}
  for _, bm in ipairs(M.bookmarks) do
    if scope == "all" or normalize_path(bm.file) == cur_file then
      table.insert(results, {
        id = bm.id,
        filename = bm.file,
        short_name = vim.fn.fnamemodify(bm.file, ":~:."),
        row = bm.line,
        col = bm.col,
        note = bm.note,
        text = bm.text,
      })
    end
  end

  if #results == 0 then
    local desc = scope == "all" and "project" or "current buffer"
    vim.notify(string.format("[SmartBookmark] No bookmarks found in %s", desc), vim.log.levels.WARN)
    return
  end

  -- 1. Telescope Picker
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  local _, finders = pcall(require, "telescope.finders")
  local _, conf = pcall(require, "telescope.config")
  local _, entry_display = pcall(require, "telescope.pickers.entry_display")

  if has_telescope then
    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 6 },  -- #ID
        { width = 26 }, -- Note
        { width = 24 }, -- File:line
        { remaining = true }, -- Code snippet
      },
    })

    local make_display = function(entry)
      local loc = string.format("%s:%d", entry.value.short_name, entry.value.row)
      if #loc > 24 then
        loc = "..." .. loc:sub(#loc - 20)
      end
      local note_str = entry.value.note
      if #note_str > 26 then
        note_str = note_str:sub(1, 23) .. "..."
      end
      return displayer({
        { string.format("🔖#%d", entry.value.id), "SmartBookmarkSign" },
        { note_str, "SmartBookmarkVirtText" },
        { loc, "Directory" },
        { entry.value.text },
      })
    end

    local title_scope = scope == "all" and "All Files" or "Current Buffer"

    pickers.new({}, {
      prompt_title = string.format("Smart Bookmarks [%s] (Ctrl+B: bottom pane)", title_scope),
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = string.format("%s %s %s %s", entry.id, entry.note, entry.short_name, entry.text),
            filename = entry.filename,
            lnum = entry.row,
            col = entry.col + 1,
          }
        end,
      }),
      previewer = conf.values.grep_previewer({}),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        map({ "i", "n" }, "<C-b>", function()
          local actions = require("telescope.actions")
          actions.close(prompt_bufnr)
          M.open_bottom_pane(scope)
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
        text = string.format("🔖 [%s] %s", r.note, r.text),
        item = r,
      })
    end
    _G.Snacks.picker.pick({
      title = "Smart Bookmarks",
      items = items,
      format = "file",
    })
    return
  end

  -- 3. Bottom pane fallback
  M.open_bottom_pane(scope)
end

return M
