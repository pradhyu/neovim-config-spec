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

vim.api.nvim_create_user_command("SmartHighlightSave", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.save_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Save active highlights and bookmarks to repo file or state cache: :SmartHighlightSave [filepath]",
})

vim.api.nvim_create_user_command("SmartHighlightLoad", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.load_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Restore highlights and bookmarks from repo file or state cache: :SmartHighlightLoad [filepath]",
})

vim.api.nvim_create_user_command("SmartHighlightExport", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.save_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Export highlights and bookmarks to JSON file: :SmartHighlightExport [filepath]",
})

vim.api.nvim_create_user_command("SmartHighlightImport", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.load_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Import highlights and bookmarks from JSON file: :SmartHighlightImport [filepath]",
})

vim.api.nvim_create_user_command("SmartBookmarkExport", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.save_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Export bookmarks to repo-local .smart-highlighter.json or custom path: :SmartBookmarkExport [filepath]",
})

vim.api.nvim_create_user_command("SmartBookmarkImport", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  sh.load_session(file)
end, {
  nargs = "?",
  complete = "file",
  desc = "Import bookmarks from repo-local .smart-highlighter.json or custom path: :SmartBookmarkImport [filepath]",
})

vim.api.nvim_create_user_command("SmartHighlightAutoPersist", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "toggle"
  sh.toggle_auto_persist(arg)
end, {
  nargs = "?",
  complete = function()
    return { "on", "off", "toggle" }
  end,
  desc = "Toggle or configure auto-persist mode: :SmartHighlightAutoPersist [on|off|toggle]",
})

-- Bookmark User Commands
vim.api.nvim_create_user_command("SmartBookmarkToggle", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  sh.toggle_bookmark(arg)
end, {
  nargs = "?",
  desc = "Toggle bookmark on line (prompt note; empty uses highlighted text): :SmartBookmarkToggle [note]",
})

vim.api.nvim_create_user_command("SmartBookmarkToggleGlobal", function()
  sh.toggle_global_bookmarks()
end, {
  desc = "Toggle global bookmarks visibility (Show/Hide): :SmartBookmarkToggleGlobal",
})

vim.api.nvim_create_user_command("SmartBookmarkQuick", function()
  sh.quick_add_bookmark()
end, {
  desc = "Quick bookmark line or selection without prompting",
})

vim.api.nvim_create_user_command("SmartBookmarkNext", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  sh.jump_bookmark_next(arg)
end, {
  nargs = "?",
  complete = function()
    return { "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }
  end,
  desc = "Jump to next bookmark (optionally filter by tag): :SmartBookmarkNext [tag]",
})

vim.api.nvim_create_user_command("SmartBookmarkPrev", function(opts)
  local arg = opts.args ~= "" and opts.args or nil
  sh.jump_bookmark_prev(arg)
end, {
  nargs = "?",
  complete = function()
    return { "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }
  end,
  desc = "Jump to previous bookmark (optionally filter by tag): :SmartBookmarkPrev [tag]",
})

vim.api.nvim_create_user_command("SmartBookmarkSearch", function(opts)
  local arg = opts.args ~= "" and opts.args or "all"
  local upper = arg:upper()
  if upper == "ALL" or upper == "CURRENT" then
    sh.search_bookmarks({ scope = arg:lower() })
  else
    sh.search_bookmarks({ scope = "all", tag = upper })
  end
end, {
  nargs = "?",
  complete = function()
    return { "all", "current", "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }
  end,
  desc = "Search bookmarks via Telescope / Snacks / Bottom Pane: :SmartBookmarkSearch [tag|all|current]",
})

vim.api.nvim_create_user_command("SmartBookmarkBottom", function(opts)
  local arg = opts.args ~= "" and opts.args or "all"
  local upper = arg:upper()
  if upper == "ALL" or upper == "CURRENT" then
    sh.bottom_pane_bookmarks(arg:lower())
  else
    sh.bottom_pane_bookmarks("all", upper)
  end
end, {
  nargs = "?",
  complete = function()
    return { "all", "current", "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }
  end,
  desc = "Open bottom buffer window for bookmarks: :SmartBookmarkBottom [tag|all|current]",
})

vim.api.nvim_create_user_command("SmartBookmarkFilter", function(opts)
  if opts.args ~= "" then
    local tag = opts.args:upper()
    if tag == "ALL" then
      tag = nil
    end
    sh.search_bookmarks({ scope = "all", tag = tag })
  else
    sh.filter_bookmarks(function(chosen_tag)
      sh.search_bookmarks({ scope = "all", tag = chosen_tag })
    end)
  end
end, {
  nargs = "?",
  complete = function()
    return { "ALL", "TODO", "FIXME", "WARN", "NOTE", "HACK", "GENERAL" }
  end,
  desc = "Filter and search bookmarks by tag (TODO, FIXME, WARN, NOTE, HACK): :SmartBookmarkFilter [tag]",
})

vim.api.nvim_create_user_command("SmartBookmarkClear", function()
  sh.clear_bookmarks()
  vim.notify("[SmartBookmark] Cleared all bookmarks", vim.log.levels.INFO)
end, {
  desc = "Clear all project bookmarks: :SmartBookmarkClear",
})

vim.api.nvim_create_user_command("SmartBookmarkHUD", function()
  sh.open_hud("bookmarks")
end, {
  desc = "Open Floating HUD directly on Bookmarks tab",
})

-- Default Keymaps
local config = require("smart_highlighter.config")
if config.options.default_keymaps then
  local map = vim.keymap.set
  local km = config.options.keymaps or {}

  -- Helper to safely bind if not explicitly disabled with false
  local function bind(modes, key, fn, desc)
    if key and key ~= false and key ~= "" then
      map(modes, key, fn, { desc = desc })
    end
  end

  -- Highlighting keymaps
  bind({ "n", "v" }, km.toggle or "<leader>hh", function() sh.toggle() end, "SmartHighlight: Toggle (Default Scope)")
  bind({ "n", "v" }, km.toggle_buffer or "<leader>hb", function() sh.toggle_current_buffer() end, "SmartHighlight: Toggle Current Buffer Only")
  bind("n", km.toggle_scope_mode or "<leader>hB", function() sh.toggle_buffer_scope() end, "SmartHighlight: Toggle Buffer Scope Mode (All/Current)")
  bind("n", km.add_regex or "<leader>hH", function() sh.add_regex_interactive() end, "SmartHighlight: Add Regex Pattern")
  bind("n", km.clear_all or "<leader>hc", function() sh.clear_all() end, "SmartHighlight: Clear All")
  bind("n", km.open_hud or "<leader>hm", function() sh.open_hud() end, "SmartHighlight: Open HUD Manager")
  bind("n", km.select_preset or "<leader>hp", function() sh.select_preset() end, "SmartHighlight: Select Preset")
  bind("n", km.toggle_treesitter or "<leader>hs", function() sh.toggle_scope() end, "SmartHighlight: Toggle Treesitter Scope")
  bind("n", km.export_quickfix or "<leader>hq", function() sh.export_quickfix("all") end, "SmartHighlight: Export to Quickfix (All Buffers)")
  bind("n", km.search_matches or "<leader>hf", function() sh.search_matches({ scope = "all" }) end, "SmartHighlight: Search Matches (All Open Buffers)")
  bind("n", km.search_matches_buffer or "<leader>hF", function() sh.search_matches({ scope = "current" }) end, "SmartHighlight: Search Matches (Current Buffer Only)")
  -- Bookmark keymaps
  bind({ "n", "v" }, km.add_bookmark or "<leader>hk", function() sh.add_bookmark() end, "SmartBookmark: Add / Edit Bookmark (Prompt Note & Tag)")
  bind({ "n", "v" }, km.quick_add_bookmark or "<leader>hK", function() sh.quick_add_bookmark() end, "SmartBookmark: Quick Add Bookmark (No Prompt)")
  bind("n", km.toggle_global_bookmarks or "<leader>hx", function() sh.toggle_global_bookmarks() end, "SmartBookmark: Toggle Global Bookmarks (Show/Hide)")
  bind("n", km.delete_bookmark or "<leader>hd", function() sh.delete_bookmark() end, "SmartBookmark: Delete Bookmark at Cursor")
  bind("n", km.clear_bookmarks or "<leader>hD", function() sh.clear_bookmarks() end, "SmartBookmark: Clear All Bookmarks")
  bind("n", km.search_bookmarks or "<leader>hl", function() sh.search_bookmarks({ scope = "all" }) end, "SmartBookmark: List & Search All Bookmarks")
  bind("n", km.bottom_bookmarks or "<leader>hL", function() sh.bottom_pane_bookmarks("all") end, "SmartBookmark: Bottom Pane Bookmarks")
  bind("n", km.filter_bookmarks or "<leader>ht", function()
    sh.filter_bookmarks(function(chosen_tag)
      sh.search_bookmarks({ scope = "all", tag = chosen_tag })
    end)
  end, "SmartBookmark: Filter Bookmarks by Tag (TODO, FIXME, etc.)")

  -- Persistence & Option keymaps
  bind("n", km.toggle_auto_persist or "<leader>hP", function() sh.toggle_auto_persist() end, "SmartHighlight: Toggle Auto-Persist Mode")
  bind("n", km.export_session or "<leader>he", function() sh.save_session(nil, false) end, "SmartHighlight: Export / Save to Repo File")
  bind("n", km.import_session or "<leader>hE", function() sh.load_session(nil, false) end, "SmartHighlight: Import / Reload from Repo File")
  bind("n", km.save_session or "<leader>hS", function() sh.save_session(nil, false) end, "SmartHighlight: Save Session to Disk")
  bind("n", km.load_session or "<leader>hR", function() sh.load_session(nil, false) end, "SmartHighlight: Reload Session from Disk")

  -- Option (Alt) Key Shortcuts (Zero-leader rapid access)
  if config.options.alt_keymaps ~= false then
    bind({ "n", "v" }, km.alt_toggle_bookmark or "<M-b>", function() sh.toggle_bookmark() end, "SmartBookmark: Add / Edit Bookmark (Alt-b)")
    bind({ "n", "v" }, km.alt_quick_bookmark or "<M-B>", function() sh.quick_bookmark() end, "SmartBookmark: Quick Add Bookmark (Alt-B)")
    bind({ "n", "v" }, km.alt_toggle_highlight or "<M-h>", function() sh.toggle() end, "SmartHighlight: Toggle Highlight (Alt-h)")
    bind("n", km.alt_open_hud or "<M-m>", function() sh.open_hud() end, "SmartHighlight: Open HUD Manager (Alt-m)")
  end

  -- Jump navigation keymaps
  bind("n", km.jump_next or "]h", function() sh.jump_next() end, "SmartHighlight: Next Slot Match")
  bind("n", km.jump_prev or "[h", function() sh.jump_prev() end, "SmartHighlight: Prev Slot Match")
  bind("n", km.jump_any_next or "]H", function() sh.jump_any_next() end, "SmartHighlight: Next Match (Any Slot)")
  bind("n", km.jump_any_prev or "[H", function() sh.jump_any_prev() end, "SmartHighlight: Prev Match (Any Slot)")
  bind("n", km.jump_bookmark_next or "]k", function() sh.jump_bookmark_next() end, "SmartBookmark: Next Bookmark")
  bind("n", km.jump_bookmark_prev or "[k", function() sh.jump_bookmark_prev() end, "SmartBookmark: Prev Bookmark")
end
