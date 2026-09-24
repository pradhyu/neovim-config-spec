local stats = require("cmd_cockpit.core.stats")

local M = {}

---Get statusline summary (total commands executed and top command)
---@return string
function M.get()
  local top = stats.get_top_commands(1)
  if #top > 0 then
    return string.format("⚡ %s (%d)", top[1].cmd, top[1].count)
  end
  return ""
end

return M
