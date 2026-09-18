-- Automatic command registration for perf_lens.nvim
local perf_lens = require("perf_lens")
local plugin_manager = require("perf_lens.core.plugin_manager")

vim.api.nvim_create_user_command("PerfLens", function(opts)
  local fargs = opts.fargs or {}
  local cmd = fargs[1] and fargs[1]:lower() or "dashboard"

  if cmd == "waterfall" or cmd == "timeline" then
    perf_lens.toggle_dashboard("waterfall")
  elseif cmd == "advisor" or cmd == "advise" then
    perf_lens.toggle_dashboard("advisor")
  elseif cmd == "plugins" or cmd == "toggle" then
    perf_lens.toggle_dashboard("plugins")
  elseif cmd == "disable" then
    local plug_name = fargs[2]
    if not plug_name then
      vim.notify("[PerfLens] Usage: :PerfLens disable <plugin_name>", vim.log.levels.WARN)
      return
    end
    local _, msg = plugin_manager.disable_plugin(plug_name, true)
    vim.notify(string.format("[PerfLens] %s", msg), vim.log.levels.INFO)
  elseif cmd == "enable" then
    local plug_name = fargs[2]
    if not plug_name then
      vim.notify("[PerfLens] Usage: :PerfLens enable <plugin_name>", vim.log.levels.WARN)
      return
    end
    local _, msg = plugin_manager.enable_plugin(plug_name, true)
    vim.notify(string.format("[PerfLens] %s", msg), vim.log.levels.INFO)
  elseif cmd == "gc" or cmd == "memory" then
    local res = perf_lens.run_gc()
    vim.notify(
      string.format("[PerfLens] Lua GC Completed: Freed %.2f MB (Heap: %.2f MB)", res.freed_mb, res.after_mb),
      vim.log.levels.INFO
    )
  elseif cmd == "export" then
    local path = fargs[2]
    perf_lens.export_report(path)
  else
    perf_lens.toggle_dashboard("dashboard")
  end
end, {
  nargs = "*",
  complete = function(_, line)
    local subcommands = { "dashboard", "plugins", "advisor", "waterfall", "timeline", "disable", "enable", "memory", "gc", "export" }
    local args = vim.split(vim.trim(line), "%s+")

    if #args <= 2 and not line:match("%s+$") then
      local input = args[2] or ""
      local matches = {}
      for _, item in ipairs(subcommands) do
        if vim.startswith(item, input) then
          table.insert(matches, item)
        end
      end
      return matches
    elseif #args == 2 and line:match("%s+$") or #args >= 3 then
      local subcmd = args[2]:lower()
      if subcmd == "disable" or subcmd == "enable" then
        local input = args[3] or ""
        local matches = {}
        for _, plug in ipairs(plugin_manager.list_plugins()) do
          if vim.startswith(plug.name, input) then
            table.insert(matches, plug.name)
          end
        end
        return matches
      end
    end

    return {}
  end,
  desc = "Neovim Performance Lens & Optimization Center",
})
