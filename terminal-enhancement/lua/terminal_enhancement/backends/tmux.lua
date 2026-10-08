local utils = require("terminal_enhancement.core.utils")

local M = {}

---Check if tmux is running and available
---@return boolean
function M.is_available()
  return vim.env.TMUX ~= nil and vim.fn.executable("tmux") == 1
end

---Send text to tmux pane
---@param text string
---@param opts? table
---@param lang? string
---@param on_done? fun(target_id: string, term_buf: integer|nil, start_lines: integer|nil)
---@return boolean success
function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("tmux session not detected or tmux command not found.", vim.log.levels.ERROR)
    if on_done then on_done("tmux", nil, 0) end
    return false
  end

  local target = (opts and opts.tmux and opts.tmux.target) or "{last}"

  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if f then
    f:write(text)
    f:close()
    vim.fn.system(string.format("tmux load-buffer %s && tmux paste-buffer -p -t %s", vim.fn.shellescape(tmpfile), vim.fn.shellescape(target)))
    os.remove(tmpfile)
  else
    vim.fn.system(string.format("tmux send-keys -t %s %s", vim.fn.shellescape(target), vim.fn.shellescape(text)))
  end

  local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
  if #text > 40 then preview = preview .. "..." end
  vim.notify(string.format("[TermEnhance -> tmux %s] Dispatched: %s", target, preview), vim.log.levels.INFO)

  if on_done then on_done("tmux:" .. target, nil, 0) end
  return true
end

return M
