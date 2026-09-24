if vim.g.loaded_smart_highlighter == 1 then
  return
end
vim.g.loaded_smart_highlighter = 1

local sh = require("smart_highlighter")

-- Commands
vim.api.nvim_create_user_command("SmartHighlightToggle", function()
  sh.toggle()
end, {
  desc = "Toggle highlight on word under cursor or visual selection",
})

vim.api.nvim_create_user_command("SmartHighlightRegex", function(opts)
  if opts.args == "" then
    sh.add_regex_interactive()
  else
    sh.add_pattern(opts.args, { is_regex = true, whole_word = false, name = opts.args })
    vim.notify(string.format("[SmartHighlight] Added regex pattern: '%s'", opts.args), vim.log.levels.INFO)
  end
end, {
  nargs = "?",
  desc = "Highlight custom regex pattern: :SmartHighlightRegex <pattern>",
})

vim.api.nvim_create_user_command("SmartHighlightClear", function(opts)
  if opts.args ~= "" then
    local id = tonumber(opts.args)
    if id then
      sh.remove_slot(id)
      vim.notify(string.format("[SmartHighlight] Cleared slot #%d", id), vim.log.levels.INFO)
    end
  else
    sh.clear_all()
    vim.notify("[SmartHighlight] Cleared all highlights", vim.log.levels.INFO)
  end
end, {
  nargs = "?",
  desc = "Clear all highlights or specific slot: :SmartHighlightClear [slot_id]",
})

vim.api.nvim_create_user_command("SmartHighlightHUD", function()
  sh.open_hud()
end, {
  desc = "Open interactive Floating HUD Manager",
})

vim.api.nvim_create_user_command("SmartHighlightPreset", function(opts)
  if opts.args == "" then
    sh.select_preset()
  else
    local ok, msg = sh.load_preset(opts.args)
    if ok then
      vim.notify("[SmartHighlight] " .. msg, vim.log.levels.INFO)
    else
      vim.notify("[SmartHighlight] " .. msg, vim.log.levels.WARN)
    end
  end
end, {
  nargs = "?",
  complete = function()
    return { "logs", "http", "sql", "json", "devops" }
  end,
  desc = "Load preset pattern: :SmartHighlightPreset <preset_name>",
})

vim.api.nvim_create_user_command("SmartHighlightScope", function()
  sh.toggle_scope()
end, {
  desc = "Toggle Treesitter scope-bounded highlight",
})

vim.api.nvim_create_user_command("SmartHighlightQuickfix", function()
  sh.export_quickfix()
end, {
  desc = "Export all highlighted matches to Quickfix list",
})

vim.api.nvim_create_user_command("SmartHighlightSearch", function()
  sh.search_matches()
end, {
  desc = "Fuzzy search through highlighted matches via Telescope / Quickfix",
})

vim.api.nvim_create_user_command("SmartHighlightSave", function()
  local ok, msg = sh.save_session()
  vim.notify("[SmartHighlight] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
end, {
  desc = "Save active highlights to session storage",
})

vim.api.nvim_create_user_command("SmartHighlightLoad", function()
  local ok, msg = sh.load_session()
  vim.notify("[SmartHighlight] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
end, {
  desc = "Restore highlights from session storage",
})

-- Default Keymaps
local config = require("smart_highlighter.config")
if config.options.default_keymaps then
  local map = vim.keymap.set
  local opts = { silent = true, desc = "" }

  map({ "n", "v" }, "<leader>hh", function() sh.toggle() end, { desc = "SmartHighlight: Toggle Word/Selection" })
  map("n", "<leader>hH", function() sh.add_regex_interactive() end, { desc = "SmartHighlight: Add Regex Pattern" })
  map("n", "<leader>hc", function() sh.clear_all() end, { desc = "SmartHighlight: Clear All" })
  map("n", "<leader>hm", function() sh.open_hud() end, { desc = "SmartHighlight: Open HUD Manager" })
  map("n", "<leader>hp", function() sh.select_preset() end, { desc = "SmartHighlight: Select Preset" })
  map("n", "<leader>hs", function() sh.toggle_scope() end, { desc = "SmartHighlight: Toggle Treesitter Scope" })
  map("n", "<leader>hq", function() sh.export_quickfix() end, { desc = "SmartHighlight: Export to Quickfix" })
  map("n", "<leader>hf", function() sh.search_matches() end, { desc = "SmartHighlight: Search Matches (Telescope)" })

  -- Jump navigation keymaps
  map("n", "]h", function() sh.jump_next() end, { desc = "SmartHighlight: Next Slot Match" })
  map("n", "[h", function() sh.jump_prev() end, { desc = "SmartHighlight: Prev Slot Match" })
  map("n", "]H", function() sh.jump_any_next() end, { desc = "SmartHighlight: Next Match (Any Slot)" })
  map("n", "[H", function() sh.jump_any_prev() end, { desc = "SmartHighlight: Prev Match (Any Slot)" })
end
