local config = require("terminal_enhancement.config")
local terminal = require("terminal_enhancement.core.terminal")

local M = {}

---Launch a configured tool (e.g. lazygit, htop, agy, python, node)
---@param tool_name string
function M.open_tool(tool_name)
  local tool = config.options.tools[tool_name]
  if not tool then
    vim.notify(string.format("[TermEnhance] Unknown tool '%s'", tool_name), vim.log.levels.WARN)
    return
  end

  local direction = tool.direction or "float"
  local title = string.format(" %s ", tool.desc or tool_name)
  terminal.toggle("tool_" .. tool_name, tool.cmd, direction, title)
end

return M
