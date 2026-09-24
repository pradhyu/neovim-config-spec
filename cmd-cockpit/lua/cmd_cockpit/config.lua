local M = {}

---@class CmdCockpitOptions
---@field default_keymaps boolean
---@field track_history boolean
---@field max_history_entries integer
---@field ignore_patterns string[]
---@field storage_dir string
---@field overrides_file string
---@field auto_apply_overrides boolean

---@type CmdCockpitOptions
M.defaults = {
  default_keymaps = true,
  track_history = true,
  max_history_entries = 200,
  ignore_patterns = {
    "^w$", "^q$", "^wq$", "^x$", "^qa$", "^wqa$",
    "^noh$", "^nohlsearch$", "^lua$", "^lua %s*$",
  },
  storage_dir = vim.fn.stdpath("state") .. "/cmd-cockpit",
  overrides_file = vim.fn.stdpath("config") .. "/lua/config/keymap_overrides.lua",
  auto_apply_overrides = true,
}

---@type CmdCockpitOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options with defaults
---@param user_opts? table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
