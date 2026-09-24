local M = {}

---@class SmartHighlightPresetConfig
---@field enabled boolean
---@field auto_by_filetype boolean
---@field filetype_map table<string, string>

---@class SmartHighlightOptions
---@field max_slots integer
---@field whole_word boolean
---@field case_sensitive boolean
---@field treesitter_scope boolean
---@field persistence boolean
---@field default_keymaps boolean
---@field debounce_ms integer
---@field palette string "modern"|"neon"|"pastel"|"solarized"
---@field presets SmartHighlightPresetConfig

---@type SmartHighlightOptions
M.defaults = {
  max_slots = 16,
  whole_word = true,
  case_sensitive = false,
  treesitter_scope = false,
  persistence = true,
  default_keymaps = true,
  debounce_ms = 80,
  palette = "modern",
  presets = {
    enabled = true,
    auto_by_filetype = true,
    filetype_map = {
      log = "logs",
      text = "logs",
      http = "http",
      rest = "http",
      sql = "sql",
      mysql = "sql",
      psql = "sql",
      json = "json",
    },
  },
}

---@type SmartHighlightOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options with defaults
---@param user_opts? table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
