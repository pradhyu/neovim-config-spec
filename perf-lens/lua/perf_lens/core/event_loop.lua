local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")

local M = {}

local timer = nil
local last_check = nil
local active = false

---Start event loop stutter monitor
function M.start()
  if active then
    return
  end
  active = true
  last_check = vim.uv.hrtime()

  timer = vim.uv.new_timer()
  -- Tick every 100ms
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      if not active then
        return
      end
      local now = vim.uv.hrtime()
      local delta_ms = (now - last_check) / 1e6
      last_check = now

      -- Expected interval is ~100ms. If delta is > 100 + frame_drop_ms (e.g. 116.6ms), main thread was blocked
      local block_ms = delta_ms - 100
      local threshold = config.options.thresholds.frame_drop_ms or 16.6

      if block_ms >= threshold then
        profiler.record_frame_drop(block_ms, "Event Loop Lag")
      end
    end)
  )
end

---Stop event loop stutter monitor
function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  active = false
end

---Check if event loop monitor is running
---@return boolean
function M.is_running()
  return active
end

return M
