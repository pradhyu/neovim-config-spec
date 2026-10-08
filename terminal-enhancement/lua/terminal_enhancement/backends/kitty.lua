local utils = require("terminal_enhancement.core.utils")

local M = {}

function M.is_available()
  return vim.env.KITTY_WINDOW_ID ~= nil and vim.fn.executable("kitty") == 1
end

function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("kitty window not detected or kitty command not found.", vim.log.levels.ERROR)
    if on_done then on_done("kitty", nil, 0) end
    return false
  end

  local match_target = (opts and opts.kitty and opts.kitty.target) or "recent:1"
  vim.fn.system({ "kitty", "@", "send-text", "--match", match_target, text })

  local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
  if #text > 40 then preview = preview .. "..." end
  vim.notify(string.format("[TermEnhance -> kitty %s] Dispatched: %s", match_target, preview), vim.log.levels.INFO)

  if on_done then on_done("kitty:" .. match_target, nil, 0) end
  return true
end

return M
