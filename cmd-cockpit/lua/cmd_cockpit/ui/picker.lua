local stats = require("cmd_cockpit.core.stats")
local keymaps = require("cmd_cockpit.core.keymaps")

local M = {}

---Interactive picker for frequent commands
function M.frequent_commands_picker()
  local list = stats.get_top_commands(30)
  if #list == 0 then
    vim.notify("[CmdCockpit] No command history tracked yet", vim.log.levels.WARN)
    return
  end

  local items = {}
  for idx, rec in ipairs(list) do
    local pin = rec.pinned and "📌 " or ""
    table.insert(items, {
      cmd = rec.cmd,
      label = string.format("%2d. %s%-35s (%d uses)", idx, pin, rec.cmd, rec.count),
    })
  end

  vim.ui.select(items, {
    prompt = "Frequent Commands (Select to Execute):",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    vim.notify("[CmdCockpit] ⚡ Executing: :" .. choice.cmd, vim.log.levels.INFO)
    vim.cmd(choice.cmd)
  end)
end

---Interactive picker for all keybindings
---@param mode? string
function M.keymap_picker(mode)
  local list = keymaps.get_keymaps(mode)

  local items = {}
  for _, m in ipairs(list) do
    local desc = m.desc ~= "" and (" - " .. m.desc) or ""
    table.insert(items, {
      map = m,
      label = string.format("[%s] %-18s ➔ %-30s%s", m.mode, m.lhs, m.rhs, desc),
    })
  end

  vim.ui.select(items, {
    prompt = "Neovim Keybindings:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    local remap_modal = require("cmd_cockpit.ui.remap_modal")
    remap_modal.open(choice.map)
  end)
end

return M
