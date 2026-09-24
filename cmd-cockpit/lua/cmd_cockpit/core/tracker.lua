local stats = require("cmd_cockpit.core.stats")
local config = require("cmd_cockpit.config")

local M = {}

---Import recent command history from Neovim history table
local function import_recent_history()
  local total = vim.fn.histnr("cmd")
  if total > 0 then
    local count = math.min(total, 50)
    for i = count, 1, -1 do
      local cmd = vim.fn.histget("cmd", -i)
      if cmd and cmd ~= "" then
        stats.record_command(cmd)
      end
    end
  end
end

---Initialize command tracking autocommand
function M.setup()
  if not config.options.track_history then
    return
  end

  stats.load()
  import_recent_history()

  local group = vim.api.nvim_create_augroup("CmdCockpitTracker", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local ev = vim.v.event
      -- Check if it was an Ex command and not aborted with <Esc>/<C-c>
      if (ev.cmdtype == ":" or ev.cmdtype == "" or ev.cmdtype == nil) and not ev.abort then
        local cmd = vim.fn.histget("cmd", -1)
        if cmd and cmd ~= "" then
          stats.record_command(cmd)
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
