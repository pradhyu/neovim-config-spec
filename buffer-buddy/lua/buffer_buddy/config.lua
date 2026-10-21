local M = {}

---@class BufferBuddyBreadcrumbOptions
---@field enabled boolean
---@field separator string
---@field show_icon boolean
---@field show_workspace boolean
---@field show_pin boolean
---@field show_modified boolean
---@field show_readonly boolean
---@field folder_icon string
---@field max_depth integer
---@field excluded_filetypes string[]
---@field excluded_buftypes string[]

---@class BufferBuddyOptions
---@field default_keymaps boolean
---@field auto_clean_on_exit boolean
---@field protect_pinned boolean
---@field trim_whitespace_on_save boolean
---@field scratchpad_dir string
---@field scratchpad_style "float"|"split"|"vsplit"
---@field max_snapshots_per_buffer integer
---@field tab_scoping boolean
---@field tab_auto_name boolean
---@field tab_clean_on_close boolean
---@field breadcrumbs BufferBuddyBreadcrumbOptions

---@type BufferBuddyOptions
M.defaults = {
  default_keymaps = true,
  auto_clean_on_exit = false,
  protect_pinned = true,
  trim_whitespace_on_save = false,
  scratchpad_dir = vim.fn.stdpath("data") .. "/buffer-buddy/scratchpads",
  scratchpad_style = "float",
  max_snapshots_per_buffer = 10,
  tab_scoping = true,
  tab_auto_name = true,
  tab_clean_on_close = true,
  breadcrumbs = {
    enabled = true,
    separator = "  ",
    show_icon = true,
    show_workspace = true,
    show_pin = true,
    show_modified = true,
    show_readonly = true,
    folder_icon = " ",
    max_depth = 5,
    excluded_filetypes = {
      "neo-tree",
      "snacks_picker",
      "snacks_layout_box",
      "snacks_dashboard",
      "bufferbuddy_hud",
      "bufferbuddy_scratch_picker",
      "help",
      "qf",
      "trouble",
      "lazy",
      "mason",
      "notify",
      "noice",
    },
    excluded_buftypes = {
      "nofile",
      "quickfix",
      "prompt",
    },
  },
}

---@type BufferBuddyOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options with defaults
---@param user_opts? table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
