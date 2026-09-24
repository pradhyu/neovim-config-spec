local config = require("cmd_cockpit.config")
local tracker = require("cmd_cockpit.core.tracker")
local stats = require("cmd_cockpit.core.stats")
local keymaps = require("cmd_cockpit.core.keymaps")
local overrides = require("cmd_cockpit.core.overrides")
local hud = require("cmd_cockpit.ui.hud")
local remap_modal = require("cmd_cockpit.ui.remap_modal")
local picker = require("cmd_cockpit.ui.picker")
local statusline = require("cmd_cockpit.ui.statusline")

local M = {}

---Setup cmd-cockpit plugin
---@param user_opts? table
function M.setup(user_opts)
  config.setup(user_opts)
  tracker.setup()

  if config.options.auto_apply_overrides then
    overrides.load_and_apply()
  end
end

-- UI APIs
M.open_cockpit = function() hud.open(1) end
M.open_frequent = function() hud.open(1) end
M.open_keymaps = function() hud.open(2) end
M.open_overrides = function() hud.open(3) end
M.open_remap = remap_modal.open
M.picker_frequent = picker.frequent_commands_picker
M.picker_keymaps = picker.keymap_picker
M.statusline = statusline.get

-- Core APIs
M.get_top_commands = stats.get_top_commands
M.record_command = stats.record_command
M.toggle_pin = stats.toggle_pin
M.get_keymaps = keymaps.get_keymaps
M.search_keymaps = keymaps.search_keymaps
M.set_override = overrides.set_override
M.remove_override = overrides.remove_override
M.reset_overrides = overrides.reset_all
M.export_overrides = overrides.export_lua

---Print command analytics report
function M.view_stats()
  local top = stats.get_top_commands(10)
  local total_runs = 0
  for _, r in pairs(stats.records) do
    total_runs = total_runs + r.count
  end

  local lines = {
    "📊 Command Cockpit Analytics:",
    string.format(" • Unique Commands Tracked: %d", #vim.tbl_keys(stats.records)),
    string.format(" • Total Command Runs:      %d", total_runs),
    " • Top 5 Commands:",
  }

  for i = 1, math.min(#top, 5) do
    local r = top[i]
    table.insert(lines, string.format("   [%d] :%-25s (%d runs)", i, r.cmd, r.count))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
