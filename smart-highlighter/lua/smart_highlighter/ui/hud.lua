local engine = require("smart_highlighter.core.engine")
local palette = require("smart_highlighter.core.palette")
local presets = require("smart_highlighter.core.presets")
local config = require("smart_highlighter.config")
local bookmarks = require("smart_highlighter.core.bookmarks")

local M = {}

---Open the interactive Floating HUD Manager
---@param initial_tab? "highlights"|"bookmarks"
function M.open(initial_tab)
  local cur_buf = vim.api.nvim_get_current_buf()
  local current_tab = initial_tab or "highlights"
  local summaries = {}
  local bm_list = {}

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "smarthighlight_hud"

  -- Calculate floating window dimensions
  local width = 80
  local height = 18
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui and ui.width or 80
  local win_height = ui and ui.height or 24
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🎨 Smart Highlighter & Bookmarks ",
    title_pos = "center",
  })

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end

    local lines = {}

    -- Tab Bar Header
    if current_tab == "highlights" then
      table.insert(lines, "  [► 1. 🎨 Highlights (Active)]    [2. 🔖 Bookmarks (Press 'm' to switch)]")
    else
      table.insert(lines, "  [1. 🎨 Highlights (Press 'm')]   [► 2. 🔖 Bookmarks (Active)]")
    end
    table.insert(lines, "  " .. string.rep("─", width - 6))

    if current_tab == "highlights" then
      summaries = engine.get_slot_summaries(cur_buf)
      local def_scope_label = (config.options.buffer_scope == "current" or config.options.buffer_scope == "buffer") and "CurBuf" or "AllBufs"
      table.insert(lines, string.format("  SLOT  STATE  PATTERN / NAME               MATCHES   SCOPE (%s)  COLOR", def_scope_label))
      table.insert(lines, "  " .. string.rep("─", width - 6))

      if #summaries == 0 then
        table.insert(lines, "")
        table.insert(lines, "   [ No active highlights. Press '+' or 'a' to add, or 'p' for presets ]")
        table.insert(lines, "")
      else
        for _, item in ipairs(summaries) do
          local state_icon = item.enabled and "🟢" or "⚪"
          local pat_str = item.name or item.pattern
          if #pat_str > 24 then
            pat_str = pat_str:sub(1, 21) .. "..."
          end
          local match_str = string.format("%d matches", item.count)
          local scope_str = "All"
          if item.scope == "buffer" or item.scope == "current" then
            scope_str = "CurBuf"
          elseif item.scope == "treesitter" then
            scope_str = "TreeSit"
          end

          local line = string.format("  #%-4d %s   %-26s %-9s %-12s %s", item.id, state_icon, pat_str, match_str, scope_str, item.color.name)
          table.insert(lines, line)
        end
      end

      table.insert(lines, "  " .. string.rep("─", width - 6))
      table.insert(lines, "  <Space> Toggle | b Slot Scope | B Global Scope | m Switch Tab")
      table.insert(lines, "  d/x Delete     | a Add Pattern| p Presets      | Q Export Quickfix")
      table.insert(lines, "  q/Esc Close    | c Clear All")

    else
      -- Bookmarks View
      bm_list = bookmarks.bookmarks
      table.insert(lines, "  ID   NOTE / ANNOTATION            LOCATION                      SNIPPET")
      table.insert(lines, "  " .. string.rep("─", width - 6))

      if #bm_list == 0 then
        table.insert(lines, "")
        table.insert(lines, "   [ No bookmarks saved. Press 'a' to add bookmark on current line ]")
        table.insert(lines, "")
      else
        for _, bm in ipairs(bm_list) do
          local note_str = bm.note
          if #note_str > 26 then
            note_str = note_str:sub(1, 23) .. "..."
          end
          local short_file = vim.fn.fnamemodify(bm.file, ":~:.")
          local loc_str = string.format("%s:%d", short_file, bm.line)
          if #loc_str > 28 then
            loc_str = "..." .. loc_str:sub(#loc_str - 24)
          end
          local snip = bm.text:gsub("%s+", " ")
          if #snip > 16 then
            snip = snip:sub(1, 13) .. "..."
          end

          local line = string.format("  #%-3d %-28s %-29s %s", bm.id, note_str, loc_str, snip)
          table.insert(lines, line)
        end
      end

      table.insert(lines, "  " .. string.rep("─", width - 6))
      table.insert(lines, "  <CR> Jump to Bookmark | e Edit Note   | d/x Delete | a Add Bookmark")
      table.insert(lines, "  m Switch Tab          | c Clear All   | Q Bottom Pane")
      table.insert(lines, "  q/Esc Close")
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Syntax highlighting
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "SmartHighlightHUDTitle", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "SmartHighlightHUDHeader", 2, 0, -1)

    if current_tab == "highlights" then
      for idx, item in ipairs(summaries) do
        local line_idx = idx + 3
        local hl_name = string.format("SmartHighlightSlot%d", item.id)
        vim.api.nvim_buf_add_highlight(buf, -1, hl_name, line_idx, 2, 7)
        vim.api.nvim_buf_add_highlight(buf, -1, "SmartHighlightCount", line_idx, 38, 48)
      end
    else
      for idx, bm in ipairs(bm_list) do
        local line_idx = idx + 3
        vim.api.nvim_buf_add_highlight(buf, -1, "SmartBookmarkSign", line_idx, 2, 6)
        vim.api.nvim_buf_add_highlight(buf, -1, "SmartBookmarkVirtText", line_idx, 7, 35)
        vim.api.nvim_buf_add_highlight(buf, -1, "Directory", line_idx, 36, 65)
      end
    end
  end

  local function get_selected_index()
    local cursor = vim.api.nvim_win_get_cursor(win)
    return cursor[1] - 4
  end

  local function toggle_selected()
    if current_tab == "highlights" then
      local idx = get_selected_index()
      if idx >= 1 and idx <= #summaries then
        engine.toggle_slot(summaries[idx].id)
        render()
      end
    end
  end

  local function toggle_slot_scope_action()
    if current_tab == "highlights" then
      local idx = get_selected_index()
      if idx >= 1 and idx <= #summaries then
        local item = summaries[idx]
        local new_scope = engine.toggle_slot_scope(item.id)
        render()
        local desc = new_scope == "global" and "All Open Buffers" or "Current Buffer Only"
        vim.notify(string.format("[SmartHighlight] Slot #%d scope set to: %s", item.id, desc), vim.log.levels.INFO)
      end
    end
  end

  local function toggle_default_scope_action()
    local new_scope = engine.set_default_scope()
    render()
    local desc = new_scope == "all" and "All Open Buffers" or "Current Buffer Only"
    vim.notify(string.format("[SmartHighlight] Default highlighting scope set to: %s", desc), vim.log.levels.INFO)
  end

  local function delete_selected()
    local idx = get_selected_index()
    if current_tab == "highlights" then
      if idx >= 1 and idx <= #summaries then
        engine.remove_slot(summaries[idx].id)
        render()
      end
    else
      if idx >= 1 and idx <= #bm_list then
        local bm = bm_list[idx]
        bookmarks.remove_bookmark(bm.id)
        render()
        vim.notify(string.format("[SmartBookmark] Deleted Bookmark #%d", bm.id), vim.log.levels.INFO)
      end
    end
  end

  local function jump_selected_bookmark()
    if current_tab == "bookmarks" then
      local idx = get_selected_index()
      if idx >= 1 and idx <= #bm_list then
        local bm = bm_list[idx]
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        local norm_target = vim.fs.normalize(bm.file)
        local c_file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
        if c_file ~= norm_target then
          vim.cmd(string.format("edit %s", vim.fn.fnameescape(bm.file)))
        end
        pcall(vim.api.nvim_win_set_cursor, 0, { bm.line, bm.col })
        vim.cmd("normal! zvzz")
      end
    end
  end

  local function edit_bookmark_note()
    if current_tab == "bookmarks" then
      local idx = get_selected_index()
      if idx >= 1 and idx <= #bm_list then
        local bm = bm_list[idx]
        vim.ui.input({
          prompt = string.format("Edit Note for Bookmark #%d: ", bm.id),
          default = bm.note,
        }, function(input)
          if input and vim.trim(input) ~= "" then
            bm.note = vim.trim(input)
            bookmarks.render_all_buffers()
            render()
          end
        end)
      end
    end
  end

  local function clear_all_action()
    if current_tab == "highlights" then
      engine.clear_all()
      render()
      vim.notify("[SmartHighlight] Cleared all highlight slots", vim.log.levels.INFO)
    else
      bookmarks.clear_all()
      render()
      vim.notify("[SmartBookmark] Cleared all bookmarks", vim.log.levels.INFO)
    end
  end

  local function add_action()
    if current_tab == "highlights" then
      vim.ui.input({ prompt = "Add Highlight Pattern (supports regex): " }, function(input)
        if input and input ~= "" then
          engine.add_slot(input, { is_regex = true, whole_word = false, name = input })
          render()
        end
      end)
    else
      bookmarks.toggle_interactive()
      render()
    end
  end

  local function switch_tab()
    current_tab = (current_tab == "highlights") and "bookmarks" or "highlights"
    render()
    vim.api.nvim_win_set_cursor(win, { 5, 2 })
  end

  local function export_qf_action()
    if current_tab == "highlights" then
      local picker = require("smart_highlighter.ui.picker")
      picker.open_bottom_pane()
    else
      bookmarks.open_bottom_pane("all")
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  render()
  vim.api.nvim_win_set_cursor(win, { 5, 2 })

  local k_opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", jump_selected_bookmark, k_opts)
  vim.keymap.set("n", "<Space>", toggle_selected, k_opts)
  vim.keymap.set("n", "<Tab>", switch_tab, k_opts)
  vim.keymap.set("n", "m", switch_tab, k_opts)
  vim.keymap.set("n", "M", switch_tab, k_opts)
  vim.keymap.set("n", "b", toggle_slot_scope_action, k_opts)
  vim.keymap.set("n", "B", toggle_default_scope_action, k_opts)
  vim.keymap.set("n", "d", delete_selected, k_opts)
  vim.keymap.set("n", "x", delete_selected, k_opts)
  vim.keymap.set("n", "e", edit_bookmark_note, k_opts)
  vim.keymap.set("n", "c", clear_all_action, k_opts)
  vim.keymap.set("n", "a", add_action, k_opts)
  vim.keymap.set("n", "+", add_action, k_opts)
  vim.keymap.set("n", "p", function()
    presets.select_preset_interactive()
    close()
  end, k_opts)
  vim.keymap.set("n", "Q", export_qf_action, k_opts)
  vim.keymap.set("n", "q", close, k_opts)
  vim.keymap.set("n", "<Esc>", close, k_opts)
end

return M
