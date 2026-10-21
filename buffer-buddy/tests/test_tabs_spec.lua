-- Automated headless test runner for Buffer Buddy tab workspace management
local bb = require("buffer_buddy")

vim.o.swapfile = false

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("ASSERTION FAILED: %s (expected %s, got %s)", msg or "", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(val, msg)
  if not val then
    error(string.format("ASSERTION FAILED: expected true for %s", msg or ""))
  end
end

local function assert_false(val, msg)
  if val then
    error(string.format("ASSERTION FAILED: expected false for %s", msg or ""))
  end
end

print(">>> [Test 1] Initialize Buffer Buddy with Tab Scoping...")
bb.setup({
  tab_scoping = true,
  tab_auto_name = true,
  tab_clean_on_close = true,
})

local tab1 = vim.api.nvim_get_current_tabpage()
assert_true(vim.api.nvim_tabpage_is_valid(tab1), "Tab 1 is valid")

-- Create two sample buffers in Tab 1
local b1 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b1, "/tmp/test_file_1.txt")
vim.api.nvim_buf_set_lines(b1, 0, -1, false, { "Hello file 1" })
vim.api.nvim_win_set_buf(0, b1)

local b2 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b2, "/tmp/test_file_2.txt")
vim.api.nvim_buf_set_lines(b2, 0, -1, false, { "Hello file 2" })
bb.add_buffer_to_tab(b2, tab1)
bb.sync_tab_scoping()

assert_true(bb.is_buffer_in_tab(b1, tab1), "b1 should be in tab 1")
assert_true(bb.is_buffer_in_tab(b2, tab1), "b2 should be in tab 1")
print("✓ Tab 1 buffer registration passed")

print(">>> [Test 2] Tab Naming...")
bb.set_tab_name("Backend Workspace", tab1)
assert_eq(bb.get_tab_name(tab1), "Backend Workspace", "Tab 1 name should match")
print("✓ Tab naming passed")

print(">>> [Test 3] Create Tab 2 and Test Buffer Isolation...")
vim.cmd("tabnew")
local tab2 = vim.api.nvim_get_current_tabpage()
assert_true(tab2 ~= tab1, "Tab 2 handle differs from Tab 1")

local b3 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b3, "/tmp/test_file_3.txt")
vim.api.nvim_buf_set_lines(b3, 0, -1, false, { "Hello file 3" })
vim.api.nvim_win_set_buf(0, b3)
bb.set_tab_name("Frontend Workspace", tab2)

bb.sync_tab_scoping()

-- In Tab 2:
-- b3 must be listed; b1 and b2 must be unlisted!
assert_true(bb.is_buffer_in_tab(b3, tab2), "b3 should be in tab 2")
assert_true(vim.bo[b3].buflisted, "b3 should be buflisted in Tab 2")
assert_false(vim.bo[b1].buflisted, "b1 should NOT be buflisted in Tab 2")
assert_false(vim.bo[b2].buflisted, "b2 should NOT be buflisted in Tab 2")
print("✓ Tab 2 isolation passed (Tab 1 buffers hidden)")

print(">>> [Test 4] Switch back to Tab 1...")
vim.api.nvim_set_current_tabpage(tab1)
bb.sync_tab_scoping()

-- In Tab 1:
-- b1 and b2 must be listed; b3 must be unlisted!
assert_true(vim.bo[b1].buflisted, "b1 should be buflisted in Tab 1")
assert_true(vim.bo[b2].buflisted, "b2 should be buflisted in Tab 1")
assert_false(vim.bo[b3].buflisted, "b3 should NOT be buflisted in Tab 1")
print("✓ Tab 1 restored scoping passed (Tab 2 buffer hidden)")

print(">>> [Test 5] Global Buffer Pinning...")
-- Pin b1 globally
bb.pin_global(b1)
assert_true(bb.is_global_pinned(b1), "b1 should be globally pinned")

-- Switch to Tab 2
vim.api.nvim_set_current_tabpage(tab2)
bb.sync_tab_scoping()

-- In Tab 2, b1 should now be listed because it is globally pinned!
assert_true(vim.bo[b1].buflisted, "b1 should be buflisted in Tab 2 because it is global pin")
assert_false(vim.bo[b2].buflisted, "b2 should still be unlisted in Tab 2")

-- Unpin global
bb.unpin_global(b1)
bb.sync_tab_scoping()
assert_false(vim.bo[b1].buflisted, "b1 should now be unlisted in Tab 2 after unpinning global")
print("✓ Global buffer pinning across tabs passed")

print(">>> [Test 6] Buffer Moving across tabs...")
-- In Tab 2, move b3 to Tab 1
bb.move_buffer_to_tab(tab1, b3)
assert_false(bb.is_buffer_in_tab(b3, tab2), "b3 should no longer be in Tab 2")
assert_true(bb.is_buffer_in_tab(b3, tab1), "b3 should now be in Tab 1")
print("✓ Buffer moving across tabs passed")

print(">>> [Test 7] Tab-Scoped Sweeper (close_tab_unmodified)...")
-- Switch to Tab 1
vim.api.nvim_set_current_tabpage(tab1)
bb.sync_tab_scoping()

-- In Tab 1 we have b1, b2, b3
-- Let's pin b1 locally so it is protected
bb.pin(b1)

-- Create a dummy buffer in Tab 2 that is unmodified
vim.api.nvim_set_current_tabpage(tab2)
local b4 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b4, "/tmp/test_file_4.txt")
vim.api.nvim_win_set_buf(0, b4)
bb.sync_tab_scoping()

-- Switch back to Tab 1 and sweep tab unmodified
vim.api.nvim_set_current_tabpage(tab1)
bb.close_tab_unmodified(tab1)

-- b1 is pinned -> must still exist!
assert_true(vim.api.nvim_buf_is_valid(b1), "b1 must be preserved because it is pinned")
-- b4 in Tab 2 must NOT have been swept!
assert_true(vim.api.nvim_buf_is_valid(b4), "b4 in Tab 2 must NOT be touched by Tab 1 sweep")
print("✓ Tab-scoped sweep passed")

print(">>> [Test 8] Safe Tab Close...")
-- Close Tab 2 safely
bb.close_tab_safe(tab2)
assert_eq(#vim.api.nvim_list_tabpages(), 1, "Only 1 tabpage should remain")
-- b4 was exclusive to Tab 2 and unpinned, so it should have been swept!
assert_false(vim.api.nvim_buf_is_valid(b4), "b4 was exclusive to closed tab and should be swept")
print("✓ Safe Tab Close and exclusive buffer cleanup passed")

print(">>> [Test 9] Workspace statusline & HUD info...")
local label = bb.get_workspace_label()
assert_true(label:find("Backend Workspace") ~= nil, "Statusline label contains tab name")

local info = bb.get_all_tabs_info()
assert_eq(#info, 1, "Info reports 1 tab")
assert_eq(info[1].name, "Backend Workspace", "Info reports correct name")
print("✓ Workspace metadata reports passed")

print("\n==========================================")
print("🎉 ALL BUFFER BUDDY TAB TESTS PASSED! 🎉")
print("==========================================")

-- Clean up test buffers
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end
