local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Open an interactive multi-select floating window with dual-pane live preview to inspect, signal, kill processes, ports, or terminals
function M.open()
  local active = terminal.get_active_terminals()
  if #active == 0 then
    vim.notify("[TermEnhance] No running terminals to manage.", vim.log.levels.INFO)
    return
  end

  -- Selection state: map from terminal id -> boolean
  local selected = {}

  -- Create scratch unlisted buffer for left list
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = list_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = list_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = list_buf })
  vim.api.nvim_set_option_value("filetype", "terminal_kill_picker", { buf = list_buf })

  -- Create scratch unlisted buffer for right preview
  local prev_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prev_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prev_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prev_buf })
  vim.api.nvim_set_option_value("filetype", "terminal_preview", { buf = prev_buf })

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local modal_w = math.min(math.max(math.floor(total_w * 0.90), 100), total_w - 4)
  local modal_h = math.min(#active + 8, math.floor(total_h * 0.75))
  local row = math.floor((total_h - modal_h) / 2)
  local col = math.floor((total_w - modal_w) / 2)

  local left_w = math.floor(modal_w * 0.48)
  local right_w = modal_w - left_w - 2

  local list_win_config = {
    relative = "editor",
    width = left_w,
    height = modal_h,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🛑 Terminal Process & Port Manager ",
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

  local ns_id = vim.api.nvim_create_namespace("terminal_kill_picker")

  local function close_all()
    if vim.api.nvim_win_is_valid(list_win) then
      pcall(vim.api.nvim_win_close, list_win, true)
    end
    if vim.api.nvim_win_is_valid(prev_win) then
      pcall(vim.api.nvim_win_close, prev_win, true)
    end
  end

  local function refresh_active()
    active = terminal.get_active_terminals()
  end

  local function get_item_under_cursor()
    if not vim.api.nvim_win_is_valid(list_win) then
      return nil, nil
    end
    local cursor = vim.api.nvim_win_get_cursor(list_win)
    local line_idx = cursor[1] - 2
    if line_idx >= 1 and line_idx <= #active then
      return active[line_idx], line_idx
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
    elseif item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
      table.insert(lines, string.format("➔ Foreground: %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid))
    end
    if item.ports and #item.ports > 0 then
      local pl = {}
      for _, p in ipairs(item.ports) do
        table.insert(pl, ":" .. p.port)
      end
      table.insert(lines, string.format("🎧 Listening Ports: %s", table.concat(pl, ", ")))
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
    table.insert(lines, " <Space>: mark | <t>: SIGTERM | <k>: SIGKILL | <c>: Ctrl+C | <p>: Kill Port | <CR>: Kill")
    table.insert(lines, string.rep("─", left_w - 2))

    local marked_count = 0
    for _, item in ipairs(active) do
      local is_marked = selected[item.id] == true
      if is_marked then
        marked_count = marked_count + 1
      end
      local check = is_marked and "[✔]" or "[ ]"
      local state_icon = item.is_open and "🟢" or "⚪"
      local shell_badge = string.format("[%s]", item.shell_type or "bash")
      local pid_str = item.pid and string.format("(%d)", item.pid) or ""

      -- Listening ports
      local port_str = ""
      if item.ports and #item.ports > 0 then
        local p_list = {}
        for _, p in ipairs(item.ports) do
          table.insert(p_list, ":" .. p.port)
        end
        port_str = string.format(" 🎧 %s", table.concat(p_list, ","))
      end

      local def_badge = item.is_default and " ⭐" or ""
      local line = string.format(" %s %s %s %s %s%s (Buf #%d)%s",
        check, state_icon, shell_badge, item.title, pid_str, port_str, item.buf, def_badge)
      table.insert(lines, line)
    end

    table.insert(lines, string.rep("─", left_w - 2))
    table.insert(lines, string.format(" ➤ %d of %d marked | <t>: SIGTERM, <k>: SIGKILL, <p>: kill port", marked_count, #active))

    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)

    -- Highlights
    vim.api.nvim_buf_clear_namespace(list_buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(list_buf, ns_id, "Comment", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(list_buf, ns_id, "FloatBorder", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(list_buf, ns_id, "FloatBorder", #lines - 2, 0, -1)
    vim.api.nvim_buf_add_highlight(list_buf, ns_id, marked_count > 0 and "DiagnosticWarn" or "Comment", #lines - 1, 0, -1)

    for idx, item in ipairs(active) do
      local row_idx = idx + 1
      local is_marked = selected[item.id] == true
      if is_marked then
        vim.api.nvim_buf_add_highlight(list_buf, ns_id, "DiagnosticError", row_idx, 1, 4)
      else
        vim.api.nvim_buf_add_highlight(list_buf, ns_id, "Comment", row_idx, 1, 4)
      end
      if item.is_default then
        vim.api.nvim_buf_add_highlight(list_buf, ns_id, "DiagnosticWarn", row_idx, 0, -1)
      end
    end

    update_preview()
  end

  local function toggle_cursor()
    local item, _ = get_item_under_cursor()
    if item then
      selected[item.id] = not selected[item.id]
      render()
      local curr = vim.api.nvim_win_get_cursor(list_win)
      if curr[1] < #active + 2 then
        pcall(vim.api.nvim_win_set_cursor, list_win, { curr[1] + 1, curr[2] })
      end
    end
  end

  local function toggle_all()
    local all_marked = true
    for _, item in ipairs(active) do
      if not selected[item.id] then
        all_marked = false
        break
      end
    end

    for _, item in ipairs(active) do
      selected[item.id] = not all_marked
    end
    render()
  end

  local function toggle_hidden()
    for _, item in ipairs(active) do
      if not item.is_open then
        selected[item.id] = true
      end
    end
    render()
  end

  local function invert_selection()
    for _, item in ipairs(active) do
      selected[item.id] = not selected[item.id]
    end
    render()
  end

  -- Send signal (SIGTERM, SIGKILL, etc.) to marked or cursor terminal process tree
  local function send_signal_action(sig_num, sig_name)
    local targets = {}
    for _, item in ipairs(active) do
      if selected[item.id] then
        table.insert(targets, item)
      end
    end
    if #targets == 0 then
      local item, _ = get_item_under_cursor()
      if item then
        table.insert(targets, item)
      end
    end

    if #targets == 0 then
      vim.notify("[TermEnhance] No terminal selected.", vim.log.levels.WARN)
      return
    end

    local count = 0
    for _, item in ipairs(targets) do
      local ok, msg = terminal.send_signal(item.id, sig_num)
      if ok then
        count = count + 1
      end
    end

    vim.notify(string.format("[TermEnhance] 📡 Sent %s (%d) to %d terminal process tree(s).", sig_name, sig_num, count), vim.log.levels.INFO)

    vim.defer_fn(function()
      refresh_active()
      render()
    end, 150)
  end

  -- Send interrupt (Ctrl+C)
  local function send_interrupt_action()
    local item, _ = get_item_under_cursor()
    if not item then
      vim.notify("[TermEnhance] No terminal under cursor.", vim.log.levels.WARN)
      return
    end

    local ok, msg = terminal.send_interrupt(item.id)
    if ok then
      vim.notify("[TermEnhance] ⚡ " .. msg, vim.log.levels.INFO)
    end

    vim.defer_fn(function()
      refresh_active()
      render()
    end, 150)
  end

  -- Kill listening port action
  local function kill_port_action()
    local item, _ = get_item_under_cursor()
    if not item then
      vim.notify("[TermEnhance] No terminal selected.", vim.log.levels.WARN)
      return
    end

    local prefill = ""
    if item.ports and #item.ports > 0 then
      prefill = tostring(item.ports[1].port)
    end

    local prompt_msg = string.format("Kill Port [%s]%s: ", item.shell_type or "bash", prefill ~= "" and (" (detected: " .. prefill .. ")") or "")

    vim.ui.input({ prompt = prompt_msg, default = prefill }, function(input)
      if not input or input == "" then
        return
      end
      local port = tonumber(vim.trim(input))
      if not port then
        vim.notify(string.format("[TermEnhance] Invalid port: '%s'", input), vim.log.levels.WARN)
        return
      end

      local ok, msg = terminal.kill_port(port, 15, item.id)
      if ok then
        vim.notify("[TermEnhance] 🛑 " .. msg, vim.log.levels.INFO)
      else
        vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
      end

      vim.defer_fn(function()
        refresh_active()
        render()
      end, 200)
    end)
  end

  -- Execute full terminal teardown (process tree + port + buffer wipe)
  local function execute_kill()
    local targets = {}
    for _, item in ipairs(active) do
      if selected[item.id] then
        table.insert(targets, item.id)
      end
    end

    if #targets == 0 then
      local item, _ = get_item_under_cursor()
      if item then
        table.insert(targets, item.id)
      end
    end

    if #targets == 0 then
      vim.notify("[TermEnhance] No terminals selected to kill.", vim.log.levels.WARN)
      return
    end

    close_all()

    local killed = 0
    for _, id in ipairs(targets) do
      local ok, _ = terminal.kill(id)
      if ok then
        killed = killed + 1
      end
    end

    vim.notify(string.format("[TermEnhance] 🧹 Terminated %d selected terminal(s) and reclaimed processes/ports.", killed), vim.log.levels.INFO)
  end

  -- Initial render and cursor positioning
  render()
  pcall(vim.api.nvim_win_set_cursor, list_win, { 3, 2 })

  -- Update preview on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = update_preview,
  })

  -- Keybindings inside the picker
  local k_opts = { buffer = list_buf, silent = true, noremap = true }
  vim.keymap.set("n", "<Space>", toggle_cursor, k_opts)
  vim.keymap.set("n", "<Tab>", toggle_cursor, k_opts)
  vim.keymap.set("n", "a", toggle_all, k_opts)
  vim.keymap.set("n", "h", toggle_hidden, k_opts)
  vim.keymap.set("n", "v", invert_selection, k_opts)
  vim.keymap.set("n", "t", function() send_signal_action(15, "SIGTERM") end, k_opts)
  vim.keymap.set("n", "k", function() send_signal_action(9, "SIGKILL") end, k_opts)
  vim.keymap.set("n", "c", send_interrupt_action, k_opts)
  vim.keymap.set("n", "p", kill_port_action, k_opts)
  vim.keymap.set("n", "<CR>", execute_kill, k_opts)
  vim.keymap.set("n", "d", execute_kill, k_opts)
  vim.keymap.set("n", "x", execute_kill, k_opts)
  vim.keymap.set("n", "q", close_all, k_opts)
  vim.keymap.set("n", "<Esc>", close_all, k_opts)
end

return M
