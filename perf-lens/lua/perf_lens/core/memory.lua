local M = {}

---Get current Lua memory in Kilobytes and Megabytes
---@return { kb: number, mb: number, formatted: string }
function M.get_memory_usage()
  local kb = collectgarbage("count")
  local mb = kb / 1024
  return {
    kb = kb,
    mb = mb,
    formatted = string.format("%.2f MB", mb),
  }
end

---Run a garbage collection cycle and return freed memory
---@return { before_mb: number, after_mb: number, freed_mb: number }
function M.collect_and_measure()
  local before_kb = collectgarbage("count")
  collectgarbage("collect")
  local after_kb = collectgarbage("count")
  local freed_kb = math.max(0, before_kb - after_kb)

  return {
    before_mb = before_kb / 1024,
    after_mb = after_kb / 1024,
    freed_mb = freed_kb / 1024,
  }
end

---Count loaded Lua modules in package.loaded
---@return { total_loaded: number, user_packages: number }
function M.count_loaded_packages()
  local total = 0
  local user = 0
  for name, _ in pairs(package.loaded) do
    total = total + 1
    if not name:match("^_") and not name:match("^vim%.") and not name:match("^table$") and not name:match("^string$") then
      user = user + 1
    end
  end
  return {
    total_loaded = total,
    user_packages = user,
  }
end

return M
