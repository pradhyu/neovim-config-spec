local inspector = require("buffer_buddy.core.inspector")
local pin = require("buffer_buddy.core.pin")
local tabs = require("buffer_buddy.core.tabs")
local hygiene = require("buffer_buddy.core.hygiene")
local transforms = require("buffer_buddy.core.transforms")
local snapshot = require("buffer_buddy.core.snapshot")
local diff = require("buffer_buddy.core.diff")

local M = {}

---Open the interactive Buffer Buddy Dashboard & Inspector
function M.open()
  local cur_buf = vim.api.nvim_get_current_buf()
  local info = inspector.get_info(cur_buf)

  if not info.valid then
    vim.notify("[BufferBuddy] Invalid buffer to inspect", vim.log.levels.WARN)
    return
  end

  local width = 78
  local height = 26
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui and ui.width or 80
  local win_height = ui and ui.height or 28
  local row = math.max(1, math.floor((win_height - height) / 2))
  local col = math.max(1, math.floor((win_width - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "bufferbuddy_hud"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" 🛡️ Buffer Buddy: %s ", info.short_name),
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    info = inspector.get_info(cur_buf)

    local is_global = pin.is_global(cur_buf)
    local pin_str = is_global and "🌐 Pinned (Global/All Tabs)"
      or (info.is_pinned and "📌 Pinned (Workspace)" or "🔓 Unpinned")
    local mod_str = info.is_modified and "● Unsaved Changes" or "✓ Saved"
    local ro_str = info.is_readonly and "🔒 Read-Only" or "✏️ Modifiable"

    -- Gather tabs info
    local tabs_info = tabs.get_all_tabs_info()
    local tab_items = {}
    local active_tab_num = 1
    local active_tab_name = "Tab 1"
    local active_tab_bufs_count = 0

    for _, t in ipairs(tabs_info) do
      local marker = t.is_active and "*" or ""
      table.insert(tab_items, string.format("[%d] %s%s (%d)", t.num, t.name, marker, #t.buffers))
      if t.is_active then
        active_tab_num = t.num
        active_tab_name = t.name
        active_tab_bufs_count = #t.buffers
      end
    end

    local tab_summary = table.concat(tab_items, "  ")
    if #tab_summary > width - 8 then
      tab_summary = tab_summary:sub(1, width - 11) .. "..."
    end

    local lines = {
      "  📊 BUFFER INTELLIGENCE",
      "  " .. string.rep("─", width - 6),
      string.format("  • Target Buffer: #%-4d %-30s", info.buf, info.short_name),
      string.format("  • Path:          %-45s", info.relative_path:sub(1, 45)),
      string.format("  • Stats:         %d lines  |  %d words  |  %s", info.lines, info.words, info.size_formatted),
      string.format("  • LLM Tokens:    ~%d estimated tokens", info.tokens),
      string.format("  • Type/Encoding: %s  |  %s [%s]", info.filetype:upper(), info.encoding:upper(), info.fileformat),
      string.format("  • Status:        %s  |  %s  |  %s", pin_str, mod_str, ro_str),
      "",
      "  📑 WORKSPACE TABS",
      "  " .. string.rep("─", width - 6),
      string.format("  • Active Tab:    Tab %d [%s] (%d active buffers)", active_tab_num, active_tab_name, active_tab_bufs_count),
      string.format("  • Workspaces:    %s", tab_summary),
      "",
      "  🛠️ WORKSPACE & TAB ACTIONS",
      "  " .. string.rep("─", width - 6),
      "  [n] Rename Workspace Tab      | [m] Move Buffer to Tab",
      "  [N] New Workspace Tab         | [u] Sweep Tab Unmodified",
      "  [P] Toggle Global Pin (🌐)    | [x] Safe Tab Close & Clean",
      "  [1-9] Switch Directly to Tab  | [p] Toggle Local Pin (📌)",
      "",
      "  🔧 GENERAL ACTIONS & TOOLKIT",
      "  " .. string.rep("─", width - 6),
      "  [w] Trim Trailing Whitespace  | [D] Diff vs Saved File Disk",
      "  [j] Format/Prettify JSON      | [C] Diff vs Clipboard",
      "  [m] Minify JSON               | [S] Create Named Snapshot",
      "  [d] Deduplicate Lines         | [R] Restore Snapshot",
      "  [t] Align Markdown Table      | [b] Toggle Breadcrumbs (🍞)",
      "  " .. string.rep("─", width - 6),
      "  [U] Sweep All Tabs Unmodified | [q / Esc] Close Dashboard",
    }

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Highlights
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 2, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 9, 2, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 14, 2, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 21, 2, -1)
  end

  render()

  local k_opts = { buffer = buf, silent = true, noremap = true }

  -- Pinning
  vim.keymap.set("n", "p", function() pin.toggle_pin(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "P", function() pin.toggle_global(cur_buf); render() end, k_opts)

  -- Workspace & Tabs
  vim.keymap.set("n", "n", function() tabs.rename_tab_interactive(); render() end, k_opts)
  vim.keymap.set("n", "N", function() close(); tabs.new_tab() end, k_opts)
  vim.keymap.set("n", "m", function() tabs.move_buffer_interactive(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "u", function() hygiene.close_tab_unmodified(); render() end, k_opts)
  vim.keymap.set("n", "x", function() close(); tabs.close_tab_safe() end, k_opts)

  -- Number keys 1-9 to jump to tab
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      local all = vim.api.nvim_list_tabpages()
      if i <= #all then
        close()
        vim.api.nvim_set_current_tabpage(all[i])
      else
        vim.notify(string.format("[BufferBuddy] Tab %d does not exist", i), vim.log.levels.WARN)
      end
    end, k_opts)
  end

  -- Transforms & Diffs
  vim.keymap.set("n", "w", function() transforms.trim_whitespace(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "j", function() transforms.json_format(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "d", function() transforms.dedup_lines(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "t", function() transforms.format_markdown_table(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "b", function() require("buffer_buddy.ui.breadcrumbs").toggle(); render() end, k_opts)
  vim.keymap.set("n", "D", function() close(); diff.diff_disk(cur_buf) end, k_opts)
  vim.keymap.set("n", "C", function() close(); diff.diff_clipboard(cur_buf) end, k_opts)
  vim.keymap.set("n", "S", function()
    vim.ui.input({ prompt = "Snapshot Name: " }, function(input)
      snapshot.create_snapshot(input ~= "" and input or nil, cur_buf)
      render()
    end)
  end, k_opts)
  vim.keymap.set("n", "R", function() close(); snapshot.select_snapshot_interactive(cur_buf) end, k_opts)
  vim.keymap.set("n", "U", function() hygiene.close_unmodified(); render() end, k_opts)
  vim.keymap.set("n", "H", function() hygiene.close_hidden(); render() end, k_opts)
  vim.keymap.set("n", "O", function() hygiene.close_others(); render() end, k_opts)
  vim.keymap.set("n", "q", close, k_opts)
  vim.keymap.set("n", "<Esc>", close, k_opts)
end

return M
