local stats = require("cmd_cockpit.core.stats")
local config = require("cmd_cockpit.config")

local M = {}

---Initialize command tracking autocommand
function M.setup()
  if not config.options.track_history then
    return
  end

  stats.load()

  local group = vim.api.nvim_create_augroup("CmdCockpitTracker", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local cmd_type = vim.fn.getcmdtype()
      -- Only track ':' Ex commands (not '/' or '?' search)
      if cmd_type == ":" then
        local cmd_line = vim.fn.getcmdline()
        if cmd_line and cmd_line ~= "" then
          vim.schedule(function()
            stats.record_command(cmd_line)
          end)
        end
      end
    end,
  })

  -- Save on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stats.save()
    end,
  })
end

return M
