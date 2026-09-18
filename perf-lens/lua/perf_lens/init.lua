local config = require("perf_lens.config")
local profiler = require("perf_lens.core.profiler")
local require_hook = require("perf_lens.core.require_hook")
local autocmd_hook = require("perf_lens.core.autocmd_hook")
local event_loop = require("perf_lens.core.event_loop")
local memory = require("perf_lens.core.memory")
local dashboard = require("perf_lens.ui.dashboard")

local M = {}

---Initialize the perf_lens plugin
---@param user_opts? table
function M.setup(user_opts)
  local opts = config.setup(user_opts)

  -- Record initial setup phase
  profiler.record_phase("InitSetup")

  -- Enable require tracing
  if opts.enable_on_startup then
    require_hook.enable()
  end

  -- Enable autocommand tracking
  if opts.track_autocmds then
    autocmd_hook.enable()
  end

  -- Enable event loop monitoring
  if opts.track_event_loop then
    event_loop.start()
  end

  -- Attach lifecycle milestone listeners
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      profiler.record_phase("UIEnter")
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      profiler.record_phase("VimEnter")
      vim.schedule(function()
        profiler.record_phase("Ready")
      end)
    end,
  })

  profiler.state.initialized = true
end

---Toggle main performance dashboard
---@param view? "dashboard"|"waterfall"
function M.toggle_dashboard(view)
  dashboard.toggle(view)
end

---Run Lua GC and return freed memory
function M.run_gc()
  return memory.collect_and_measure()
end

---Export current performance report to a JSON or Markdown file
---@param filepath? string
function M.export_report(filepath)
  local startup = require("perf_lens.analyzers/startup").analyze()
  local runtime = require("perf_lens.analyzers/runtime").analyze()
  local mem = memory.get_memory_usage()
  local recommendations = require("perf_lens.advisor/engine").generate_recommendations()

  local target = filepath or ("nvim-perf-report-" .. os.date("%Y%m%d-%H%M%S") .. ".json")
  local report = {
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    neovim_version = tostring(vim.version()),
    startup = startup,
    runtime = runtime,
    memory = mem,
    recommendations = recommendations,
  }

  local file = io.open(target, "w")
  if file then
    file:write(vim.json.encode(report))
    file:close()
    vim.notify(string.format("[PerfLens] Exported report to %s", target), vim.log.levels.INFO)
  else
    vim.notify(string.format("[PerfLens] Failed to write report to %s", target), vim.log.levels.ERROR)
  end
end

return M
