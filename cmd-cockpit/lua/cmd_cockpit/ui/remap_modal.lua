local overrides = require("cmd_cockpit.core.overrides")
local keymaps = require("cmd_cockpit.core.keymaps")

local M = {}

---Open interactive remapping dialogue for a keymap
---@param entry? { mode: string, lhs: string, rhs: string, desc: string }
---@param on_done? fun()
function M.open(entry, on_done)
  local mode = entry and entry.mode or "n"
  local old_lhs = entry and entry.lhs or ""

  local function prompt_old_lhs()
    if old_lhs ~= "" then
      prompt_new_lhs()
    else
      vim.ui.input({ prompt = "Current Keybinding to Override (e.g. <leader>ff): " }, function(input)
        if not input or input == "" then return end
        old_lhs = vim.trim(input)
        prompt_new_lhs()
      end)
    end
  end

  function prompt_new_lhs()
    vim.ui.input({ prompt = string.format("New Keybinding for '%s' [%s]: ", old_lhs, mode) }, function(new_input)
      if not new_input or new_input == "" then return end
      local new_lhs = vim.trim(new_input)

      -- Check for collisions
      local existing_maps = keymaps.get_keymaps(mode)
      local collision = nil
      for _, m in ipairs(existing_maps) do
        if m.lhs == new_lhs and m.lhs ~= old_lhs then
          collision = m
          break
        end
      end

      local function do_apply()
        local ok, msg = overrides.set_override(mode, old_lhs, new_lhs, entry and entry.rhs, entry and entry.desc)
        if ok then
          vim.notify("[CmdCockpit] 🔄 " .. msg, vim.log.levels.INFO)
        else
          vim.notify("[CmdCockpit] " .. msg, vim.log.levels.WARN)
        end
        if on_done then on_done() end
      end

      if collision then
        vim.ui.select({ "Yes, Override", "Cancel" }, {
          prompt = string.format("⚠️ '%s' is already mapped to '%s' (%s). Override?", new_lhs, collision.rhs, collision.desc),
        }, function(choice)
          if choice == "Yes, Override" then
            do_apply()
          end
        end)
      else
        do_apply()
      end
    end)
  end

  prompt_old_lhs()
end

return M
