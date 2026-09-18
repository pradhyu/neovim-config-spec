local M = {}

---@class PerfLensPhase
---@field name string Phase description
---@field timestamp number Nanoseconds from hrtime
---@field duration_ms number Duration in milliseconds

---@class PerfLensState
---@field start_time number
---@field phases PerfLensPhase[]
---@field modules table<string, { duration_ms: number, caller: string, depth: number, timestamp: number }>
---@field module_order string[]
---@field autocmd_stats table<string, { count: number, total_ms: number, max_ms: number, last_ms: number }>
---@field frame_drops table[]
---@field memory_snapshots table[]

M.state = {
  start_time = vim.uv.hrtime(),
  phases = {},
  modules = {},
  module_order = {},
  autocmd_stats = {},
  frame_drops = {},
  memory_snapshots = {},
  initialized = false,
}

---Get current high-resolution timestamp in nanoseconds
---@return number
function M.now()
  return vim.uv.hrtime()
end

---Convert nanoseconds delta to milliseconds with precision
---@param start_nano number
---@param end_nano? number
---@return number
function M.elapsed_ms(start_nano, end_nano)
  local stop = end_nano or vim.uv.hrtime()
  return (stop - start_nano) / 1e6
end

---Record a named startup/lifecycle phase
---@param name string
function M.record_phase(name)
  local now = vim.uv.hrtime()
  local prev_time = #M.state.phases > 0 and M.state.phases[#M.state.phases].timestamp or M.state.start_time
  local duration = (now - prev_time) / 1e6

  table.insert(M.state.phases, {
    name = name,
    timestamp = now,
    duration_ms = duration,
    total_ms = (now - M.state.start_time) / 1e6,
  })
end

---Record a module require load duration
---@param modname string
---@param duration_ms number
---@param caller string
---@param depth integer
function M.record_module(modname, duration_ms, caller, depth)
  if not M.state.modules[modname] then
    table.insert(M.state.module_order, modname)
  end
  M.state.modules[modname] = {
    duration_ms = duration_ms,
    caller = caller,
    depth = depth,
    timestamp = vim.uv.hrtime(),
  }
end

---Record an autocommand execution duration
---@param event string
---@param pattern string
---@param duration_ms number
function M.record_autocmd(event, pattern, duration_ms)
  local key = string.format("%s (%s)", event, pattern ~= "" and pattern or "*")
  local stat = M.state.autocmd_stats[key]
  if not stat then
    stat = { count = 0, total_ms = 0, max_ms = 0, last_ms = 0 }
    M.state.autocmd_stats[key] = stat
  end
  stat.count = stat.count + 1
  stat.total_ms = stat.total_ms + duration_ms
  stat.last_ms = duration_ms
  if duration_ms > stat.max_ms then
    stat.max_ms = duration_ms
  end
end

---Record a frame drop or event loop block
---@param duration_ms number
---@param context? string
function M.record_frame_drop(duration_ms, context)
  table.insert(M.state.frame_drops, {
    timestamp = os.date("%H:%M:%S"),
    duration_ms = duration_ms,
    context = context or "Main Thread Event Loop",
  })
  -- Keep max 50 frame drop records
  if #M.state.frame_drops > 50 then
    table.remove(M.state.frame_drops, 1)
  end
end

---Get total startup time in ms (up to UIEnter / VimEnter or current time)
---@return number
function M.get_total_startup_ms()
  for _, phase in ipairs(M.state.phases) do
    if phase.name == "UIEnter" or phase.name == "VimEnter" or phase.name == "Ready" then
      return phase.total_ms
    end
  end
  return M.elapsed_ms(M.state.start_time)
end

return M
