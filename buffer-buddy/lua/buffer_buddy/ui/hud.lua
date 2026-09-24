local inspector = require("buffer_buddy.core.inspector")
local pin = require("buffer_buddy.core.pin")
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

  local width = 74
  local height = 22
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui and ui.width or 80
  local win_height = ui and ui.height or 24
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

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

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    info = inspector.get_info(cur_buf)

    local pin_str = info.is_pinned and "📌 Pinned (Protected)" or "🔓 Unpinned"
    local mod_str = info.is_modified and "● Unsaved Changes" or "✓ Saved"
    local ro_str = info.is_readonly and "🔒 Read-Only" or "✏️ Modifiable"

    local lines = {
      "  📊 BUFFER METRICS & INTELLIGENCE",
      "  " .. string.rep("─", width - 6),
      string.format("  • Target Buffer: #%-4d %-30s", info.buf, info.short_name),
      string.format("  • Path:          %-45s", info.relative_path:sub(1, 45)),
      string.format("  • Stats:         %d lines  |  %d words  |  %s", info.lines, info.words, info.size_formatted),
      string.format("  • LLM Tokens:    ~%d estimated tokens", info.tokens),
      string.format("  • Type/Encoding: %s  |  %s [%s]", info.filetype:upper(), info.encoding:upper(), info.fileformat),
      string.format("  • Status:        %s  |  %s  |  %s", pin_str, mod_str, ro_str),
      "",
      "  🛠️ ACTIONS & TOOLKIT (Press Hotkey)",
      "  " .. string.rep("─", width - 6),
      "  [p] Toggle Pin Status        | [D] Diff vs Saved File Disk",
      "  [w] Trim Trailing Whitespace | [C] Diff vs Clipboard",
      "  [j] Format/Prettify JSON     | [S] Create Named Snapshot",
      "  [m] Minify JSON              | [R] Restore Snapshot Checkpoint",
      "  [d] Deduplicate Lines        | [U] Sweep Unmodified Buffers",
      "  [t] Align Markdown Table     | [H] Sweep Hidden Buffers",
      "  [6] Base64 Encode / Decode   | [O] Sweep Other Buffers",
      "  " .. string.rep("─", width - 6),
      "  [q / Esc] Close Dashboard",
    }

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Highlights
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 2, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 9, 2, -1)
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  render()

  local k_opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "p", function() pin.toggle_pin(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "w", function() transforms.trim_whitespace(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "j", function() transforms.json_format(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "m", function() transforms.json_minify(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "d", function() transforms.dedup_lines(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "t", function() transforms.format_markdown_table(cur_buf); render() end, k_opts)
  vim.keymap.set("n", "6", function()
    vim.ui.select({ "Encode Base64", "Decode Base64" }, { prompt = "Base64 Operation:" }, function(c)
      if c == "Encode Base64" then transforms.base64_encode(cur_buf) elseif c == "Decode Base64" then transforms.base64_decode(cur_buf) end
      render()
    end)
  end, k_opts)
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
