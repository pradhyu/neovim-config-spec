if vim.g.loaded_cmd_cockpit == 1 then
  return
end
vim.g.loaded_cmd_cockpit = 1

local cp = require("cmd_cockpit")

-- User Commands
vim.api.nvim_create_user_command("CmdCockpit", function()
  cp.open_cockpit()
end, {
  desc = "Open interactive Command Cockpit & Keymap Hub",
})

vim.api.nvim_create_user_command("CmdFrequent", function()
  cp.picker_frequent()
end, {
  desc = "Open Frequent Commands launcher",
})

vim.api.nvim_create_user_command("CmdKeymaps", function(opts)
  local mode = opts.args ~= "" and opts.args or nil
  cp.open_keymaps()
end, {
  nargs = "?",
  complete = function()
    return { "n", "v", "i", "t", "c", "x", "o", "all" }
  end,
  desc = "Inspect & browse active keymaps: :CmdKeymaps [mode]",
})

vim.api.nvim_create_user_command("CmdRemap", function(opts)
  local args = vim.split(vim.trim(opts.args), "%s+")
  if #args >= 3 then
    local mode = args[1]
    local old_lhs = args[2]
    local new_lhs = args[3]
    local ok, msg = cp.set_override(mode, old_lhs, new_lhs)
    vim.notify("[CmdCockpit] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
  else
    cp.open_remap()
  end
end, {
  nargs = "*",
  desc = "Remap a keybinding: :CmdRemap <mode> <old_lhs> <new_lhs>",
})

vim.api.nvim_create_user_command("CmdResetOverrides", function()
  cp.reset_overrides()
  vim.notify("[CmdCockpit] 🔄 Reset all custom keymap overrides to defaults", vim.log.levels.INFO)
end, {
  desc = "Reset all custom keymap overrides",
})

vim.api.nvim_create_user_command("CmdExportOverrides", function(opts)
  local path = opts.args ~= "" and opts.args or nil
  local ok, msg = cp.export_overrides(path)
  vim.notify("[CmdCockpit] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
end, {
  nargs = "?",
  desc = "Export active overrides to Lua file: :CmdExportOverrides [path]",
})

vim.api.nvim_create_user_command("CmdStats", function()
  cp.view_stats()
end, {
  desc = "Display command execution frequency analytics",
})

-- Default Keymaps (<leader>k... / <leader>C)
local config = require("cmd_cockpit.config")
if config.options.default_keymaps then
  local map = vim.keymap.set

  map("n", "<leader>kk", function() cp.open_cockpit() end, { desc = "CmdCockpit: Open Hub" })
  map("n", "<leader>kc", function() cp.open_cockpit() end, { desc = "CmdCockpit: Open Hub" })
  map("n", "<leader>kf", function() cp.picker_frequent() end, { desc = "CmdCockpit: Frequent Commands" })
  map("n", "<leader>km", function() cp.open_keymaps() end, { desc = "CmdCockpit: Keymap Browser" })
  map("n", "<leader>kr", function() cp.open_remap() end, { desc = "CmdCockpit: Remap Keybinding" })
  map("n", "<leader>ks", function() cp.view_stats() end, { desc = "CmdCockpit: Command Analytics" })
  map("n", "<leader>ke", function()
    local ok, msg = cp.export_overrides()
    vim.notify("[CmdCockpit] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
  end, { desc = "CmdCockpit: Export Overrides Lua" })

  -- Direct shortcut on <leader>C
  map("n", "<leader>C", function() cp.open_cockpit() end, { desc = "CmdCockpit: Open Hub" })
end
