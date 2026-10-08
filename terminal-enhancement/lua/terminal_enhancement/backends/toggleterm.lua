local utils = require("terminal_enhancement.core.utils")

local M = {}

function M.is_available()
  local ok, _ = pcall(require, "toggleterm")
  return ok
end

function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("toggleterm.nvim is not installed.", vim.log.levels.ERROR)
    if on_done then on_done("toggleterm", nil, 0) end
    return false
  end

  local ok, tt = pcall(require, "toggleterm")
  if ok and tt.send_lines_to_terminal then
    local lines = utils.split_lines(text)
    tt.send_lines_to_terminal("single_line", true, { args = lines })
    if on_done then on_done("toggleterm", nil, 0) end
    return true
  end

  return false
end

return M
