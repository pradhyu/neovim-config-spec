local utils = require("terminal_enhancement.core.utils")

local M = {}

function M.is_available()
  return vim.env.WEZTERM_PANE ~= nil and vim.fn.executable("wezterm") == 1
end

function M.send(text, opts, lang, on_done)
  if not M.is_available() then
    utils.notify("wezterm pane not detected or wezterm command not found.", vim.log.levels.ERROR)
    if on_done then on_done("wezterm", nil, 0) end
    return false
  end

  local pane_id = (opts and opts.wezterm and opts.wezterm.pane_id) or nil
  local cmd = { "wezterm", "cli", "send-text", "--no-paste" }
  if pane_id then
    table.insert(cmd, "--pane-id")
    table.insert(cmd, tostring(pane_id))
  end
  table.insert(cmd, text)

  vim.fn.system(cmd)

  local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
  if #text > 40 then preview = preview .. "..." end
  vim.notify(string.format("[TermEnhance -> wezterm] Dispatched: %s", preview), vim.log.levels.INFO)

  if on_done then on_done("wezterm", nil, 0) end
  return true
end

return M
