local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Open an interactive multi-select floating window with live preview to check and unhide hidden terminals
function M.open()
  local active = terminal.get_active_terminals()
  local hidden_list = {}
  for _, item in ipairs(active) do
    if not item.is_open then
      table.insert(hidden_list, item)
    end
  end

  if #hidden_list == 0 then
    vim.notify("[TermEnhance] No hidden terminals to unhide. All active terminals are currently visible.", vim.log.levels.INFO)
    return
  end

  -- Selection state: map from terminal id -> boolean
  local selected = {}

  -- Create scratch unlisted buffer for left list
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = list_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = list_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = list_buf })
  vim.api.nvim_set_option_value("filetype", "terminal_unhide_picker", { buf = list_buf })

  -- Create scratch buffer for right preview pane
  local prev_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prev_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prev_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prev_buf })
  vim.api.nvim_set_option_value("filetype", "terminal_preview", { buf = prev_buf })

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local modal_w = math.min(math.max(math.floor(total_w * 0.90), 100), total_w - 4)
  local modal_h = math.min(#hidden_list + 8, math.floor(total_h * 0.75))
  local row = math.floor((total_h - modal_h) / 2)
  local col = math.floor((total_w - modal_w) / 2)

  local left_w = math.floor(modal_w * 0.45)
  local right_w = modal_w - left_w - 2

  local list_win_config = {
    relative = "editor",
    width = left_w,
    height = modal_h,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 👁️ Unhide Terminals (Check to Restore) ",
    title_pos = "center",
  }

  local prev_win_config = {
    relative = "editor",
    width = right_w,
    height = modal_h,
    row = row,
    col = col + left_w + 2,
    style = "minimal",
    border = "rounded",
    title = " 📄 Live Terminal Output Preview ",
    title_pos = "center",
  }

  local list_win = vim.api.nvim_open_win(list_buf, true, list_win_config)
  local prev_win = vim.api.nvim_open_win(prev_buf, false, prev_win_config)

  vim.api.nvim_set_option_value("cursorline", true, { win = list_win })
  vim.api.nvim_set_option_value("number", false, { win = list_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = list_win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title,CursorLine:Visual",
    { win = list_win }
  )

  vim.api.nvim_set_option_value("number", false, { win = prev_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = prev_win })
  vim.api.nvim_set_option_value("wrap", true, { win = prev_win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title",
    { win = prev_win }
  )

  local ns_id = vim.api.nvim_create_namespace("terminal_unhide_picker")

  local function close_all()
    if vim.api.nvim_win_is_valid(list_win) then
      pcall(vim.api.nvim_win_close, list_win, true)
    end
    if vim.api.nvim_win_is_valid(prev_win) then
      pcall(vim.api.nvim_win_close, prev_win, true)
    end
  end

  local function get_item_under_cursor()
    if not vim.api.nvim_win_is_valid(list_win) then
      return nil, nil
    end
    local cursor = vim.api.nvim_win_get_cursor(list_win)
    local line_idx = cursor[1] - 2 -- adjust for 2 header lines
    if line_idx >= 1 and line_idx <= #hidden_list then
      return hidden_list[line_idx], line_idx
    end
    return nil, nil
  end

  local function update_preview()
    if not vim.api.nvim_buf_is_valid(prev_buf) or not vim.api.nvim_win_is_valid(prev_win) then
      return
    end

    local item = get_item_under_cursor()
    if not item then
      vim.api.nvim_buf_set_lines(prev_buf, 0, -1, false, { "  (No terminal selected)" })
      return
    end

    local lines = {}
    table.insert(lines, string.format("🖥️  Terminal ID: %s   [%s]", item.id, item.shell_type or "bash"))
    if item.pid then
      table.insert(lines, string.format("⚙️  PID: %d", item.pid))
    end
    if item.cwd and item.cwd ~= "" then
      table.insert(lines, string.format("📁 CWD: %s", item.cwd))
    end
    if item.last_cmd and item.last_cmd ~= "" then
      local dur_s = (item.last_duration and item.last_duration ~= "") and string.format(" (⏱️ %s)", item.last_duration) or ""
      table.insert(lines, string.format("⚡ Last Command: %s%s", item.last_cmd, dur_s))
    end
    if item.ports and #item.ports > 0 then
      local pl = {}
      for _, p in ipairs(item.ports) do
        table.insert(pl, ":" .. p.port)
      end
      table.insert(lines, string.format("🎧 Ports: %s", table.concat(pl, ", ")))
    end
    table.insert(lines, string.rep("─", right_w - 4))
    table.insert(lines, "")

    -- Fetch live buffer lines from terminal
    if item.buf and vim.api.nvim_buf_is_valid(item.buf) then
      local total_lines = vim.api.nvim_buf_line_count(item.buf)
      local max_lines = 60
      local start_line = math.max(0, total_lines - max_lines)
      local term_lines = vim.api.nvim_buf_get_lines(item.buf, start_line, total_lines, false)

      table.insert(lines, string.format("--- Live Terminal Output (Buffer #%d, %d lines) ---", item.buf, total_lines))
      table.insert(lines, "")
      for _, l in ipairs(term_lines) do
        table.insert(lines, l)
      end
    else
      table.insert(lines, "  [Terminal buffer not available]")
    end

    vim.api.nvim_buf_set_lines(prev_buf, 0, -1, false, lines)
    pcall(vim.api.nvim_win_set_cursor, prev_win, { #lines, 0 })
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(list_buf) then
      return
    end

    local lines = {}
    table.insert(lines, " <Space>: check | <a>: all | <CR>: unhide | <q>: exit")
    table.insert(lines, string.rep("─", left_w - 2))

    local marked_count = 0
    for _, item in ipairs(hidden_list) do
      local is_marked = selected[item.id] == true
      if is_marked then
        marked_count = marked_count + 1
      end
      local check = is_marked and "[✔]" or "[ ]"
      local shell_badge = string.format("[%s]", item.shell_type or "bash")
      local def_badge = item.is_default and " ⭐" or ""

      local line = string.format(" %s ⚪ %s %s%s", check, shell_badge, item.title, def_badge)
      table.insert(lines, line)
    end

    table.insert(lines, string.rep("─", left_w - 2))
    table.insert(lines, string.format(" %d hidden total • %d marked to unhide", #hidden_list, marked_count))

    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)

    for idx, item in ipairs(hidden_list) do
      local line_idx = idx + 1
      local is_marked = selected[item.id] == true
      if is_marked then
        vim.api.nvim_buf_add_highlight(list_buf, ns_id, "DiagnosticOk", line_idx, 1, 4)
      else
        vim.api.nvim_buf_add_highlight(list_buf, ns_id, "Comment", line_idx, 1, 4)
      end
      vim.api.nvim_buf_add_highlight(list_buf, ns_id, "Keyword", line_idx, 7, 7 + #(item.shell_type or "bash") + 2)
    end

    update_preview()
  end

  render()
  pcall(vim.api.nvim_win_set_cursor, list_win, { 3, 1 })

  -- Update live preview on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = update_preview,
  })

  local function get_targets_to_unhide()
    local targets = {}
    for _, item in ipairs(hidden_list) do
      if selected[item.id] then
        table.insert(targets, item)
      end
    end
    if #targets == 0 then
      local cur_item = get_item_under_cursor()
      if cur_item then
        table.insert(targets, cur_item)
      end
    end
    return targets
  end

  local function perform_unhide(direction)
    local targets = get_targets_to_unhide()
    if #targets == 0 then
      vim.notify("[TermEnhance] No terminals selected to unhide.", vim.log.levels.WARN)
      return
    end

    close_all()

    for _, target in ipairs(targets) do
      terminal.show(target.id, direction, true)
    end

    vim.notify(string.format("[TermEnhance] Restored & unhidden %d terminal(s)", #targets), vim.log.levels.INFO)
  end

  local k_opts = { buffer = list_buf, nowait = true, silent = true }

  vim.keymap.set("n", "<Space>", function()
    local item = get_item_under_cursor()
    if item then
      selected[item.id] = not selected[item.id]
      render()
    end
  end, k_opts)

  vim.keymap.set("n", "a", function()
    local all_marked = true
    for _, item in ipairs(hidden_list) do
      if not selected[item.id] then
        all_marked = false
        break
      end
    end
    for _, item in ipairs(hidden_list) do
      selected[item.id] = not all_marked
    end
    render()
  end, k_opts)

  vim.keymap.set("n", "<CR>", function() perform_unhide(nil) end, k_opts)
  vim.keymap.set("n", "f", function() perform_unhide("float") end, k_opts)
  vim.keymap.set("n", "h", function() perform_unhide("horizontal") end, k_opts)
  vim.keymap.set("n", "v", function() perform_unhide("vertical") end, k_opts)
  vim.keymap.set("n", "q", close_all, k_opts)
  vim.keymap.set("n", "<Esc>", close_all, k_opts)
end

return M
