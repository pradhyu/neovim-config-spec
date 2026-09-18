local profiler = require("perf_lens.core.profiler")

local M = {}

---Render ASCII/Unicode waterfall chart of startup phases and top modules
---@param max_width? integer
---@return string[]
function M.render_lines(max_width)
  local width = max_width or 78
  local lines = {}

  local total_ms = profiler.get_total_startup_ms()
  if total_ms <= 0 then
    total_ms = 1.0
  end

  table.insert(lines, string.format("╭─── Startup Timeline & Waterfall (Total: %.2f ms) ───", total_ms))
  table.insert(lines, "")

  -- Time markers
  local time_header = string.format(" 0.0ms %s %.1fms", string.rep("─", math.max(10, width - 20)), total_ms)
  table.insert(lines, time_header)
  table.insert(lines, "")

  local bar_width = math.max(20, width - 35)

  -- Render phases
  table.insert(lines, " [Startup Lifecycle Phases]")
  for _, phase in ipairs(profiler.state.phases) do
    local start_ratio = math.min(1.0, math.max(0.0, (phase.total_ms - phase.duration_ms) / total_ms))
    local end_ratio = math.min(1.0, math.max(0.0, phase.total_ms / total_ms))

    local left_pad = math.floor(start_ratio * bar_width)
    local bar_len = math.max(1, math.floor((end_ratio - start_ratio) * bar_width))

    local bar_str = string.rep(" ", left_pad) .. string.rep("█", bar_len)
    local line = string.format("  %-16s %s (%.2fms)", phase.name:sub(1, 16), bar_str, phase.duration_ms)
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, " [Top Module Requires]")

  -- Render top 12 slowest modules
  local sorted_modules = {}
  for name, data in pairs(profiler.state.modules) do
    table.insert(sorted_modules, {
      name = name,
      duration_ms = data.duration_ms,
      timestamp = data.timestamp,
    })
  end
  table.sort(sorted_modules, function(a, b)
    return a.duration_ms > b.duration_ms
  end)

  local count = math.min(12, #sorted_modules)
  for i = 1, count do
    local mod = sorted_modules[i]
    local ratio = math.min(1.0, mod.duration_ms / total_ms)
    local bar_len = math.max(1, math.floor(ratio * bar_width))
    local bar_str = string.rep("▓", bar_len)
    local line = string.format("  %-22s %s (%.2fms)", mod.name:sub(1, 22), bar_str, mod.duration_ms)
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "╰──────────────────────────────────────────────────────────────────────────╯")

  return lines
end

return M
