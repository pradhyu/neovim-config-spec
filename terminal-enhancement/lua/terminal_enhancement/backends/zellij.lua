local utils = require("terminal_enhancement.core.utils")

local M = {}

function M.is_available()
  return vim.env.ZELLIJ ~= nil and vim.fn.executable("zellij") == 1
end

function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("zellij session not detected or zellij command not found.", vim.log.levels.ERROR)
    if on_done then on_done("zellij", nil, 0) end
    return false
  end

  vim.fn.system({ "zellij", "action", "write-chars", text })

  local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
  if #text > 40 then preview = preview .. "..." end
  vim.notify(string.format("[TermEnhance -> zellij] Dispatched: %s", preview), vim.log.levels.INFO)

  if on_done then on_done("zellij", nil, 0) end
  return true
end

return M
