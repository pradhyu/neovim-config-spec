if vim.g.loaded_super_keychord == 1 then
  return
end
vim.g.loaded_super_keychord = 1

local sk = require("super_keychord")
local config = require("super_keychord.config")

-- =============================================================================
-- User Commands
-- =============================================================================

vim.api.nvim_create_user_command("SuperKeychord", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or nil
  if arg == "n" or arg == "normal" then
    sk.open_normal()
  elseif arg == "v" or arg == "visual" then
    sk.open_visual()
  elseif arg == "i" or arg == "insert" then
    sk.open_insert()
  elseif arg == "t" or arg == "terminal" then
    sk.open_terminal()
  elseif arg == "buf" or arg == "buffer" then
    sk.open_buffer()
  else
    sk.open({ mode = arg or "all" })
  end
end, {
  nargs = "?",
  complete = function()
    return { "all", "normal", "visual", "insert", "terminal", "buffer" }
  end,
  desc = "Search keychords by description or partial chord: :SuperKeychord [mode|buffer]",
})

vim.api.nvim_create_user_command("SuperKeychordNormal", function()
  sk.open_normal()
end, {
  desc = "Search normal mode keychords: :SuperKeychordNormal",
})

vim.api.nvim_create_user_command("SuperKeychordBuffer", function()
  sk.open_buffer()
end, {
  desc = "Search buffer-local keychords: :SuperKeychordBuffer",
})

-- =============================================================================
-- Default Keymaps
-- =============================================================================

if config.options.default_keymaps then
  -- <leader>k chord namespace for super-keychord
  vim.keymap.set("n", "<leader>k?", function() sk.open() end, { desc = "SuperKeychord: Search All Keychords" })
  vim.keymap.set("n", "<leader>kn", function() sk.open_normal() end, { desc = "SuperKeychord: Normal Mode Keychords" })
  vim.keymap.set("n", "<leader>kv", function() sk.open_visual() end, { desc = "SuperKeychord: Visual Mode Keychords" })
  vim.keymap.set("n", "<leader>kb", function() sk.open_buffer() end, { desc = "SuperKeychord: Buffer Local Keychords" })
  -- Convenience quick chord
  vim.keymap.set("n", "<leader>sk", function() sk.open() end, { desc = "SuperKeychord: Search Keychords" })
end
