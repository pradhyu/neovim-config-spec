if vim.g.loaded_buffer_buddy == 1 then
  return
end
vim.g.loaded_buffer_buddy = 1

local bb = require("buffer_buddy")

-- User Commands
vim.api.nvim_create_user_command("BufferBuddy", function()
  bb.open_hud()
end, {
  desc = "Open interactive Buffer Buddy Dashboard & Inspector",
})

vim.api.nvim_create_user_command("BufferPin", function()
  bb.pin()
end, {
  desc = "Pin current buffer (protect from sweeps)",
})

vim.api.nvim_create_user_command("BufferUnpin", function()
  bb.unpin()
end, {
  desc = "Unpin current buffer",
})

vim.api.nvim_create_user_command("BufferTogglePin", function()
  bb.toggle_pin()
end, {
  desc = "Toggle pin state for current buffer",
})

vim.api.nvim_create_user_command("BufferSweep", function(opts)
  local arg = opts.args ~= "" and opts.args:lower() or "unmodified"
  if arg == "unmodified" then
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
    return { "unmodified", "hidden", "others", "dead" }
  end,
  desc = "Sweep buffer clutter: :BufferSweep [unmodified|hidden|others|dead]",
})

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

-- Default Keymaps:
-- 1. All non-conflicting shortcuts are available under <leader>b... (e.g. <leader>bj for JSON format, <leader>bt for trim)
-- 2. Standard LazyVim buffer keymaps (<leader>bb, <leader>bd, <leader>bD, <leader>bo, <leader>bp, <leader>be, <leader>bi) are 100% preserved.
-- 3. All BufferBuddy features are also available under <leader>B... prefix.
local config = require("buffer_buddy.config")
if config.options.default_keymaps then
  local map = vim.keymap.set

  -- Hub / Dashboard
  map("n", "<leader>B", function() bb.open_hud() end, { desc = "BufferBuddy: Open Dashboard" })
  map("n", "<leader>BB", function() bb.open_hud() end, { desc = "BufferBuddy: Open Dashboard" })

  -- Non-conflicting <leader>b* shortcuts (including <leader>bj)
  map({ "n", "v" }, "<leader>bj", function() bb.json_format() end, { desc = "BufferBuddy: Format JSON" })
  map({ "n", "v" }, "<leader>bt", function() bb.trim_whitespace() end, { desc = "BufferBuddy: Trim Whitespace" })
  map("n", "<leader>bs", function() bb.select_scratchpad() end, { desc = "BufferBuddy: Open Scratchpad" })
  map("n", "<leader>bS", function()
    vim.ui.input({ prompt = "Snapshot Name: " }, function(input)
      bb.create_snapshot(input ~= "" and input or nil)
    end)
  end, { desc = "BufferBuddy: Create Snapshot" })
  map("n", "<leader>bR", function() bb.select_snapshot() end, { desc = "BufferBuddy: Restore Snapshot" })
  map("n", "<leader>bc", function() bb.close_current() end, { desc = "BufferBuddy: Close Current Safely" })
  map("n", "<leader>bC", function() bb.close_unmodified() end, { desc = "BufferBuddy: Close Unmodified" })
  map("n", "<leader>bh", function() bb.close_hidden() end, { desc = "BufferBuddy: Close Hidden" })

  -- Full <leader>B* suite
  map("n", "<leader>Bp", function() bb.toggle_pin() end, { desc = "BufferBuddy: Toggle Pin" })
  map("n", "<leader>Bd", function() bb.diff_disk() end, { desc = "BufferBuddy: Diff vs Disk" })
  map("n", "<leader>BD", function() bb.diff_clipboard() end, { desc = "BufferBuddy: Diff vs Clipboard" })
  map("n", "<leader>Bs", function() bb.select_scratchpad() end, { desc = "BufferBuddy: Open Scratchpad" })
  map("n", "<leader>BS", function()
    vim.ui.input({ prompt = "Snapshot Name: " }, function(input)
      bb.create_snapshot(input ~= "" and input or nil)
    end)
  end, { desc = "BufferBuddy: Create Snapshot" })
  map("n", "<leader>BR", function() bb.select_snapshot() end, { desc = "BufferBuddy: Restore Snapshot" })
  map("n", "<leader>Bc", function() bb.close_current() end, { desc = "BufferBuddy: Close Current Safely" })
  map("n", "<leader>BC", function() bb.close_unmodified() end, { desc = "BufferBuddy: Close Unmodified" })
  map("n", "<leader>Bo", function() bb.close_others() end, { desc = "BufferBuddy: Close Others" })
  map("n", "<leader>Bh", function() bb.close_hidden() end, { desc = "BufferBuddy: Close Hidden" })
  map("n", "<leader>Bt", function() bb.trim_whitespace() end, { desc = "BufferBuddy: Trim Whitespace" })
  map("n", "<leader>Bj", function() bb.json_format() end, { desc = "BufferBuddy: Format JSON" })
end
