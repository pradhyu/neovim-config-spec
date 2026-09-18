local profiler = require("perf_lens.core.profiler")
local config = require("perf_lens.config")

local M = {}

local original_require = _G.require
local current_depth = 0
local hooked = false
local in_hook = false

---Extract basename from a file path using pure Lua pattern
---@param path string
---@return string
local function get_basename(path)
  if not path then
    return "unknown"
  end
  return path:match("[/\\]([^/\\]+)$") or path
end

---Get caller name/file from debug trace using pure Lua
---@return string
local function get_caller_info()
  local info = debug.getinfo(4, "Sl")
  if info and info.short_src then
    local src = info.short_src
    local line = info.currentline or 0
    return string.format("%s:%d", get_basename(src), line)
  end
  return "unknown"
end

---Enable the require tracing hook
function M.enable()
  if hooked then
    return
  end
  hooked = true

  _G.require = function(modname)
    -- If already cached in package.loaded or currently inside tracing logic, skip profiling overhead
    if package.loaded[modname] ~= nil or in_hook then
      return original_require(modname)
    end

    in_hook = true
    current_depth = current_depth + 1
    local caller = get_caller_info()
    local t0 = profiler.now()

    local ok, res = pcall(original_require, modname)

    local delta_ms = profiler.elapsed_ms(t0)
    current_depth = current_depth - 1
    in_hook = false

    profiler.record_module(modname, delta_ms, caller, current_depth)

    if not ok then
      error(res, 2)
    end

    return res
  end
end

---Disable require tracing hook and restore original require
function M.disable()
  if not hooked then
    return
  end
  _G.require = original_require
  hooked = false
end

---Check if hook is active
---@return boolean
function M.is_active()
  return hooked
end

return M
