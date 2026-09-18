local config = require("perf_lens.config")
local profiler = require("perf_lens.core.profiler")
local memory = require("perf_lens.core.memory")
local plugin_manager = require("perf_lens.core.plugin_manager")
local startup_analyzer = require("perf_lens.analyzers/startup")
local runtime_analyzer = require("perf_lens.analyzers/runtime")
local advisor_engine = require("perf_lens.advisor/engine")
local waterfall = require("perf_lens.ui.waterfall")

local M = {}

local active_buf = nil
local active_win = nil
local ns_id = vim.api.nvim_create_namespace("PerfLensHighlights")
local current_view = "dashboard" -- "dashboard" | "plugins" | "advisor" | "waterfall"
local line_plugin_map = {} -- line_number -> plugin_name

---Calculate floating window dimensions
---@return integer width, integer height, integer row, integer col
local function get_window_layout()
  local ui_opts = config.options.ui
  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local width = math.floor(total_w * (ui_opts.width or 0.85))
  local height = math.floor(total_h * (ui_opts.height or 0.80))
  local row = math.floor((total_h - height) / 2)
  local col = math.floor((total_w - width) / 2)

  return width, height, row, col
end

---Build text lines for the main dashboard view
---@param width integer
---@return string[]
local function build_dashboard_lines(width)
  local lines = {}
  local startup = startup_analyzer.analyze()
  local runtime = runtime_analyzer.analyze()
  local mem = memory.get_memory_usage()
  local pkgs = memory.count_loaded_packages()
  local recommendations = advisor_engine.generate_recommendations()

  table.insert(lines, "  ⚡ Neovim Performance Lens & Optimization Center")
  table.insert(lines, "  " .. string.rep("─", width - 6))

  -- Section 1: Overview Stats
  local stat_line = string.format(
    "  Startup: %-18s | Lua Heap: %-10s | Modules: %-4d | Buffers: %-3d | LSP: %-2d",
    string.format("%.2f ms (%s)", startup.total_ms, startup.grade),
    mem.formatted,
    pkgs.user_packages,
    runtime.total_buffers,
    runtime.active_clients
  )
  table.insert(lines, stat_line)
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "")

  -- Section 2: Top Startup Bottlenecks
  table.insert(lines, "  ⏱️  Top Module Require Bottlenecks:")
  if #startup.slow_modules == 0 then
    table.insert(lines, "     ✓ No slow modules detected (all loaded under threshold).")
  else
    for i = 1, math.min(8, #startup.slow_modules) do
      local mod = startup.slow_modules[i]
      table.insert(
        lines,
        string.format("     %d. %-32s  %6.2f ms  [from %s]", i, mod.name:sub(1, 32), mod.duration_ms, mod.caller)
      )
    end
  end
  table.insert(lines, "")

  -- Section 3: Runtime Autocommands & Jitter
  table.insert(lines, "  🔄 Runtime Autocommand Performance:")
  if #runtime.slow_autocmds == 0 then
    table.insert(lines, "     ✓ All autocommands executing smoothly with no lag spikes.")
  else
    for i = 1, math.min(5, #runtime.slow_autocmds) do
      local ac = runtime.slow_autocmds[i]
      table.insert(
        lines,
        string.format("     • %-36s avg %5.2f ms (max %5.2f ms, calls: %d)", ac.name:sub(1, 36), ac.avg_ms, ac.max_ms, ac.count)
      )
    end
  end
  table.insert(lines, "")

  -- Section 4: Optimization Advisor Highlights
  table.insert(lines, string.format("  💡 Optimization Advisor (%d Suggestions - press 'a' for details):", #recommendations))
  if #recommendations == 0 then
    table.insert(lines, "     ✓ System optimal! No actionable performance bottlenecks found.")
  else
    for i = 1, math.min(3, #recommendations) do
      local rec = recommendations[i]
      local badge = rec.level == "CRITICAL" and "[CRITICAL]" or (rec.level == "WARN" and "[WARN]" or "[OPT]")
      table.insert(lines, string.format("     %s %s", badge, rec.title))
      table.insert(lines, string.format("        ⤷ %s", rec.suggestion))
    end
  end
  table.insert(lines, "")

  -- Footer Controls
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "  [p] Plugins & Disable   [a] Advisor Rules   [w] Waterfall   [m] Run GC   [q] Close")

  return lines
end

---Build text lines for the Plugin Manager view
---@param width integer
---@return string[]
local function build_plugin_lines(width)
  local lines = {}
  line_plugin_map = {}
  local plugins = plugin_manager.list_plugins()

  table.insert(lines, "  🔌 Plugin Performance & On-Demand Manager")
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "  Press [x], [<Space>], or [<CR>] on any plugin to toggle Enable / Disable.")
  table.insert(lines, "  Disabled plugins are persisted to ~/.config/nvim/lua/plugins/perf_disabled.lua")
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "")

  for _, plug in ipairs(plugins) do
    local status_badge = plug.enabled and "[x] ACTIVE " or "[ ] DISABLED"
    local load_badge = plug.loaded and "(Loaded)" or "(Lazy/Idle)"
    local line = string.format("  %s  %-30s  %-12s  %s", status_badge, plug.name:sub(1, 30), load_badge, plug.repo)
    table.insert(lines, line)
    line_plugin_map[#lines] = plug.name
  end

  table.insert(lines, "")
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "  [d] Dashboard   [a] Advisor   [w] Waterfall   [r] Refresh   [q] Close")

  return lines
end

---Build text lines for the full Advisor view
---@param width integer
---@return string[]
local function build_advisor_lines(width)
  local lines = {}
  local recommendations = advisor_engine.generate_recommendations()

  table.insert(lines, "  💡 Performance Optimization Advisor & Best Practices")
  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, string.format("  Detected %d actionable optimization suggestions:", #recommendations))
  table.insert(lines, "")

  if #recommendations == 0 then
    table.insert(lines, "  ✓ All checks passed! Your Neovim configuration is fully optimized.")
  else
    for i, rec in ipairs(recommendations) do
      local badge = rec.level == "CRITICAL" and "🔴 [CRITICAL]"
        or (rec.level == "WARN" and "🟡 [WARNING]" or "🟢 [OPTIMIZE]")
      table.insert(lines, string.format("  %d. %s %s", i, badge, rec.title))
      table.insert(lines, string.format("     Description: %s", rec.description))
      table.insert(lines, string.format("     Suggestion:  %s", rec.suggestion))
      if rec.code_snippet then
        table.insert(lines, "     Code Example:")
        for snippet_line in rec.code_snippet:gmatch("[^\r\n]+") do
          table.insert(lines, string.format("       | %s", snippet_line))
        end
      end
      table.insert(lines, "")
    end
  end

  table.insert(lines, "  " .. string.rep("─", width - 6))
  table.insert(lines, "  [d] Dashboard   [p] Plugins & Disable   [w] Waterfall   [q] Close")

  return lines
end

---Render buffer contents and apply highlight decorations
local function render_content()
  if not active_buf or not vim.api.nvim_buf_is_valid(active_buf) then
    return
  end

  local width, _ = get_window_layout()
  local lines = {}

  if current_view == "waterfall" then
    lines = waterfall.render_lines(width - 4)
  elseif current_view == "plugins" then
    lines = build_plugin_lines(width)
  elseif current_view == "advisor" then
    lines = build_advisor_lines(width)
  else
    lines = build_dashboard_lines(width)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = active_buf })
  vim.api.nvim_buf_set_lines(active_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = active_buf })

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(active_buf, ns_id, 0, -1)

  -- Apply syntax decoration
  for i, line in ipairs(lines) do
    local line_idx = i - 1
    if line:match("^  ⚡") or line:match("^  🔌") or line:match("^  💡") or line:match("^╭───") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "Title", line_idx, 0, -1)
    elseif line:match("^  ⏱️") or line:match("^  🔄") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "Special", line_idx, 0, -1)
    elseif line:match("%[CRITICAL%]") or line:match("🔴") or line:match("🐌") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "DiagnosticError", line_idx, 0, -1)
    elseif line:match("%[WARN%]") or line:match("🟡") or line:match("⚠️") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "DiagnosticWarn", line_idx, 0, -1)
    elseif line:match("✓") or line:match("%[x%] ACTIVE") or line:match("🟢") or line:match("⚡ Ultra Fast") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "DiagnosticOk", line_idx, 0, -1)
    elseif line:match("%[ %] DISABLED") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "Comment", line_idx, 0, -1)
    elseif line:match("^  %[") then
      vim.api.nvim_buf_add_highlight(active_buf, ns_id, "Comment", line_idx, 0, -1)
    end
  end
end

---Toggle plugin on current line
local function toggle_current_line_plugin()
  if current_view ~= "plugins" then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(active_win)
  local line_num = cursor[1]
  local plugin_name = line_plugin_map[line_num]

  if not plugin_name then
    vim.notify("[PerfLens] No plugin on this line to toggle.", vim.log.levels.WARN)
    return
  end

  local new_state, msg = plugin_manager.toggle_plugin(plugin_name, true)
  render_content()
  vim.notify(string.format("[PerfLens] %s", msg), vim.log.levels.INFO)
end

---Attach buffer keybindings
local function setup_keymaps()
  local opts = { buffer = active_buf, silent = true, noremap = true }

  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)

  -- Navigation between views
  vim.keymap.set("n", "d", function()
    current_view = "dashboard"
    render_content()
  end, opts)

  vim.keymap.set("n", "p", function()
    current_view = "plugins"
    render_content()
  end, opts)

  vim.keymap.set("n", "a", function()
    current_view = "advisor"
    render_content()
  end, opts)

  vim.keymap.set("n", "w", function()
    current_view = "waterfall"
    render_content()
  end, opts)

  -- Plugin toggling
  vim.keymap.set("n", "x", toggle_current_line_plugin, opts)
  vim.keymap.set("n", "<Space>", toggle_current_line_plugin, opts)
  vim.keymap.set("n", "<CR>", toggle_current_line_plugin, opts)

  -- Utilities
  vim.keymap.set("n", "r", function()
    render_content()
    vim.notify("[PerfLens] Refreshed view.", vim.log.levels.INFO)
  end, opts)

  vim.keymap.set("n", "m", function()
    local res = memory.collect_and_measure()
    render_content()
    vim.notify(
      string.format("[PerfLens] Lua GC: Freed %.2f MB (Heap: %.2f MB)", res.freed_mb, res.after_mb),
      vim.log.levels.INFO
    )
  end, opts)
end

---Open or toggle the performance dashboard
---@param initial_view? "dashboard"|"plugins"|"advisor"|"waterfall"
function M.toggle(initial_view)
  if active_win and vim.api.nvim_win_is_valid(active_win) then
    if initial_view and initial_view ~= current_view then
      current_view = initial_view
      render_content()
      return
    end
    M.close()
    return
  end

  current_view = initial_view or "dashboard"

  active_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = active_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = active_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = active_buf })
  vim.api.nvim_set_option_value("filetype", "perf_lens", { buf = active_buf })

  local width, height, row, col = get_window_layout()

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.options.ui.border or "rounded",
    title = " 🚀 Neovim Performance Lens ",
    title_pos = "center",
  }

  active_win = vim.api.nvim_open_win(active_buf, true, win_opts)
  vim.api.nvim_set_option_value("cursorline", true, { win = active_win })

  setup_keymaps()
  render_content()
end

---Close the dashboard window
function M.close()
  if active_win and vim.api.nvim_win_is_valid(active_win) then
    vim.api.nvim_win_close(active_win, true)
    active_win = nil
  end
  active_buf = nil
  line_plugin_map = {}
end

return M
