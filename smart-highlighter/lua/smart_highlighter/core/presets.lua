local engine = require("smart_highlighter.core.engine")

local M = {}

M.PRESETS = {
  logs = {
    name = "Log Analysis & Diagnostics",
    patterns = {
      { pattern = [[\c\<ERROR\>\|\<FATAL\>\|\<CRITICAL\>\|\<SEVERE\>]], is_regex = true, name = "Errors", slot = 13 },
      { pattern = [[\c\<WARN\>\|\<WARNING\>]], is_regex = true, name = "Warnings", slot = 3 },
      { pattern = [[\c\<INFO\>]], is_regex = true, name = "Info", slot = 4 },
      { pattern = [[\c\<DEBUG\>]], is_regex = true, name = "Debug", slot = 6 },
      { pattern = [[\c\<TRACE\>]], is_regex = true, name = "Trace", slot = 5 },
      { pattern = [[\<[0-9a-fA-F]\{8}-[0-9a-fA-F]\{4}-[0-9a-fA-F]\{4}-[0-9a-fA-F]\{4}-[0-9a-fA-F]\{12}\>]], is_regex = true, name = "UUID", slot = 8 },
      { pattern = [[\<[0-9]\{1,3}\.[0-9]\{1,3}\.[0-9]\{1,3}\.[0-9]\{1,3}\>]], is_regex = true, name = "IP Address", slot = 9 },
      { pattern = [[\d\{4}-\d\{2}-\d\{2}T\d\{2}:\d\{2}:\d\{2}]], is_regex = true, name = "Timestamp", slot = 12 },
    },
  },
  http = {
    name = "HTTP / REST API",
    patterns = {
      { pattern = [[\<GET\>]], is_regex = true, name = "GET", slot = 2 },
      { pattern = [[\<POST\>]], is_regex = true, name = "POST", slot = 4 },
      { pattern = [[\<PUT\>\|\<PATCH\>]], is_regex = true, name = "PUT/PATCH", slot = 7 },
      { pattern = [[\<DELETE\>]], is_regex = true, name = "DELETE", slot = 1 },
      { pattern = [[\<20[0-9]\>]], is_regex = true, name = "2xx Success", slot = 10 },
      { pattern = [[\<40[0-9]\>]], is_regex = true, name = "4xx Client Error", slot = 14 },
      { pattern = [[\<50[0-9]\>]], is_regex = true, name = "5xx Server Error", slot = 13 },
    },
  },
  sql = {
    name = "SQL Queries & Databases",
    patterns = {
      { pattern = [[\c\<SELECT\>]], is_regex = true, name = "SELECT", slot = 4 },
      { pattern = [[\c\<FROM\>\|\<JOIN\>\|\<LEFT JOIN\>\|\<INNER JOIN\>]], is_regex = true, name = "FROM/JOIN", slot = 6 },
      { pattern = [[\c\<WHERE\>\|\<HAVING\>]], is_regex = true, name = "WHERE", slot = 3 },
      { pattern = [[\c\<INSERT\>\|\<UPDATE\>\|\<DELETE\>]], is_regex = true, name = "MUTATION", slot = 1 },
      { pattern = [[\c\<GROUP BY\>\|\<ORDER BY\>\|\<LIMIT\>]], is_regex = true, name = "CLAUSE", slot = 5 },
    },
  },
  json = {
    name = "JSON Data",
    patterns = {
      { pattern = [[\<true\>\|\<false\>]], is_regex = true, name = "Booleans", slot = 2 },
      { pattern = [[\<null\>]], is_regex = true, name = "Null", slot = 14 },
      { pattern = [["[^"]\+":]], is_regex = true, name = "Object Keys", slot = 6 },
    },
  },
  devops = {
    name = "DevOps & Containers",
    patterns = {
      { pattern = [[\c\<Running\>\|\<Active\>\|\<Ready\>\|\<Healthy\>]], is_regex = true, name = "Healthy/Running", slot = 2 },
      { pattern = [[\c\<Failed\>\|\<Error\>\|\<CrashLoopBackOff\>\|\<Unhealthy\>]], is_regex = true, name = "Failure", slot = 1 },
      { pattern = [[\c\<Pending\>\|\<ContainerCreating\>\|\<Terminating\>]], is_regex = true, name = "In Progress", slot = 3 },
    },
  },
}

---Load a specific preset by name
---@param name string
---@param clear_existing? boolean
---@return boolean, string
function M.load_preset(name, clear_existing)
  local preset = M.PRESETS[name:lower()]
  if not preset then
    return false, string.format("Unknown preset '%s'", name)
  end

  if clear_existing ~= false then
    engine.clear_all()
  end

  for _, item in ipairs(preset.patterns) do
    engine.add_slot(item.pattern, {
      id = item.slot,
      is_regex = item.is_regex or false,
      whole_word = false,
      name = item.name or item.pattern,
      scope = "global",
    })
  end

  return true, string.format("Loaded preset '%s' (%d patterns)", preset.name, #preset.patterns)
end

---Interactive preset selector
function M.select_preset_interactive()
  local items = {}
  for key, val in pairs(M.PRESETS) do
    table.insert(items, {
      id = key,
      label = string.format("%-10s - %s (%d patterns)", key:upper(), val.name, #val.patterns),
    })
  end

  table.sort(items, function(a, b) return a.id < b.id end)

  vim.ui.select(items, {
    prompt = "Select SmartHighlight Preset:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    local ok, msg = M.load_preset(choice.id, true)
    if ok then
      vim.notify("[SmartHighlight] 🎨 " .. msg, vim.log.levels.INFO)
    else
      vim.notify("[SmartHighlight] " .. msg, vim.log.levels.WARN)
    end
  end)
end

return M
