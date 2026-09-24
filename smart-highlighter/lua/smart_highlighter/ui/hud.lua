local engine = require("smart_highlighter.core.engine")
local palette = require("smart_highlighter.core.palette")
local presets = require("smart_highlighter.core.presets")

local M = {}

---Open the interactive Floating HUD Manager
function M.open()
  local cur_buf = vim.api.nvim_get_current_buf()
  local summaries = engine.get_slot_summaries(cur_buf)

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "smarthighlight_hud"

  -- Calculate floating window dimensions
  local width = 72
  local height = math.max(12, math.min(#summaries + 8, 22))
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
    title = " 🎨 Smart Highlighter Manager ",
    title_pos = "center",
  })

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    summaries = engine.get_slot_summaries(cur_buf)

    local lines = {}
    table.insert(lines, "  SLOT  STATE  PATTERN / NAME               MATCHES   SCOPE      COLOR")
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
        local scope_str = item.scope:sub(1, 1):upper() .. item.scope:sub(2)

        local line = string.format("  #%-4d %s   %-26s %-9s %-10s %s", item.id, state_icon, pat_str, match_str, scope_str, item.color.name)
        table.insert(lines, line)
      end
    end

    table.insert(lines, "  " .. string.rep("─", width - 6))
    table.insert(lines, "  <Space>/<Tab> Toggle  |  d/x Delete  |  a Add Pattern  |  p Presets")
    table.insert(lines, "  q/Esc Close           |  c Clear All |  Q Export Quickfix")

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Apply syntax highlighting to the HUD window
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "SmartHighlightHUDHeader", 0, 0, -1)

    for idx, item in ipairs(summaries) do
      local line_idx = idx + 1
      local hl_name = string.format("SmartHighlightSlot%d", item.id)
      vim.api.nvim_buf_add_highlight(buf, -1, hl_name, line_idx, 2, 7)
      vim.api.nvim_buf_add_highlight(buf, -1, "SmartHighlightCount", line_idx, 38, 48)
    end
  end

  local function get_selected_item()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line_idx = cursor[1] - 2
    if line_idx >= 1 and line_idx <= #summaries then
      return summaries[line_idx]
    end
    return nil
  end

  local function toggle_selected()
    local item = get_selected_item()
    if item then
      engine.toggle_slot(item.id)
      render()
    end
  end

  local function delete_selected()
    local item = get_selected_item()
    if item then
      engine.remove_slot(item.id)
      render()
    end
  end

  local function clear_all_action()
    engine.clear_all()
    render()
    vim.notify("[SmartHighlight] Cleared all highlight slots", vim.log.levels.INFO)
  end

  local function add_pattern_action()
    vim.ui.input({ prompt = "Add Highlight Pattern (supports regex): " }, function(input)
      if input and input ~= "" then
        engine.add_slot(input, { is_regex = true, whole_word = false, name = input })
        render()
      end
    end)
  end

  local function export_qf_action()
    local picker = require("smart_highlighter.ui.picker")
    picker.export_to_quickfix()
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
  vim.api.nvim_win_set_cursor(win, { 3, 2 })

  local k_opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<Space>", toggle_selected, k_opts)
  vim.keymap.set("n", "<Tab>", toggle_selected, k_opts)
  vim.keymap.set("n", "d", delete_selected, k_opts)
  vim.keymap.set("n", "x", delete_selected, k_opts)
  vim.keymap.set("n", "c", clear_all_action, k_opts)
  vim.keymap.set("n", "a", add_pattern_action, k_opts)
  vim.keymap.set("n", "+", add_pattern_action, k_opts)
  vim.keymap.set("n", "p", function()
    presets.select_preset_interactive()
    close()
  end, k_opts)
  vim.keymap.set("n", "Q", export_qf_action, k_opts)
  vim.keymap.set("n", "q", close, k_opts)
  vim.keymap.set("n", "<Esc>", close, k_opts)
end

return M
