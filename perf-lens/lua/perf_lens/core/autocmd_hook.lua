local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")

local M = {}

local monitored_events = {
  "CursorMoved",
  "CursorMovedI",
  "CursorHold",
  "CursorHoldI",
  "TextChanged",
  "TextChangedI",
  "BufEnter",
  "BufWinEnter",
  "BufReadPost",
  "LspAttach",
}

local augroup = nil

---Attach tracking listeners to critical Neovim events
function M.enable()
  if augroup then
    return
  end
  augroup = vim.api.nvim_create_augroup("PerfLensAutocmdTracker", { clear = true })

  for _, event in ipairs(monitored_events) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      callback = function(args)
        local t0 = profiler.now()
        -- Schedule a micro-tick check to measure event cycle resolution
        vim.schedule(function()
          local delta_ms = profiler.elapsed_ms(t0)
          local pattern = (args and args.match) or (args and args.file) or ""
          profiler.record_autocmd(event, pattern, delta_ms)
        end)
      end,
    })
  end
end

---Disable autocmd tracking
function M.disable()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
end

return M
