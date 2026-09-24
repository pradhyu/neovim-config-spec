local M = {}

---@class BufferBuddyOptions
---@field default_keymaps boolean
---@field auto_clean_on_exit boolean
---@field protect_pinned boolean
---@field trim_whitespace_on_save boolean
---@field scratchpad_dir string
---@field scratchpad_style "float"|"split"|"vsplit"
---@field max_snapshots_per_buffer integer

---@type BufferBuddyOptions
M.defaults = {
  default_keymaps = true,
  auto_clean_on_exit = false,
  protect_pinned = true,
  trim_whitespace_on_save = false,
  scratchpad_dir = vim.fn.stdpath("data") .. "/buffer-buddy/scratchpads",
  scratchpad_style = "float",
  max_snapshots_per_buffer = 10,
}

---@type BufferBuddyOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options with defaults
---@param user_opts? table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
