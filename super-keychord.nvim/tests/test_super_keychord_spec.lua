-- Tests for super-keychord.nvim
local sk = require("super_keychord")
local keychords = require("super_keychord.core.keychords")

local function assert_true(cond, msg)
  if not cond then
    error("ASSERTION FAILED: " .. (msg or "expected true"))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error(string.format("ASSERTION FAILED: expected '%s', got '%s' (%s)", tostring(b), tostring(a), msg or ""))
  end
end

print(">>> [Test 1] Setup SuperKeychord...")
sk.setup({
  default_mode = "all",
  include_buffer_local = true,
  include_plug_maps = false,
  execute_on_select = false,
})
print("✓ SuperKeychord initialized")

print(">>> [Test 2] Keychord Normalization...")
local d1, c1 = keychords.normalize_chord(" fe")
assert_eq(d1, "<leader>fe", "Leading space normalizes to <leader>")
assert_eq(c1, "leaderfe", "Clean chord strips brackets and lowers case")

local d2, c2 = keychords.normalize_chord("<Space>w")
assert_eq(d2, "<leader>w", "<Space> normalizes to <leader>")
assert_eq(c2, "leaderw", "Clean chord removes brackets")

local d3, _ = keychords.normalize_chord("\27")
assert_eq(d3, "<Esc>", "Escape byte normalizes to <Esc>")
print("✓ Chord normalization passed")

print(">>> [Test 3] Collect Keychords...")
-- Define test keymaps
vim.keymap.set("n", "<leader>tst", "<cmd>echo 'test'<cr>", { desc = "Test Super Keychord Map" })
vim.keymap.set("v", "<leader>vmp", "<cmd>echo 'visual'<cr>", { desc = "Visual Test Map" })

local all = sk.get_keychords("all")
assert_true(#all > 0, "Should collect at least 1 keychord")

local found_test = false
for _, entry in ipairs(all) do
  if entry.display_lhs == "<leader>tst" then
    found_test = true
    assert_eq(entry.desc, "Test Super Keychord Map", "Description must match")
    assert_eq(entry.mode, "n", "Mode must be 'n'")
  end
end
assert_true(found_test, "Custom test keychord must be found in results")
print("✓ Keychord collection passed")

print(">>> [Test 4] Filter by Mode...")
local n_maps = sk.get_keychords("n")
for _, entry in ipairs(n_maps) do
  assert_eq(entry.mode, "n", "All returned entries must be normal mode")
end
print("✓ Mode filtering passed")

print(">>> [Test 5] Commands and Module Exports...")
assert_true(type(sk.open) == "function", "sk.open is a function")
assert_true(type(sk.open_normal) == "function", "sk.open_normal is a function")
assert_true(type(sk.open_buffer) == "function", "sk.open_buffer is a function")
assert_true(vim.fn.exists(":SuperKeychord") == 2, ":SuperKeychord command exists")
assert_true(vim.fn.exists(":SuperKeychordNormal") == 2, ":SuperKeychordNormal command exists")
print("✓ Exports and user commands verified")

print(">>> [Test 6] Frecency Tracking & Top Boost...")
local tracker = require("super_keychord.core.tracker")
tracker.stats = {} -- Reset stats table for test isolation
-- Record usage for test chord
tracker.record_usage("<leader>tst", true)
tracker.record_usage("<leader>tst", true)
local rec = tracker.get_record("<leader>tst")
assert_true(rec ~= nil, "Record exists")
assert_eq(rec.count, 2, "Count is 2")

local sorted = sk.get_keychords("n")
assert_eq(sorted[1].display_lhs, "<leader>tst", "Most used keychord must be ranked at top #1")
assert_true(sorted[1].usage_count >= 2, "Usage count matches")
print("✓ Frecency tracking & top ranking verified")

print("\n==============================================")
print("🎉 ALL SUPER-KEYCHORD TESTS PASSED! 🎉")
print("==============================================")
