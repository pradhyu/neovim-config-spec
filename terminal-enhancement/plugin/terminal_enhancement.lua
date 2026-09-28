-- Automatic command registration for terminal_enhancement.nvim
local term_enh = require("terminal_enhancement")
local config = require("terminal_enhancement.config")

vim.api.nvim_create_user_command("TermToggle", function(opts)
  local dir = opts.args ~= "" and opts.args:lower() or nil
  term_enh.toggle(dir)
end, {
  nargs = "?",
  complete = function()
    return { "float", "horizontal", "vertical" }
  end,
  desc = "Toggle persistent terminal (float, horizontal, vertical)",
})

vim.api.nvim_create_user_command("TermFloat", function()
  term_enh.toggle("float")
end, { desc = "Open floating terminal" })

vim.api.nvim_create_user_command("TermSplit", function(opts)
  local dir = opts.args ~= "" and opts.args:lower() or "horizontal"
  term_enh.toggle(dir)
end, {
  nargs = "?",
  complete = function()
    return { "horizontal", "vertical" }
  end,
  desc = "Open split terminal",
})

vim.api.nvim_create_user_command("TermHide", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  term_enh.hide(arg)
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Hide terminal window (current or specified) without closing process",
})

vim.api.nvim_create_user_command("TermHideAll", function()
  term_enh.hide_all()
end, {
  desc = "Hide all open terminal windows without terminating background jobs",
})

vim.api.nvim_create_user_command("TermShow", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  term_enh.show(arg)
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Show/open hidden terminal without restarting or killing session",
})

vim.api.nvim_create_user_command("TermShowAll", function(opts)
  local dir = opts.args ~= "" and opts.args:lower() or nil
  term_enh.show_all(dir)
end, {
  nargs = "?",
  complete = function()
    return { "float", "horizontal", "vertical" }
  end,
  desc = "Unhide and show all hidden terminal windows at once",
})

vim.api.nvim_create_user_command("TermUnhideAll", function(opts)
  local dir = opts.args ~= "" and opts.args:lower() or nil
  term_enh.show_all(dir)
end, {
  nargs = "?",
  complete = function()
    return { "float", "horizontal", "vertical" }
  end,
  desc = "Unhide and show all hidden terminal windows at once",
})

vim.api.nvim_create_user_command("TermUnhide", function()
  term_enh.unhide_picker()
end, {
  desc = "Interactive multi-select picker to inspect, check, and unhide hidden terminals",
})

vim.api.nvim_create_user_command("TermShowPicker", function()
  term_enh.unhide_picker()
end, {
  desc = "Interactive multi-select picker to inspect, check, and unhide hidden terminals",
})

vim.api.nvim_create_user_command("TermTool", function(opts)
  local tool = opts.args
  if tool == "" then
    vim.notify("[TermEnhance] Specify tool name: lazygit, htop, agy, python, node", vim.log.levels.WARN)
    return
  end
  term_enh.open_tool(tool)
end, {
  nargs = 1,
  complete = function(_, line)
    local matches = {}
    local input = line:match("TermTool%s+(.*)$") or ""
    for name, _ in pairs(config.options.tools) do
      if vim.startswith(name, input) then
        table.insert(matches, name)
      end
    end
    return matches
  end,
  desc = "Open dedicated tool terminal (lazygit, htop, agy, etc.)",
})

vim.api.nvim_create_user_command("TermPrompt", function(opts)
  term_enh.prompt({ initial_text = opts.args })
end, {
  nargs = "?",
  desc = "Interactive command bar with Fish-like live dimmed autocomplete & history ghost text",
})

vim.api.nvim_create_user_command("TermExec", function(opts)
  term_enh.prompt({ initial_text = opts.args })
end, {
  nargs = "?",
  desc = "Interactive command runner with Fish-like ghost text completion",
})

vim.api.nvim_create_user_command("TermRun", function(opts)
  if opts.args == "" then
    term_enh.prompt()
    return
  end
  term_enh.run(opts.args)
end, {
  nargs = "*",
  desc = "Run shell command in terminal (opens Fish ghost-text prompt if no command provided)",
})

vim.api.nvim_create_user_command("TermSend", function(opts)
  local subcmd = opts.args ~= "" and opts.args:lower() or nil

  if subcmd == "line" then
    term_enh.send_line()
  elseif subcmd == "block" then
    term_enh.send_block()
  elseif subcmd == "step" then
    term_enh.send_step()
  elseif subcmd == "file" then
    term_enh.send_file()
  elseif subcmd == "visual" then
    term_enh.send_visual()
  elseif subcmd == "last" or subcmd == "outcome" then
    term_enh.show_last_output()
  elseif subcmd == "history" then
    term_enh.show_history()
  elseif subcmd == "copy_output" or subcmd == "copy" then
    term_enh.copy_last_output()
  elseif subcmd == "copy_command" or subcmd == "copy_cmd" then
    term_enh.copy_last_command()
  elseif subcmd == "paste_output" or subcmd == "paste" then
    term_enh.paste_last_output()
  elseif subcmd == "toggle_copy" then
    term_enh.toggle_copy_output()
  elseif subcmd == "toggle_paste" then
    term_enh.toggle_paste_output()
  elseif opts.range ~= 0 then
    term_enh.send_selection(opts.line1, opts.line2, "raw")
  else
    term_enh.send_line()
  end
end, {
  range = true,
  nargs = "?",
  complete = function()
    return {
      "line",
      "block",
      "step",
      "file",
      "visual",
      "last",
      "outcome",
      "history",
      "copy_output",
      "copy_command",
      "paste_output",
      "toggle_copy",
      "toggle_paste",
    }
  end,
  desc = "Send code (line, block, step, file, visual) or manage outcome history",
})

vim.api.nvim_create_user_command("TermSendLine", function()
  term_enh.send_line()
end, { desc = "Send current line or inline command with prompt stripping" })

vim.api.nvim_create_user_command("TermSendBlock", function()
  term_enh.send_block()
end, { desc = "Send current code block (Markdown fence or Treesitter node)" })

vim.api.nvim_create_user_command("TermSendStep", function()
  term_enh.send_step()
end, { desc = "Send current command and step cursor to next line" })

vim.api.nvim_create_user_command("TermSendFile", function()
  term_enh.send_file()
end, { desc = "Send entire buffer/file to target terminal" })

vim.api.nvim_create_user_command("TermOutcome", function()
  term_enh.show_last_output()
end, { desc = "Show floating modal of the last terminal execution outcome" })

vim.api.nvim_create_user_command("TermHistory", function()
  term_enh.show_history()
end, { desc = "Show interactive terminal execution history" })

vim.api.nvim_create_user_command("TermCopyOutput", function()
  term_enh.copy_last_output()
end, { desc = "Copy last terminal execution outcome to clipboard" })

vim.api.nvim_create_user_command("TermPasteOutput", function()
  term_enh.paste_last_output()
end, { desc = "Paste last terminal execution outcome as commented lines below cursor" })

vim.api.nvim_create_user_command("TermToggleCopy", function()
  term_enh.toggle_copy_output()
end, { desc = "Toggle auto-copying outcome to clipboard" })

vim.api.nvim_create_user_command("TermTogglePaste", function()
  term_enh.toggle_paste_output()
end, { desc = "Toggle auto-pasting outcome into buffer" })

vim.api.nvim_create_user_command("TermSendJoined", function(opts)
  local mode = (opts.args == "and" or opts.args == "&&") and "join_and" or "join_continuation"
  term_enh.send_joined(opts.line1, opts.line2, mode)
end, {
  range = true,
  nargs = "?",
  complete = function()
    return { "continuation", "and" }
  end,
  desc = "Send lines joined with line continuation (\\ or `) or &&",
})

vim.api.nvim_create_user_command("TermSelect", function()
  term_enh.filter_interactive()
end, {
  desc = "Interactive quick-filter modal to search and switch target terminal",
})

vim.api.nvim_create_user_command("TermPicker", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  term_enh.filter_interactive({ use_snacks = (arg == "snacks") })
end, {
  nargs = "?",
  complete = function()
    return { "native", "snacks" }
  end,
  desc = "Open interactive live-filter terminal switcher: :TermPicker [native|snacks]",
})

vim.api.nvim_create_user_command("TermSwitch", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  if arg then
    term_enh.focus(arg)
  else
    term_enh.filter_interactive()
  end
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Switch to terminal by name or open live filter picker: :TermSwitch [term_id]",
})

vim.api.nvim_create_user_command("TermFind", function()
  term_enh.filter_interactive()
end, {
  desc = "Live filter and search active terminals",
})

vim.api.nvim_create_user_command("TermTarget", function(opts)
  local arg = opts.args
  if arg and arg ~= "" then
    require("terminal_enhancement.core.terminal").set_default_target(arg)
  else
    term_enh.filter_interactive()
  end
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Set or switch default target terminal for code execution",
})

vim.api.nvim_create_user_command("TermBuffer", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  require("terminal_enhancement.core.terminal").open_as_buffer(arg)
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Open terminal directly into current window as a regular buffer",
})

vim.api.nvim_create_user_command("TermList", function()
  term_enh.filter_interactive()
end, {
  desc = "List and switch active terminal instances (Interactive Switcher)",
})

vim.api.nvim_create_user_command("TermKill", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  if arg then
    local ok, msg = term_enh.kill(arg)
    if ok then
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.INFO)
    else
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
    end
  else
    term_enh.kill_interactive()
  end
end, {
  nargs = "?",
  complete = function()
    local matches = { "hidden", "all" }
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Kill terminal buffer/process or open interactive kill selector",
})

vim.api.nvim_create_user_command("TermClean", function()
  term_enh.kill_hidden()
end, {
  desc = "Kill and purge all hidden/background terminal buffers",
})

vim.api.nvim_create_user_command("TermKillHidden", function()
  term_enh.kill_hidden()
end, {
  desc = "Kill and purge all hidden/background terminal buffers",
})

vim.api.nvim_create_user_command("TermKillAll", function()
  term_enh.kill_all()
end, {
  desc = "Kill and terminate all active terminal sessions",
})

vim.api.nvim_create_user_command("TermRename", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  term_enh.rename_interactive(arg)
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Rename terminal session or open interactive rename prompt",
})

vim.api.nvim_create_user_command("TermKillPort", function(opts)
  local args = vim.split(vim.trim(opts.args), "%s+")
  local port = tonumber(args[1])
  local sig = args[2]

  if not port then
    term_enh.kill_port_interactive()
    return
  end

  local ok, msg = term_enh.kill_port(port, sig)
  if ok then
    vim.notify("[TermEnhance] 🛑 " .. msg, vim.log.levels.INFO)
  else
    vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
  end
end, {
  nargs = "*",
  desc = "Kill process listening on a port: :TermKillPort <port> [signal]",
})

vim.api.nvim_create_user_command("TermSignal", function(opts)
  local args = vim.split(vim.trim(opts.args), "%s+")
  local sig = args[1]
  local term_id = args[2]

  if not sig or sig == "" then
    term_enh.send_signal_interactive(term_id)
    return
  end

  local ok, msg = term_enh.send_signal(term_id, sig)
  if ok then
    vim.notify("[TermEnhance] 📡 " .. msg, vim.log.levels.INFO)
  else
    vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
  end
end, {
  nargs = "*",
  complete = function()
    return { "SIGTERM", "SIGKILL", "SIGINT", "SIGHUP", "SIGQUIT", "SIGSTOP", "SIGCONT" }
  end,
  desc = "Send POSIX signal to terminal process: :TermSignal <signal> [term_id]",
})

vim.api.nvim_create_user_command("TermInterrupt", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  local ok, msg = term_enh.send_interrupt(arg)
  if ok then
    vim.notify("[TermEnhance] ⚡ " .. msg, vim.log.levels.INFO)
  end
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Send interrupt (Ctrl+C / SIGINT) to terminal",
})

vim.api.nvim_create_user_command("TermKillTree", function(opts)
  local args = vim.split(vim.trim(opts.args), "%s+")
  local term_id = args[1] ~= "" and args[1] or nil
  local sig = args[2]

  local ok, msg = term_enh.kill_tree(term_id, sig)
  if ok then
    vim.notify("[TermEnhance] 🛑 " .. msg, vim.log.levels.INFO)
  else
    vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
  end
end, {
  nargs = "*",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Kill child process tree without closing terminal: :TermKillTree [term_id] [signal]",
})

vim.api.nvim_create_user_command("TermInfo", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  local info = term_enh.get_terminal_info(arg)
  if not info then
    vim.notify("[TermEnhance] No terminal found to inspect.", vim.log.levels.WARN)
    return
  end

  local lines = {
    string.format("Terminal Diagnostics for '%s' (Buf #%d):", info.id, info.buf),
    string.format(" • Shell Type: %s", info.shell_type:upper()),
    string.format(" • Root Shell PID: %s", info.root_pid and tostring(info.root_pid) or "none"),
  }

  if info.fg_process and info.fg_process.pid ~= info.root_pid then
    table.insert(lines, string.format(" • Foreground Process: '%s' (PID %d)", info.fg_process.comm, info.fg_process.pid))
    table.insert(lines, string.format("   Command: %s", info.fg_process.cmdline))
  else
    table.insert(lines, " • Foreground Process: [Idle at shell prompt]")
  end

  if info.ports and #info.ports > 0 then
    local p_strs = {}
    for _, p in ipairs(info.ports) do
      table.insert(p_strs, string.format(":%d (%s, PID %s)", p.port, p.proto:upper(), tostring(p.pid or "unknown")))
    end
    table.insert(lines, string.format(" • Active Listening Ports: %s", table.concat(p_strs, ", ")))
  else
    table.insert(lines, " • Active Listening Ports: None")
  end

  if #info.tree > 1 then
    table.insert(lines, string.format(" • Process Tree (%d processes):", #info.tree))
    for idx, proc in ipairs(info.tree) do
      table.insert(lines, string.format("   [%d] PID %d: %s (%s)", idx, proc.pid, proc.comm, proc.cmdline:sub(1, 60)))
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {
  nargs = "?",
  complete = function()
    local matches = {}
    for _, item in ipairs(term_enh.get_active_terminals()) do
      table.insert(matches, item.id)
    end
    return matches
  end,
  desc = "Inspect terminal shell, process tree, and listening ports: :TermInfo [term_id]",
})

vim.api.nvim_create_user_command("TermStatusBarToggle", function()
  term_enh.toggle_status_bar()
end, {
  desc = "Toggle terminal lower status bar",
})

vim.api.nvim_create_user_command("TermStatus", function()
  term_enh.toggle_status_bar()
end, {
  desc = "Toggle terminal lower status bar",
})

vim.api.nvim_create_user_command("TermStickyToggle", function()
  term_enh.toggle_status_bar()
end, {
  desc = "Toggle terminal lower status bar (legacy alias)",
})

vim.api.nvim_create_user_command("TermSticky", function()
  term_enh.toggle_status_bar()
end, {
  desc = "Toggle terminal lower status bar (legacy alias)",
})


