local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")

local M = {}

---Analyze runtime latency metrics
---@return { slow_autocmds: table[], frame_drops: table[], active_clients: number, total_buffers: number }
function M.analyze()
  local slow_thresh = config.options.thresholds.slow_autocmd_ms or 2.0
  local autocmds = {}

  for key, stat in pairs(profiler.state.autocmd_stats) do
    local avg_ms = stat.count > 0 and (stat.total_ms / stat.count) or 0
    table.insert(autocmds, {
      name = key,
      count = stat.count,
      avg_ms = avg_ms,
      max_ms = stat.max_ms,
      last_ms = stat.last_ms,
      is_slow = avg_ms >= slow_thresh or stat.max_ms >= (slow_thresh * 2),
    })
  end

  table.sort(autocmds, function(a, b)
    return a.avg_ms > b.avg_ms
  end)

  local slow_autocmds = {}
  for _, item in ipairs(autocmds) do
    if item.is_slow then
      table.insert(slow_autocmds, item)
    end
  end

  local active_clients = #vim.lsp.get_clients()
  local buffers = #vim.api.nvim_list_bufs()

  return {
    all_autocmds = autocmds,
    slow_autocmds = slow_autocmds,
    frame_drops = profiler.state.frame_drops,
    active_clients = active_clients,
    total_buffers = buffers,
  }
end

return M
