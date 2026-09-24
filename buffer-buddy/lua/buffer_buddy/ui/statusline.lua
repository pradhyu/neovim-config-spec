local pin = require("buffer_buddy.core.pin")
local inspector = require("buffer_buddy.core.inspector")

local M = {}

---Get statusline badge for current buffer (pinned indicator + token estimation)
---@param buf? integer
---@return string
function M.get(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return ""
  end

  local parts = {}
  if pin.is_pinned(target_buf) then
    table.insert(parts, "📌")
  end

  local info = inspector.get_info(target_buf)
  if info.valid and info.tokens > 0 then
    table.insert(parts, string.format("~%dtk", info.tokens))
  end

  return table.concat(parts, " ")
end

return M
