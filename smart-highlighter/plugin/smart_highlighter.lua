if vim.g.loaded_smart_highlighter == 1 then
  return
end
vim.g.loaded_smart_highlighter = 1

local sh = require("smart_highlighter")

-- Commands
vim.api.nvim_create_user_command("SmartHighlightToggle", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or nil
  if arg == "current" or arg == "buffer" then
    sh.toggle_current_buffer()
  elseif arg == "all" or arg == "global" then
    sh.toggle_all_buffers()
  else
    sh.toggle()
  end
end, {
  nargs = "?",
  complete = function()
    return { "all", "current", "global", "buffer" }
  end,
  desc = "Toggle highlight on word under cursor: :SmartHighlightToggle [all|current]",
})

vim.api.nvim_create_user_command("SmartHighlightBuffer", function(opts)
  local text = opts.args ~= "" and opts.args or nil
  sh.toggle_current_buffer(text)
end, {
  nargs = "?",
  desc = "Toggle highlight for CURRENT buffer only: :SmartHighlightBuffer [word]",
})

vim.api.nvim_create_user_command("SmartHighlightGlobal", function(opts)
  local text = opts.args ~= "" and opts.args or nil
  sh.toggle_all_buffers(text)
end, {
  nargs = "?",
  desc = "Toggle highlight across ALL open buffers: :SmartHighlightGlobal [word]",
})

vim.api.nvim_create_user_command("SmartHighlightBufferScope", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or nil
  sh.toggle_buffer_scope(arg)
end, {
  nargs = "?",
  complete = function()
    return { "all", "current", "toggle" }
  end,
  desc = "Switch or toggle default highlight scope: :SmartHighlightBufferScope [all|current|toggle]",
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

vim.api.nvim_create_user_command("SmartHighlightQuickfix", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "all"
  sh.export_quickfix(arg)
end, {
  nargs = "?",
  complete = function()
    return { "all", "current" }
  end,
  desc = "Export highlighted matches to Quickfix list: :SmartHighlightQuickfix [all|current]",
})

vim.api.nvim_create_user_command("SmartHighlightBottom", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "current"
  sh.open_bottom_pane(arg)
end, {
  nargs = "?",
  complete = function()
    return { "current", "all" }
  end,
  desc = "Open bottom buffer window for matches: :SmartHighlightBottom [current|all]",
})

vim.api.nvim_create_user_command("SmartHighlightSearch", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "all"
  sh.search_matches({ scope = arg })
end, {
  nargs = "?",
  complete = function()
    return { "all", "current" }
  end,
  desc = "Search highlighted matches (Telescope for all buffers, bottom pane for current): :SmartHighlightSearch [all|current]",
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

  map({ "n", "v" }, "<leader>hh", function() sh.toggle() end, { desc = "SmartHighlight: Toggle (Default Scope)" })
  map({ "n", "v" }, "<leader>hb", function() sh.toggle_current_buffer() end, { desc = "SmartHighlight: Toggle Current Buffer Only" })
  map("n", "<leader>hB", function() sh.toggle_buffer_scope() end, { desc = "SmartHighlight: Toggle Buffer Scope Mode (All/Current)" })
  map("n", "<leader>hH", function() sh.add_regex_interactive() end, { desc = "SmartHighlight: Add Regex Pattern" })
  map("n", "<leader>hc", function() sh.clear_all() end, { desc = "SmartHighlight: Clear All" })
  map("n", "<leader>hm", function() sh.open_hud() end, { desc = "SmartHighlight: Open HUD Manager" })
  map("n", "<leader>hp", function() sh.select_preset() end, { desc = "SmartHighlight: Select Preset" })
  map("n", "<leader>hs", function() sh.toggle_scope() end, { desc = "SmartHighlight: Toggle Treesitter Scope" })
  map("n", "<leader>hq", function() sh.export_quickfix("all") end, { desc = "SmartHighlight: Export to Quickfix (All Buffers)" })
  map("n", "<leader>hf", function() sh.search_matches({ scope = "all" }) end, { desc = "SmartHighlight: Search Matches (All Open Buffers)" })
  map("n", "<leader>hF", function() sh.search_matches({ scope = "current" }) end, { desc = "SmartHighlight: Search Matches (Current Buffer Only)" })

  -- Jump navigation keymaps
  map("n", "]h", function() sh.jump_next() end, { desc = "SmartHighlight: Next Slot Match" })
  map("n", "[h", function() sh.jump_prev() end, { desc = "SmartHighlight: Prev Slot Match" })
  map("n", "]H", function() sh.jump_any_next() end, { desc = "SmartHighlight: Next Match (Any Slot)" })
  map("n", "[H", function() sh.jump_any_prev() end, { desc = "SmartHighlight: Prev Match (Any Slot)" })
end
