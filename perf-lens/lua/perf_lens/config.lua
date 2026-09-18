local M = {}

---@class PerfLensThresholds
---@field slow_plugin_ms number Milliseconds threshold for slow plugin/require load
---@field slow_autocmd_ms number Milliseconds threshold for slow autocommand
---@field frame_drop_ms number Milliseconds threshold to detect event loop stall
---@field memory_warn_mb number Memory threshold in MB for warning

---@class PerfLensOptions
---@field enable_on_startup boolean Auto-hook startup and require loading
---@field track_autocmds boolean Instrument and track autocommand execution latency
---@field track_memory boolean Track Lua memory deltas and GC metrics
---@field track_event_loop boolean Monitor event loop frame jitter / stalls
---@field auto_loader_check boolean Alert if vim.loader.enable() is disabled
---@field thresholds PerfLensThresholds Performance warning thresholds
---@field ui table UI configuration for dashboard and floating windows

---@type PerfLensOptions
M.defaults = {
  enable_on_startup = true,
  track_autocmds = true,
  track_memory = true,
  track_event_loop = true,
  auto_loader_check = true,
  thresholds = {
    slow_plugin_ms = 4.0,     -- Flag module requires > 4ms
    slow_autocmd_ms = 2.0,    -- Flag autocommands > 2ms
    frame_drop_ms = 16.6,     -- Flag event loop blocks > 16.6ms (dropped 60FPS frame)
    memory_warn_mb = 120.0,   -- Warn when LuaJIT heap exceeds 120MB
  },
  ui = {
    border = "rounded",
    width = 0.85,             -- 85% of editor width
    height = 0.80,            -- 80% of editor height
    highlights = {
      title = "FloatTitle",
      border = "FloatBorder",
      fast = "DiagnosticOk",
      warn = "DiagnosticWarn",
      slow = "DiagnosticError",
      header = "Title",
      subtext = "Comment",
    },
  },
}

---@type PerfLensOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options into defaults
---@param user_opts? table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
  return M.options
end

return M
