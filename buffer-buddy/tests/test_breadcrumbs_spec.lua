local bb = require("buffer_buddy")
local breadcrumbs = require("buffer_buddy.ui.breadcrumbs")

local function assert_true(cond, msg)
  if not cond then
    error("Assertion failed: " .. (msg or "expected true"))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("Assertion failed: %s != %s (%s)", tostring(a), tostring(b), msg or ""))
  end
end

print(">>> [Test 1] Setup Breadcrumbs & Verify Highlights...")
bb.setup({
  tab_scoping = true,
  breadcrumbs = {
    enabled = true,
    separator = "  ",
    show_workspace = true,
    show_pin = true,
    show_modified = true,
    show_readonly = true,
    max_depth = 4,
  },
})

assert_true(breadcrumbs.is_enabled(), "Breadcrumbs should be enabled by default")
print("✓ Breadcrumbs initialized")

print(">>> [Test 2] Render Breadcrumbs for a Normal File Buffer...")
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, vim.fn.getcwd() .. "/lua/my_plugin/core/parser.lua")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local M = {}" })
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)

local result = breadcrumbs.build_breadcrumb_string(win, buf)
assert_true(result:find("parser.lua") ~= nil, "Should contain filename 'parser.lua'")
assert_true(result:find("my_plugin") ~= nil, "Should contain directory 'my_plugin'")
assert_true(result:find("core") ~= nil, "Should contain directory 'core'")
print("✓ Breadcrumbs for file buffer passed: " .. result)

print(">>> [Test 3] Test Modified & Readonly & Pin Indicators...")
vim.bo[buf].modified = true
local mod_result = breadcrumbs.build_breadcrumb_string(win, buf)
assert_true(mod_result:find("●") ~= nil, "Should display modified dot")

bb.pin(buf)
local pin_result = breadcrumbs.build_breadcrumb_string(win, buf)
assert_true(pin_result:find("📌") ~= nil, "Should display local pin badge")

bb.pin_global(buf)
local global_pin_result = breadcrumbs.build_breadcrumb_string(win, buf)
assert_true(global_pin_result:find("🌐") ~= nil, "Should display global pin badge")

vim.bo[buf].readonly = true
local ro_result = breadcrumbs.build_breadcrumb_string(win, buf)
assert_true(ro_result:find("🔒") ~= nil, "Should display readonly lock")
print("✓ State indicators passed")

print(">>> [Test 4] Path Depth Truncation with Ellipsis...")
local deep_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(deep_buf, vim.fn.getcwd() .. "/a/b/c/d/e/f/g/file.lua")
vim.api.nvim_win_set_buf(win, deep_buf)

local deep_result = breadcrumbs.build_breadcrumb_string(win, deep_buf)
assert_true(deep_result:find("file.lua") ~= nil, "Should contain 'file.lua'")
assert_true(deep_result:find("…") ~= nil, "Should truncate deep directories with '…'")
print("✓ Depth truncation passed: " .. deep_result)

print(">>> [Test 5] Excluded Buffers (nofile / special)...")
local nofile_buf = vim.api.nvim_create_buf(false, true)
vim.bo[nofile_buf].buftype = "nofile"
vim.api.nvim_win_set_buf(win, nofile_buf)
local nofile_rendered = breadcrumbs.render()
assert_eq(nofile_rendered, "", "Nofile buffer should render empty string for winbar")
print("✓ Excluded buffer passed")

print(">>> [Test 6] Breadcrumbs Toggle...")
breadcrumbs.toggle()
assert_true(not breadcrumbs.is_enabled(), "Should be disabled after toggle")
vim.api.nvim_win_set_buf(win, buf)
assert_eq(breadcrumbs.render(), "", "Should return empty string when disabled")

breadcrumbs.enable()
assert_true(breadcrumbs.is_enabled(), "Should be enabled after enable()")
assert_true(breadcrumbs.render() ~= "", "Should render breadcrumbs when re-enabled")
print("✓ Toggle / Enable / Disable passed")

print("\n==============================================")
print("🎉 ALL BUFFER BUDDY BREADCRUMB TESTS PASSED! 🎉")
print("==============================================")
