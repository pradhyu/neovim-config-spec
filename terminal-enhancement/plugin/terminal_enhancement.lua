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

vim.api.nvim_create_user_command("TermRun", function(opts)
  if opts.args == "" then
    vim.notify("[TermEnhance] Usage: :TermRun <command>", vim.log.levels.WARN)
    return
  end
  term_enh.run(opts.args)
end, {
  nargs = "+",
  desc = "Run arbitrary shell command in floating terminal",
})

vim.api.nvim_create_user_command("TermSend", function(opts)
  term_enh.send_selection(opts.line1, opts.line2, "raw")
end, {
  range = true,
  desc = "Send line or visual selection to target terminal with bracketed paste",
})

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
  term_enh.select_target()
end, {
  desc = "Interactive prompt to select or switch default target terminal",
})

vim.api.nvim_create_user_command("TermTarget", function(opts)
  local arg = opts.args
  if arg and arg ~= "" then
    require("terminal_enhancement.core.terminal").set_default_target(arg)
  else
    term_enh.select_target()
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
  local list = term_enh.get_active_terminals()
  if #list == 0 then
    vim.notify("[TermEnhance] No active terminals currently running.", vim.log.levels.INFO)
    return
  end
  local lines = { "Active Terminals (Available in :buffers / :b term://<name>):" }
  for _, item in ipairs(list) do
    local def = item.is_default and " [ACTIVE TARGET]" or ""
    local state = item.is_open and "Visible" or "Hidden"
    table.insert(lines, string.format(" • %s (%s)%s  [Buf #%d]", item.title, state, def, item.buf))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {
  desc = "List all active terminal instances",
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


