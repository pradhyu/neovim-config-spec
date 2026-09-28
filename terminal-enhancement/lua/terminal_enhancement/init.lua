local config = require("terminal_enhancement.config")
local terminal = require("terminal_enhancement.core.terminal")
local keymaps = require("terminal_enhancement.core.keymaps")
local runner = require("terminal_enhancement.core.runner")
local tools = require("terminal_enhancement.tools.instances")
local link_resolver = require("terminal_enhancement.core.link_resolver")

local M = {}

---Initialize the terminal-enhancement plugin
---@param user_opts? table
function M.setup(user_opts)
  config.setup(user_opts)
  keymaps.setup()

  local function setup_term_buffer(buf)
    if vim.api.nvim_buf_is_valid(buf) and (vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype:match("terminal")) then
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 and vim.api.nvim_win_is_valid(win) then
        require("terminal_enhancement.ui.window").apply_terminal_styling(buf, win)
      end
      keymaps.attach_to_buffer(buf, win ~= -1 and win or nil)
    end
  end

  -- Attach to all existing terminal buffers across Neovim
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    setup_term_buffer(buf)
  end

  -- Autocmd to format terminal buffers upon creation and entry
  vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "FileType" }, {
    group = vim.api.nvim_create_augroup("TerminalEnhancementAuto", { clear = true }),
    pattern = { "*", "terminal", "sidekick_terminal" },
    callback = function(args)
      local buf = args.buf
      setup_term_buffer(buf)
      if args.event == "TermOpen" and config.options.auto_insert then
        vim.cmd("startinsert")
      end
    end,
  })
end

---Toggle default or named terminal
---@param direction? "float"|"horizontal"|"vertical"
---@param id? string
function M.toggle(direction, id)
  terminal.toggle(id or terminal.default_target or "default", nil, direction)
end

---Explicitly hide terminal window (current or specified) without closing process
---@param id_or_buf? string|integer
function M.hide(id_or_buf)
  terminal.hide(id_or_buf)
end

---Hide all open terminal windows without closing running processes
function M.hide_all()
  terminal.hide_all()
end

---Explicitly show/open terminal window
---@param id? string
---@param direction? "float"|"horizontal"|"vertical"
---@param focus? boolean
function M.show(id, direction, focus)
  terminal.show(id, direction, focus)
end

---Unhide/show all currently hidden terminals
---@param direction? "float"|"horizontal"|"vertical"
function M.show_all(direction)
  terminal.show_all(direction)
end

---Open interactive multi-select picker to check and unhide hidden terminals
function M.unhide_picker()
  terminal.unhide_interactive()
end

---Alias for unhide_picker
function M.show_picker()
  terminal.unhide_interactive()
end

---Open terminal directly in active window like a normal buffer
---@param id? string
function M.open_as_buffer(id)
  terminal.open_as_buffer(id)
end

---Open specific tool terminal
---@param tool_name string
function M.open_tool(tool_name)
  tools.open_tool(tool_name)
end

---Run custom command in terminal
---@param cmd string
---@param direction? string
function M.run(cmd, direction)
  runner.run_command(cmd, direction)
end

---Send visual selection or current line to terminal
---@param line1? integer
---@param line2? integer
---@param mode? "raw"|"join_continuation"|"join_and"
function M.send_selection(line1, line2, mode)
  runner.send_selection(line1, line2, mode)
end

---Send visual selection joined into a single command with \ (Bash) or ` (PowerShell)
---@param line1? integer
---@param line2? integer
---@param mode? "join_continuation"|"join_and"
function M.send_joined(line1, line2, mode)
  runner.send_joined(line1, line2, mode)
end

---Send current line or inline code to terminal
function M.send_line()
  runner.send_line()
end

---Send enclosing code block (Markdown code fence, Treesitter block, or paragraph)
function M.send_block()
  runner.send_block()
end

---Send current line/command and auto-advance to next executable line
function M.send_step()
  runner.send_step()
end

---Send entire buffer/file to terminal
function M.send_file()
  runner.send_file()
end

---Send visual selection to terminal
function M.send_visual()
  runner.send_visual()
end

---Show floating modal with the last command execution outcome
function M.show_last_output()
  history.show_last_output()
end

---Interactive execution history picker
function M.show_history()
  history.show_history_ui()
end

---Copy last command outcome/output to clipboard
function M.copy_last_output()
  history.copy_last_output()
end

---Copy last executed command text to clipboard
function M.copy_last_command()
  history.copy_last_command()
end

---Paste last output as commented lines below current line
function M.paste_last_output()
  history.paste_last_output_to_current_buffer()
end

---Toggle auto-copying outcome to clipboard
function M.toggle_copy_output()
  config.options.history = config.options.history or {}
  config.options.history.copy_output_to_clipboard = not config.options.history.copy_output_to_clipboard
  local state_str = config.options.history.copy_output_to_clipboard and "ENABLED" or "DISABLED"
  vim.notify(string.format("[TermEnhance] Auto-copy outcome to clipboard: %s", state_str), vim.log.levels.INFO)
end

---Toggle auto-pasting outcome into buffer
function M.toggle_paste_output()
  config.options.history = config.options.history or {}
  config.options.history.paste_output_to_buffer = not config.options.history.paste_output_to_buffer
  local state_str = config.options.history.paste_output_to_buffer and "ENABLED" or "DISABLED"
  vim.notify(string.format("[TermEnhance] Auto-paste outcome into buffer: %s", state_str), vim.log.levels.INFO)
end

---Select or switch the default target terminal
function M.select_target()
  runner.select_target()
end

---Get all active terminal instances
function M.get_active_terminals()
  return terminal.get_active_terminals()
end

---Kill terminal by ID or buffer number
---@param id_or_buf? string|integer
function M.kill(id_or_buf)
  return terminal.kill(id_or_buf)
end

---Kill all hidden/background terminals to free PTYs and memory
function M.kill_hidden()
  return terminal.kill_hidden()
end

---Kill all active terminals
function M.kill_all()
  return terminal.kill_all()
end

---Interactive prompt to terminate or clean terminals
function M.kill_interactive()
  terminal.kill_interactive()
end

---Rename a terminal
---@param old_id string
---@param new_name string
function M.rename(old_id, new_name)
  return terminal.rename(old_id, new_name)
end

---Interactive prompt to rename a terminal
---@param id? string
function M.rename_interactive(id)
  terminal.rename_interactive(id)
end

---Send a POSIX signal to a terminal's process tree
---@param id_or_buf? string|integer
---@param signal? string|integer
function M.send_signal(id_or_buf, signal)
  return terminal.send_signal(id_or_buf, signal)
end

---Send interrupt (SIGINT / Ctrl+C) to a terminal
---@param id_or_buf? string|integer
function M.send_interrupt(id_or_buf)
  return terminal.send_interrupt(id_or_buf)
end

---Kill child process tree without closing terminal buffer
---@param id_or_buf? string|integer
---@param signal? string|integer
function M.kill_tree(id_or_buf, signal)
  return terminal.kill_tree(id_or_buf, signal)
end

---Kill process listening on a port
---@param port integer
---@param signal? string|integer
---@param id_or_buf? string|integer
function M.kill_port(port, signal, id_or_buf)
  return terminal.kill_port(port, signal, id_or_buf)
end

---Interactive prompt to kill a port
---@param id_or_buf? string|integer
function M.kill_port_interactive(id_or_buf)
  terminal.kill_port_interactive(id_or_buf)
end

---Interactive prompt to send signal to terminal process
---@param id_or_buf? string|integer
function M.send_signal_interactive(id_or_buf)
  terminal.send_signal_interactive(id_or_buf)
end

---Get diagnostic info for a terminal (shell type, PID, processes, ports)
---@param id_or_buf? string|integer
function M.get_terminal_info(id_or_buf)
  return terminal.get_terminal_info(id_or_buf)
end

---Switch focus to terminal (open if needed)
---@param id_or_buf string|integer
---@param direction? "float"|"horizontal"|"vertical"
function M.focus(id_or_buf, direction)
  terminal.focus(id_or_buf, direction)
end

---Open interactive Quick-Filter terminal switcher modal
---@param opts? table
function M.filter_interactive(opts)
  terminal.filter_interactive(opts)
end

---Alias for filter_interactive
function M.open_picker(opts)
  terminal.filter_interactive(opts)
end

---Resolve and open link/file at cursor
---@param target? string
function M.open_link(target)
  return link_resolver.open(target)
end

---Open interactive command prompt with Fish-like live ghost text autocomplete
---@param opts? table
function M.prompt(opts)
  require("terminal_enhancement.ui.prompt").open(opts)
end

---Toggle terminal lower status bar
function M.toggle_status_bar()
  require("terminal_enhancement.ui.status_bar").toggle()
end

---Toggle status bar (legacy alias)
function M.toggle_sticky_scroll()
  M.toggle_status_bar()
end

return M
