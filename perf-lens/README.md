# 🚀 nvim-perf-lens.nvim

> **Zero-overhead Neovim performance profiler, jitter detector, and automated optimization advisor.**

`nvim-perf-lens.nvim` analyzes your Neovim startup time, monitors runtime event latency, tracks LuaJIT memory pressure, and provides automated, actionable recommendations to keep your editor ultra-fast and stutter-free.

---

## ✨ Features

* ⏱️ **Microsecond Startup Profiling**: Measures `init.lua`, package managers, plugin `require()` times, and lifecycle phases (`UIEnter`, `VimEnter`, `Ready`).
* 🔄 **Runtime & Autocmd Latency Tracker**: Detects laggy autocommand handlers attached to high-frequency events (`CursorMoved`, `TextChanged`, `BufEnter`).
* 📉 **Event Loop Stutter & Frame-Drop Detection**: Monitors libuv event loop delays and flags blocking synchronous operations that drop 60 FPS frames ($> 16.6\text{ms}$).
* 🧠 **LuaJIT Heap & GC Audit**: Profiles memory consumption, tracks loaded package counts, and runs garbage collection with instant delta reports.
* 💡 **Automated Optimization Advisor**: Built-in rule engine that diagnoses performance bottlenecks (missing `vim.loader`, heavy eager requires, un-debounced cursor handlers) with actionable suggestions and code snippets.
* 🔌 **On-Demand Plugin Manager**: Interactively enable, disable, or toggle plugins with one keypress (`x` / `<Space>`), with automatic persistence to `lua/plugins/perf_disabled.lua`.
* 📊 **Interactive Floating Dashboard & Waterfall Chart**: Visual multi-view dashboard (`[d]` Dashboard, `[p]` Plugins, `[a]` Advisor, `[w]` Waterfall).
* 📁 **CI / Headless Export**: Export full benchmark reports to JSON with `:PerfLens export [filename]`.

---

## 📦 Installation & Setup

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    "pkshrestha/nvim-perf-lens.nvim",
    cmd = { "PerfLens" },
    keys = {
      { "<leader>up", "<cmd>PerfLens<cr>", desc = "Performance Dashboard" },
      { "<leader>uP", "<cmd>PerfLens plugins<cr>", desc = "Plugin Manager / Toggler" },
      { "<leader>ua", "<cmd>PerfLens advisor<cr>", desc = "Optimization Advisor" },
      { "<leader>uw", "<cmd>PerfLens waterfall<cr>", desc = "Startup Waterfall View" },
      { "<leader>um", "<cmd>PerfLens memory<cr>", desc = "Lua Memory & GC" },
    },
    opts = {
      enable_on_startup = true,   -- Enable startup require tracing
      track_autocmds = true,      -- Track autocommand execution durations
      track_memory = true,        -- Monitor Lua memory heap
      track_event_loop = true,    -- Detect main thread stalls
      auto_loader_check = true,   -- Verify vim.loader is enabled
      thresholds = {
        slow_plugin_ms = 4.0,     -- Flag module requires taking > 4ms
        slow_autocmd_ms = 2.0,    -- Flag autocommands taking > 2ms
        frame_drop_ms = 16.6,     -- Flag event loop stalls > 16.6ms
        memory_warn_mb = 120.0,   -- Memory warning threshold
      },
    },
  },
}
```

---

## ⌨️ User Commands & Subcommands

| Command | Action | Description |
| :--- | :--- | :--- |
| `:PerfLens` | Dashboard | Opens the main overview dashboard. |
| `:PerfLens plugins` | Plugin Manager | Interactive plugin list with active/disabled status. |
| `:PerfLens advisor` | Advisor | Displays optimization suggestions, rules, and code snippets. |
| `:PerfLens waterfall` | Waterfall | Displays the visual ASCII/Unicode startup timeline. |
| `:PerfLens disable <plugin>` | Disable Plugin | Disables a plugin on demand and saves to `perf_disabled.lua`. |
| `:PerfLens enable <plugin>` | Enable Plugin | Re-enables a disabled plugin. |
| `:PerfLens memory` / `:PerfLens gc` | Memory & GC | Runs a garbage collection cycle and displays freed memory. |
| `:PerfLens export [path]` | Export Report | Exports performance data to JSON for benchmarking. |

---

## 🖥️ Dashboard Controls

When inside the floating dashboard (`:PerfLens`):
* `d` - Switch to Overview Dashboard.
* `p` - Switch to Plugin Performance & On-Demand Manager.
* `a` - Switch to Optimization Advisor Rules & Code Snippets.
* `w` - Switch to Startup Waterfall Timeline.
* `x` / `<Space>` / `<CR>` - (In Plugin view) Toggle Enable / Disable on the highlighted plugin line.
* `r` - Refresh dashboard metrics.
* `m` - Trigger manual Lua garbage collection and refresh memory stats.
* `q` or `<Esc>` - Close the dashboard window.

---

## 🛠️ Architecture

```text
lua/perf_lens/
├── init.lua                 -- Plugin entrypoint & lifecycle hooks
├── config.lua               -- Configuration & threshold options
├── core/
│   ├── profiler.lua         -- Microsecond hrtime & state store
│   ├── require_hook.lua     -- require() interception & caller tracing
│   ├── autocmd_hook.lua     -- Event latency instrumentation
│   ├── memory.lua           -- LuaJIT heap & GC tracker
│   └── event_loop.lua       -- UV timer jitter / frame drop monitor
├── analyzers/
│   ├── startup.lua          -- Startup phases & module ranking
│   └── runtime.lua          -- Runtime latency & autocmd statistics
├── advisor/
│   └── engine.lua           -- Rule-based optimization heuristics
└── ui/
    ├── dashboard.lua        -- Interactive floating modal
    └── waterfall.lua        -- Waterfall chart generator
```

---

## 📄 License

MIT
