local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")
local memory = require("perf_lens.core.memory")

local M = {}

---@class PerfRecommendation
---@field id string Unique rule identifier
---@field level "CRITICAL"|"WARN"|"INFO"|"OPTIMIZATION"
---@field title string Short title
---@field description string Explanation of the performance bottleneck
---@field suggestion string Actionable fix or config change
---@field code_snippet? string Code example to copy or apply
---@field auto_fixable boolean Whether this can be auto-executed
---@field plugin_name? string Associated plugin if applicable

---Run performance rule analysis and generate recommendations
---@return PerfRecommendation[]
function M.generate_recommendations()
  local recommendations = {}

  -- Rule 1: Check if vim.loader is enabled
  if config.options.auto_loader_check then
    local loader_enabled = vim.loader and vim.loader.enabled
    if not loader_enabled then
      table.insert(recommendations, {
        id = "LOADER_DISABLED",
        level = "CRITICAL",
        title = "Lua Bytecode Cache (vim.loader) is Disabled",
        description = "Neovim's built-in byte-compiler cache speeds up module loading by 25-50%.",
        suggestion = "Add `vim.loader.enable()` as the very first line of your `init.lua`.",
        code_snippet = "vim.loader.enable()",
        auto_fixable = false,
      })
    end
  end

  -- Rule 2: Eager LazyVim plugins that could be deferred
  local lazy_cfg = package.loaded["lazy.core.config"]
  if lazy_cfg and lazy_cfg.plugins then
    for name, plug in pairs(lazy_cfg.plugins) do
      if plug.enabled ~= false and plug.lazy == false and not plug._.loaded then
        -- Eagerly declared without explicit trigger
        if not name:match("^lazy%.nvim$") and not name:match("^LazyVim$") and not name:match("^tokyonight") then
          table.insert(recommendations, {
            id = "EAGER_PLUGIN_" .. name:gsub("[^%w]", "_"),
            level = "OPTIMIZATION",
            plugin_name = name,
            title = string.format("Plugin `%s` is configured eager (`lazy = false`)", name),
            description = "Eager plugins increase startup time. Consider loading on an event or keymap.",
            suggestion = string.format("Add `event = 'VeryLazy'` to `%s` plugin specification.", name),
            code_snippet = string.format('{\n  "%s",\n  event = "VeryLazy",\n}', plug[1] or name),
            auto_fixable = false,
          })
        end
      end
    end
  end

  -- Rule 3: Heavy modules recorded by profiler
  local slow_thresh = config.options.thresholds.slow_plugin_ms or 4.0
  for name, data in pairs(profiler.state.modules) do
    if data.duration_ms >= slow_thresh and data.depth <= 1 then
      table.insert(recommendations, {
        id = "EAGER_HEAVY_MODULE_" .. name:gsub("[^%w]", "_"),
        level = "WARN",
        plugin_name = name,
        title = string.format("Heavy Require: `%s` (%.2f ms)", name, data.duration_ms),
        description = string.format("Module `%s` took %.2f ms to load synchronously (caller: `%s`).", name, data.duration_ms, data.caller),
        suggestion = "Defer require() inside a keymap callback or load via `event = 'VeryLazy'`.",
        code_snippet = string.format('-- In your plugin spec:\nevent = "VeryLazy",\n-- Or defer require:\nvim.keymap.set("n", "<leader>x", function() require("%s").run() end)', name),
        auto_fixable = false,
      })
    end
  end

  -- Rule 4: Expensive cursor autocommands
  for key, stat in pairs(profiler.state.autocmd_stats) do
    local avg = stat.count > 0 and (stat.total_ms / stat.count) or 0
    if key:match("^CursorMoved") and avg > 2.5 then
      table.insert(recommendations, {
        id = "EXPENSIVE_CURSOR_AUTOCMD",
        level = "WARN",
        title = string.format("Slow CursorMoved Handler: `%s` (avg %.2f ms)", key, avg),
        description = "CursorMoved executes on every keystroke/movement. Handlers > 2.5ms cause micro-stutter.",
        suggestion = "Debounce this callback or attach to `CursorHold` with `vim.opt.updatetime = 200`.",
        code_snippet = "vim.opt.updatetime = 200\n-- Replace CursorMoved with CursorHold",
        auto_fixable = false,
      })
    end
  end

  -- Rule 5: Diagnostic update in insert mode
  local diag_config = vim.diagnostic.config()
  if diag_config and diag_config.update_in_insert == true then
    table.insert(recommendations, {
      id = "DIAGNOSTICS_IN_INSERT",
      level = "INFO",
      title = "Diagnostics update during insert mode (`update_in_insert = true`)",
      description = "Recalculating diagnostics while typing increases CPU load and latency.",
      suggestion = "Set `update_in_insert = false` to evaluate diagnostics only after leaving insert mode.",
      code_snippet = "vim.diagnostic.config({ update_in_insert = false })",
      auto_fixable = true,
    })
  end

  -- Rule 6: Memory usage threshold
  local mem = memory.get_memory_usage()
  local mem_warn = config.options.thresholds.memory_warn_mb or 120.0
  if mem.mb > mem_warn then
    table.insert(recommendations, {
      id = "HIGH_LUA_HEAP",
      level = "WARN",
      title = string.format("High Lua Memory Usage: %.1f MB (Threshold: %.1f MB)", mem.mb, mem_warn),
      description = "Large heap sizes trigger more frequent garbage collection pauses.",
      suggestion = "Run `:PerfLens memory` to trigger GC or disable unused heavy plugins in `:PerfLens plugins`.",
      code_snippet = ":PerfLens memory",
      auto_fixable = true,
    })
  end

  -- Rule 7: Event loop frame drops
  if #profiler.state.frame_drops > 5 then
    table.insert(recommendations, {
      id = "FREQUENT_FRAME_DROPS",
      level = "WARN",
      title = string.format("%d Event Loop Stalls / Dropped Frames Detected", #profiler.state.frame_drops),
      description = "The main Neovim thread was blocked for > 16.6ms multiple times.",
      suggestion = "Check for synchronous file I/O or heavy unbuffered plugins.",
      auto_fixable = false,
    })
  end

  return recommendations
end

return M
