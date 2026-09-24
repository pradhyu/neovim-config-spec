local engine = require("smart_highlighter.core.engine")

local M = {}

---Get formatted statusline string for active highlights
---@param buf? integer
---@return string
function M.get(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local active_slots = 0
  local total_matches = 0

  for id, slot in pairs(engine.slots) do
    if slot.enabled then
      active_slots = active_slots + 1
      total_matches = total_matches + engine.count_matches(id, target_buf)
    end
  end

  if active_slots == 0 then
    return ""
  end

  return string.format("🎨 %d [%d]", active_slots, total_matches)
end

return M
