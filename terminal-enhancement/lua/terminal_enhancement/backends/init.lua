local config = require("terminal_enhancement.config")
local utils = require("terminal_enhancement.core.utils")

local M = {}

local backends = {
  neovim = require("terminal_enhancement.backends.neovim"),
  tmux = require("terminal_enhancement.backends.tmux"),
  zellij = require("terminal_enhancement.backends.zellij"),
  kitty = require("terminal_enhancement.backends.kitty"),
  wezterm = require("terminal_enhancement.backends.wezterm"),
  snacks = require("terminal_enhancement.backends.snacks"),
  toggleterm = require("terminal_enhancement.backends.toggleterm"),
}

---Register a custom backend adapter
---@param name string
---@param backend_module table
function M.register(name, backend_module)
  backends[name] = backend_module
end

---Auto-detect external multiplexer environment
---@return string
function M.auto_detect()
  if vim.env.TMUX and backends.tmux.is_available() then
    return "tmux"
  elseif vim.env.ZELLIJ and backends.zellij.is_available() then
    return "zellij"
  elseif vim.env.KITTY_WINDOW_ID and backends.kitty.is_available() then
    return "kitty"
  elseif vim.env.WEZTERM_PANE and backends.wezterm.is_available() then
    return "wezterm"
  end

  -- Default to native Neovim terminal suite
  return "neovim"
end

---Get active backend adapter
---@param backend_name? string
---@return table|nil
function M.get_backend(backend_name)
  local opts = config.options
  local name = backend_name or opts.backend or "auto"

  if type(name) == "function" then
    return {
      send = name,
      is_available = function() return true end,
    }
  end

  if name == "auto" then
    name = M.auto_detect()
  end

  local backend = backends[name]
  if not backend then
    utils.notify(string.format("Unknown backend '%s', falling back to 'neovim'", tostring(name)), vim.log.levels.WARN)
    return backends.neovim
  end

  return backend
end

---Send text through the resolved backend
---@param text string
---@param opts? table
---@param lang? string
---@param on_done? fun(target_id: string, term_buf: integer|nil, start_lines: integer|nil)
---@param entry_id? integer
---@return boolean success
function M.send(text, opts, lang, on_done, entry_id)
  opts = opts or config.options
  local backend = M.get_backend(opts.backend)
  if not backend then
    utils.notify("No valid terminal backend found.", vim.log.levels.ERROR)
    if on_done then on_done("unknown", nil, 0) end
    return false
  end

  return backend.send(text, opts, lang, on_done, entry_id)
end

return M
