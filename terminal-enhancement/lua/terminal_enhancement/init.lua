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

  -- Autocmd to format terminal buffers upon creation
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("TerminalEnhancementAuto", { clear = true }),
    callback = function(args)
      local buf = args.buf
      local win = vim.api.nvim_get_current_win()
      require("terminal_enhancement.ui.window").apply_terminal_styling(buf, win)
      keymaps.attach_to_buffer(buf, win)
      if config.options.auto_insert then
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
function M.send_selection(line1, line2)
  runner.send_selection(line1, line2)
end

---Send current line to terminal
function M.send_line()
  runner.send_current_line()
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

---Resolve and open link/file at cursor
---@param target? string
function M.open_link(target)
  return link_resolver.open(target)
end

return M
