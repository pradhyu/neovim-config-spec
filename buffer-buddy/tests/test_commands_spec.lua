-- Test user commands for Buffer Buddy tab workspace management
local bb = require("buffer_buddy")
bb.setup({ tab_scoping = true, default_keymaps = true })
dofile("/home/pkshrestha/git/neovim-config-spec/buffer-buddy/plugin/buffer_buddy.lua")

local function assert_true(val, msg)
  if not val then error("ASSERTION FAILED: " .. (msg or "")) end
end
local function assert_eq(a, b, msg)
  if a ~= b then error(string.format("ASSERTION FAILED: %s (expected %s, got %s)", msg or "", vim.inspect(b), vim.inspect(a))) end
end

print(">>> Testing :BufferTabName command...")
vim.cmd("BufferTabName testing 1")
assert_eq(bb.get_tab_name(vim.api.nvim_get_current_tabpage()), "testing 1", "Tab renamed via command with spaces")

print(">>> Testing :BufferTabNew command...")
vim.cmd("BufferTabNew testing 3")
assert_eq(#vim.api.nvim_list_tabpages(), 2, "2 tabs exist")
assert_eq(bb.get_tab_name(vim.api.nvim_get_current_tabpage()), "testing 3", "New tab has specified name with spaces")

print(">>> Testing :BufferPin global & :BufferTogglePin global...")
local cur = vim.api.nvim_get_current_buf()
vim.cmd("BufferPin global")
assert_true(bb.is_global_pinned(cur), "Buffer pinned globally via command")
vim.cmd("BufferTogglePin global")
assert_true(not bb.is_global_pinned(cur), "Buffer global pin toggled off via command")

print(">>> Testing :BufferTabNext & :BufferTabPrev...")
local b_extra = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b_extra, "/tmp/extra.lua")
vim.api.nvim_win_set_buf(0, b_extra)
vim.cmd("BufferTabNext")
vim.cmd("BufferTabPrev")
print("✓ Tab buffer cycling commands succeed")

print(">>> Testing :BufferTabClose command...")
vim.cmd("BufferTabClose")
assert_eq(#vim.api.nvim_list_tabpages(), 1, "Only 1 tab remains after BufferTabClose")

print(">>> Testing :BufferSweep tab...")
vim.cmd("BufferSweep tab")
print("✓ BufferSweep tab command succeed")

print(">>> Testing :BufferTabSelect & :BufferTabList commands...")
assert_true(type(bb.select_tab) == "function", "bb.select_tab is a function")
assert_true(vim.fn.exists(":BufferTabSelect") == 2, ":BufferTabSelect exists")
assert_true(vim.fn.exists(":BufferTabList") == 2, ":BufferTabList exists")
print("✓ Tab picker commands exist")

print("\n==========================================")
print("🎉 ALL BUFFER BUDDY COMMAND TESTS PASSED! 🎉")
print("==========================================")
