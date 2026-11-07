local M = {}

M.defaults = {
  default_mode = "all", -- "n" | "v" | "i" | "t" | "x" | "o" | "c" | "all"
  include_buffer_local = true,
  include_plug_maps = false, -- Filter out noisy internal <Plug>(...) mappings by default
  leader_representation = "<leader>", -- normalize leading space / <Space> to <leader>
  preview = true,
  execute_on_select = true, -- Pressing <CR> executes the keychord
  backend = "auto", -- "auto" (Snacks -> Telescope -> UI) | "snacks" | "telescope" | "ui"
  default_keymaps = true,
}

M.options = vim.deepcopy(M.defaults)

---Setup super-keychord configuration
---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
