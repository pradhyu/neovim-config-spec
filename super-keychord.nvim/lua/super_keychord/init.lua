local config = require("super_keychord.config")
local keychords = require("super_keychord.core.keychords")
local picker = require("super_keychord.ui.picker")

local M = {}

---Setup super-keychord plugin
---@param opts? table
function M.setup(opts)
  config.setup(opts)
end

---Open interactive keychord search picker
---@param opts? table
function M.open(opts)
  picker.open(opts)
end

---Search keychords for normal mode specifically
function M.open_normal()
  picker.open({ mode = "n" })
end

---Search keychords for visual mode specifically
function M.open_visual()
  picker.open({ mode = "v" })
end

---Search keychords for insert mode specifically
function M.open_insert()
  picker.open({ mode = "i" })
end

---Search keychords for terminal mode specifically
function M.open_terminal()
  picker.open({ mode = "t" })
end

---Search keychords for current buffer only
function M.open_buffer()
  picker.open({ buf = vim.api.nvim_get_current_buf() })
end

---Get all keychord entries programmatically
---@param mode? string
---@param buf? integer
---@return KeychordEntry[]
M.get_keychords = keychords.get_keychords

---Execute a keychord entry
---@param entry KeychordEntry
M.execute = keychords.execute_keychord

return M
