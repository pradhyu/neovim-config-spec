local utils = require("terminal_enhancement.core.utils")

local M = {}

function M.is_available()
  return _G.Snacks ~= nil and _G.Snacks.terminal ~= nil
end

function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("Snacks.terminal is not available.", vim.log.levels.ERROR)
    if on_done then on_done("snacks", nil, 0) end
    return false
  end

  local term = _G.Snacks.terminal.get(nil, { create = true })
  if term and term.job_id then
    vim.fn.chansend(term.job_id, text)
    local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
    if #text > 40 then preview = preview .. "..." end
    vim.notify(string.format("[TermEnhance -> Snacks] Dispatched: %s", preview), vim.log.levels.INFO)
    if on_done then on_done("snacks", term.buf, (term.buf and vim.api.nvim_buf_is_valid(term.buf)) and vim.api.nvim_buf_line_count(term.buf) or 0) end
    return true
  end

  utils.notify("Failed to get Snacks terminal job ID.", vim.log.levels.ERROR)
  if on_done then on_done("snacks", nil, 0) end
  return false
end

return M
