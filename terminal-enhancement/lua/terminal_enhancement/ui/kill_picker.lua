local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Open an interactive multi-select floating window to inspect, signal, kill processes, ports, or terminals
function M.open()
  local active = terminal.get_active_terminals()
  if #active == 0 then
    vim.notify("[TermEnhance] No running terminals to manage.", vim.log.levels.INFO)
    return
  end

  -- Selection state: map from terminal id -> boolean
  local selected = {}

  -- Create scratch unlisted buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal_kill_picker", { buf = buf })

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  -- Generous width so shell badges, process names, and listening ports fit cleanly
  local width = math.min(math.max(math.floor(total_w * 0.8), 85), total_w - 4)
  local height = math.min(#active + 6, math.floor(total_h * 0.7))
  local row = math.floor((total_h - height) / 2)
  local col = math.floor((total_w - width) / 2)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🛑 Terminal Process & Port Manager (Bash / PowerShell) ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title,CursorLine:Visual",
    { win = win }
  )

  local ns_id = vim.api.nvim_create_namespace("terminal_kill_picker")

  local function refresh_active()
    active = terminal.get_active_terminals()
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local lines = {}
    table.insert(lines, "  Keys: <Space>: mark | <t>: SIGTERM | <k>: SIGKILL | <c>: Ctrl+C | <p>: Kill Port | <CR>: Kill & Wipe | <q>: Exit")
    table.insert(lines, string.rep("─", width - 2))

    local marked_count = 0
    for _, item in ipairs(active) do
      local is_marked = selected[item.id] == true
      if is_marked then
        marked_count = marked_count + 1
      end
      local check = is_marked and "[✔]" or "[ ]"
      local state_icon = item.is_open and "🟢" or "⚪"
      local shell_badge = string.format("[%s]", item.shell_type or "bash")
      local pid_str = item.pid and string.format("(PID %d)", item.pid) or ""

      -- Child process info
      local proc_str = ""
      if item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
        proc_str = string.format(" ➔ %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid)
      end

      -- Listening ports
      local port_str = ""
      if item.ports and #item.ports > 0 then
        local p_list = {}
        for _, p in ipairs(item.ports) do
          table.insert(p_list, ":" .. p.port)
        end
        port_str = string.format(" 🎧 %s", table.concat(p_list, ","))
      end

      local def_badge = item.is_default and " ⭐ TARGET" or ""
      local line = string.format(" %s %s %s %s %s%s%s (Buf #%d)%s",
        check, state_icon, shell_badge, item.title, pid_str, proc_str, port_str, item.buf, def_badge)
      table.insert(lines, line)
    end

    table.insert(lines, string.rep("─", width - 2))
    table.insert(lines, string.format("  ➤ %d of %d terminal(s) marked | Press <t> for SIGTERM, <k> for SIGKILL, <p> to kill port", marked_count, #active))

    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    -- Highlights
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "FloatBorder", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "FloatBorder", #lines - 2, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, marked_count > 0 and "DiagnosticWarn" or "Comment", #lines - 1, 0, -1)

    for idx, item in ipairs(active) do
      local row_idx = idx + 1
      local is_marked = selected[item.id] == true
      if is_marked then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "DiagnosticError", row_idx, 1, 4)
      else
        vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", row_idx, 1, 4)
      end
      if item.is_default then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "DiagnosticWarn", row_idx, 0, -1)
      end
    end
  end

  local function get_item_at_cursor()
    if not vim.api.nvim_win_is_valid(win) then
      return nil, nil
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line_idx = cursor[1] - 2
    if line_idx >= 1 and line_idx <= #active then
      return active[line_idx], line_idx
    end
    return nil, nil
  end

  local function toggle_cursor()
    local item, _ = get_item_at_cursor()
    if item then
      selected[item.id] = not selected[item.id]
      render()
      local curr = vim.api.nvim_win_get_cursor(win)
      if curr[1] < #active + 2 then
        vim.api.nvim_win_set_cursor(win, { curr[1] + 1, curr[2] })
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
      local item, _ = get_item_at_cursor()
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

    -- Refresh display after brief pause to allow OS signal to take effect
    vim.defer_fn(function()
      refresh_active()
      render()
    end, 150)
  end

  -- Send interrupt (Ctrl+C)
  local function send_interrupt_action()
    local item, _ = get_item_at_cursor()
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
    local item, _ = get_item_at_cursor()
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

      -- Refresh after port reclamation
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
      local item, _ = get_item_at_cursor()
      if item then
        table.insert(targets, item.id)
      end
    end

    if #targets == 0 then
      vim.notify("[TermEnhance] No terminals selected to kill.", vim.log.levels.WARN)
      return
    end

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end

    local killed = 0
    for _, id in ipairs(targets) do
      local ok, _ = terminal.kill(id)
      if ok then
        killed = killed + 1
      end
    end

    vim.notify(string.format("[TermEnhance] 🧹 Terminated %d selected terminal(s) and reclaimed processes/ports.", killed), vim.log.levels.INFO)
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Initial render and cursor positioning
  render()
  vim.api.nvim_win_set_cursor(win, { 3, 2 })

  -- Keybindings inside the picker
  local k_opts = { buffer = buf, silent = true, noremap = true }
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
  vim.keymap.set("n", "q", close, k_opts)
  vim.keymap.set("n", "<Esc>", close, k_opts)
end

return M
