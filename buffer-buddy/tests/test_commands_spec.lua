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
vim.cmd("BufferTabName CoreAPI")
assert_eq(bb.get_tab_name(vim.api.nvim_get_current_tabpage()), "CoreAPI", "Tab renamed via command")

print(">>> Testing :BufferTabNew command...")
vim.cmd("BufferTabNew FrontendUI")
assert_eq(#vim.api.nvim_list_tabpages(), 2, "2 tabs exist")
assert_eq(bb.get_tab_name(vim.api.nvim_get_current_tabpage()), "FrontendUI", "New tab has specified name")

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

print("\n==========================================")
print("🎉 ALL BUFFER BUDDY COMMAND TESTS PASSED! 🎉")
print("==========================================")
