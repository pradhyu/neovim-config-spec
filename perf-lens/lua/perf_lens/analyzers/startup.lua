local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")

local M = {}

---Analyze startup performance data
---@return { total_ms: number, phases: table[], slow_modules: table[], all_modules: table[], bottleneck_summary: string }
function M.analyze()
  local total_ms = profiler.get_total_startup_ms()
  local slow_thresh = config.options.thresholds.slow_plugin_ms or 4.0

  local sorted_modules = {}
  for name, data in pairs(profiler.state.modules) do
    table.insert(sorted_modules, {
      name = name,
      duration_ms = data.duration_ms,
      caller = data.caller,
      depth = data.depth,
    })
  end

  table.sort(sorted_modules, function(a, b)
    return a.duration_ms > b.duration_ms
  end)

  local slow_modules = {}
  for _, mod in ipairs(sorted_modules) do
    if mod.duration_ms >= slow_thresh then
      table.insert(slow_modules, mod)
    end
  end

  local grade = "⚡ Ultra Fast"
  if total_ms > 100 then
    grade = "🐌 Slow (>100ms)"
  elseif total_ms > 50 then
    grade = "⚠️ Moderate (>50ms)"
  elseif total_ms > 25 then
    grade = "🚀 Good (<50ms)"
  end

  local summary = string.format("Startup: %.2f ms (%s) | %d modules traced", total_ms, grade, #sorted_modules)

  return {
    total_ms = total_ms,
    grade = grade,
    phases = profiler.state.phases,
    slow_modules = slow_modules,
    all_modules = sorted_modules,
    summary = summary,
  }
end

return M
