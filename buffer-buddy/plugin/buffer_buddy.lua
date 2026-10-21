if vim.g.loaded_buffer_buddy == 1 then
  return
end
vim.g.loaded_buffer_buddy = 1

local bb = require("buffer_buddy")

-- =============================================================================
-- User Commands
-- =============================================================================

vim.api.nvim_create_user_command("BufferBuddy", function()
  bb.open_hud()
end, {
  desc = "Open interactive Buffer Buddy Dashboard & Inspector",
})

vim.api.nvim_create_user_command("BufferPin", function(opts)
  local arg = opts.args:lower()
  if arg == "global" then
    bb.pin_global()
  else
    bb.pin()
  end
end, {
  nargs = "?",
  complete = function() return { "local", "global" } end,
  desc = "Pin current buffer: :BufferPin [local|global]",
})

vim.api.nvim_create_user_command("BufferUnpin", function(opts)
  local arg = opts.args:lower()
  if arg == "global" then
    bb.unpin_global()
  else
    bb.unpin()
  end
end, {
  nargs = "?",
  complete = function() return { "local", "global" } end,
  desc = "Unpin current buffer: :BufferUnpin [local|global]",
})

vim.api.nvim_create_user_command("BufferTogglePin", function(opts)
  local arg = opts.args:lower()
  if arg == "global" then
    bb.toggle_global_pin()
  else
    bb.toggle_pin()
  end
end, {
  nargs = "?",
  complete = function() return { "local", "global" } end,
  desc = "Toggle pin state: :BufferTogglePin [local|global]",
})

vim.api.nvim_create_user_command("BufferSweep", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "tab"
  if arg == "tab" or arg == "tab_unmodified" then
    bb.close_tab_unmodified()
  elseif arg == "tab_hidden" then
    bb.close_tab_hidden()
  elseif arg == "tab_others" then
    bb.close_tab_others()
  elseif arg == "unmodified" then
    bb.close_unmodified()
  elseif arg == "hidden" then
    bb.close_hidden()
  elseif arg == "others" then
    bb.close_others()
  elseif arg == "dead" then
    bb.close_dead()
  else
    vim.notify(string.format("[BufferBuddy] Unknown sweep target '%s'", arg), vim.log.levels.WARN)
  end
end, {
  nargs = "?",
  complete = function()
    return { "tab", "tab_unmodified", "tab_hidden", "tab_others", "unmodified", "hidden", "others", "dead" }
  end,
  desc = "Sweep buffer clutter: :BufferSweep [tab|tab_hidden|tab_others|unmodified|hidden|others|dead]",
})

-- Workspace Tab Commands
vim.api.nvim_create_user_command("BufferTabName", function(opts)
  if opts.args ~= "" then
    bb.set_tab_name(opts.args)
  else
    bb.rename_tab_interactive()
  end
end, {
  nargs = "?",
  desc = "Name or rename workspace tab: :BufferTabName [name]",
})

vim.api.nvim_create_user_command("BufferTabNew", function(opts)
  bb.new_tab(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  desc = "Create a new named workspace tab: :BufferTabNew [name]",
})

vim.api.nvim_create_user_command("BufferTabClose", function(opts)
  local force = opts.bang or (opts.args:lower() == "force" or opts.args:lower() == "!")
  bb.close_tab_safe(nil, force)
end, {
  bang = true,
  nargs = "?",
  desc = "Close workspace tab & sweep exclusive buffers: :BufferTabClose[!]",
})

vim.api.nvim_create_user_command("BufferTabMove", function(opts)
  if opts.args ~= "" then
    bb.move_buffer_to_tab(opts.args)
  else
    bb.move_buffer_interactive()
  end
end, {
  nargs = "?",
  desc = "Move current buffer to target tab workspace: :BufferTabMove [tab_number]",
})

vim.api.nvim_create_user_command("BufferTabSend", function(opts)
  if opts.args ~= "" then
    bb.send_buffer_to_tab(opts.args)
  else
    vim.notify("[BufferBuddy] Please specify target tab number: :BufferTabSend <tab>", vim.log.levels.WARN)
  end
end, {
  nargs = 1,
  desc = "Share current buffer with target tab: :BufferTabSend <tab_number>",
})

vim.api.nvim_create_user_command("BufferTabNext", function()
  bb.next_tab_buffer()
end, {
  desc = "Next buffer in current workspace tab",
})

vim.api.nvim_create_user_command("BufferTabPrev", function()
  bb.prev_tab_buffer()
end, {
  desc = "Previous buffer in current workspace tab",
})

-- Utilities
vim.api.nvim_create_user_command("BufferDiffDisk", function()
  bb.diff_disk()
end, {
  desc = "Diff buffer against file on disk",
})

vim.api.nvim_create_user_command("BufferDiffClipboard", function()
  bb.diff_clipboard()
end, {
  desc = "Diff buffer against system clipboard",
})

vim.api.nvim_create_user_command("BufferScratch", function(opts)
  if opts.args == "" then
    bb.select_scratchpad()
  else
    bb.open_scratchpad(opts.args)
  end
end, {
  nargs = "?",
  complete = function()
    return { "markdown", "lua", "sql", "json", "sh", "python" }
  end,
  desc = "Open scratchpad buffer: :BufferScratch [filetype]",
})

vim.api.nvim_create_user_command("BufferSnapshot", function(opts)
  bb.create_snapshot(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  desc = "Create named in-memory checkpoint: :BufferSnapshot [name]",
})

vim.api.nvim_create_user_command("BufferRestore", function()
  bb.select_snapshot()
end, {
  desc = "Restore buffer to an in-memory snapshot checkpoint",
})

vim.api.nvim_create_user_command("BufferTransform", function(opts)
  local arg = opts.args:lower()
  if arg == "trim" or arg == "whitespace" then
    bb.trim_whitespace()
  elseif arg == "json" or arg == "json_format" then
    bb.json_format()
  elseif arg == "json_minify" then
    bb.json_minify()
  elseif arg == "base64_encode" then
    bb.base64_encode()
  elseif arg == "base64_decode" then
    bb.base64_decode()
  elseif arg == "url_encode" then
    bb.url_encode()
  elseif arg == "url_decode" then
    bb.url_decode()
  elseif arg == "dedup" then
    bb.dedup_lines()
  elseif arg == "sort" then
    bb.sort_lines(nil, nil, false)
  elseif arg == "sort_unique" then
    bb.sort_lines(nil, nil, true)
  elseif arg == "table" or arg == "markdown_table" then
    bb.format_markdown_table()
  else
    vim.notify(string.format("[BufferBuddy] Unknown transform '%s'", arg), vim.log.levels.WARN)
  end
end, {
  nargs = 1,
  complete = function()
    return { "trim", "json", "json_minify", "base64_encode", "base64_decode", "url_encode", "url_decode", "dedup", "sort", "sort_unique", "table" }
  end,
  desc = "Run buffer transformation: :BufferTransform <transform_name>",
})

vim.api.nvim_create_user_command("BufferJSON", function()
  bb.json_format()
end, {
  desc = "Format / Prettify JSON buffer or selection",
})

-- Breadcrumb Commands
vim.api.nvim_create_user_command("BufferBreadcrumbsToggle", function()
  bb.toggle_breadcrumbs()
end, {
  desc = "Toggle buffer breadcrumbs winbar: :BufferBreadcrumbsToggle",
})

vim.api.nvim_create_user_command("BufferBreadcrumbToggle", function()
  bb.toggle_breadcrumbs()
end, {
  desc = "Toggle buffer breadcrumbs winbar: :BufferBreadcrumbToggle",
})

-- =============================================================================
-- Default Keymaps
-- =============================================================================
local config = require("buffer_buddy.config")
if config.options.default_keymaps then
  local map = vim.keymap.set

  -- Hub / Dashboard
  map("n", "<leader>B", function() bb.open_hud() end, { desc = "BufferBuddy: Open Dashboard" })
  map("n", "<leader>BB", function() bb.open_hud() end, { desc = "BufferBuddy: Open Dashboard" })
  map("n", "<leader>Bb", function() bb.toggle_breadcrumbs() end, { desc = "BufferBuddy: Toggle Breadcrumbs" })

  -- Workspace & Tab Management (<leader>B...)
  map("n", "<leader>Bn", function() bb.rename_tab_interactive() end, { desc = "BufferBuddy: Rename Workspace Tab" })
  map("n", "<leader>BN", function() bb.new_tab() end, { desc = "BufferBuddy: New Workspace Tab" })
  map("n", "<leader>Bm", function() bb.move_buffer_interactive() end, { desc = "BufferBuddy: Move Buffer to Tab" })
  map("n", "<leader>Bx", function() bb.close_tab_safe() end, { desc = "BufferBuddy: Safe Tab Close & Clean" })
  map("n", "<leader>Bu", function() bb.close_tab_unmodified() end, { desc = "BufferBuddy: Sweep Tab Unmodified" })

  -- Tab Buffer Cycling
  map("n", "[B", function() bb.prev_tab_buffer() end, { desc = "BufferBuddy: Prev Buffer in Workspace Tab" })
  map("n", "]B", function() bb.next_tab_buffer() end, { desc = "BufferBuddy: Next Buffer in Workspace Tab" })

  -- Pinning (Local vs Global)
  map("n", "<leader>Bp", function() bb.toggle_pin() end, { desc = "BufferBuddy: Toggle Local Pin" })
  map("n", "<leader>BP", function() bb.toggle_global_pin() end, { desc = "BufferBuddy: Toggle Global Pin (All Tabs)" })

  -- Diffs & Snapshots
  map("n", "<leader>Bd", function() bb.diff_disk() end, { desc = "BufferBuddy: Diff vs Disk" })
  map("n", "<leader>BD", function() bb.diff_clipboard() end, { desc = "BufferBuddy: Diff vs Clipboard" })
  map("n", "<leader>Bs", function() bb.select_scratchpad() end, { desc = "BufferBuddy: Open Scratchpad" })
  map("n", "<leader>BS", function()
    vim.ui.input({ prompt = "Snapshot Name: " }, function(input)
      bb.create_snapshot(input ~= "" and input or nil)
    end)
  end, { desc = "BufferBuddy: Create Snapshot" })
  map("n", "<leader>BR", function() bb.select_snapshot() end, { desc = "BufferBuddy: Restore Snapshot" })

  -- Hygiene Sweeps
  map("n", "<leader>Bc", function() bb.close_current() end, { desc = "BufferBuddy: Close Current Safely" })
  map("n", "<leader>BC", function() bb.close_unmodified() end, { desc = "BufferBuddy: Close All Tabs Unmodified" })
  map("n", "<leader>Bo", function() bb.close_others() end, { desc = "BufferBuddy: Close All Other Buffers" })
  map("n", "<leader>Bh", function() bb.close_hidden() end, { desc = "BufferBuddy: Close All Hidden Buffers" })

  -- Transforms
  map({ "n", "v" }, "<leader>Bt", function() bb.trim_whitespace() end, { desc = "BufferBuddy: Trim Whitespace" })
  map({ "n", "v" }, "<leader>Bj", function() bb.json_format() end, { desc = "BufferBuddy: Format JSON" })

  -- Non-conflicting <leader>b* shortcuts
  map({ "n", "v" }, "<leader>bj", function() bb.json_format() end, { desc = "BufferBuddy: Format JSON" })
  map({ "n", "v" }, "<leader>bt", function() bb.trim_whitespace() end, { desc = "BufferBuddy: Trim Whitespace" })
  map("n", "<leader>bs", function() bb.select_scratchpad() end, { desc = "BufferBuddy: Open Scratchpad" })
  map("n", "<leader>bc", function() bb.close_current() end, { desc = "BufferBuddy: Close Current Safely" })
  map("n", "<leader>bu", function() bb.close_tab_unmodified() end, { desc = "BufferBuddy: Sweep Tab Unmodified" })
end
