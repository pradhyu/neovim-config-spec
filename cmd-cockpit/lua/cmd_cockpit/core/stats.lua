local config = require("cmd_cockpit.config")

local M = {}

---@class CmdRecord
---@field cmd string
---@field count integer
---@field last_used integer
---@field pinned boolean
---@field kind? "cmd"|"keymap"
---@field keys? string

---@type table<string, CmdRecord>
M.records = {}

---Get storage file path
---@return string
local function get_history_file()
  local dir = config.options.storage_dir or (vim.fn.stdpath("state") .. "/cmd-cockpit")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir .. "/history.json"
end

---Calculate Frecency score (Frequency + Recency)
---@param record CmdRecord
---@return number
function M.calculate_frecency(record)
  local now = os.time()
  local delta_seconds = math.max(0, now - (record.last_used or 0))

  -- Recency boost:
  -- Used in last 10 minutes: +50 bonus (jumps directly to top)
  -- Used in last hour: +20 bonus
  -- Used in last 24h: +5 bonus
  local recency_boost = 0
  if delta_seconds < 600 then
    recency_boost = 50
  elseif delta_seconds < 3600 then
    recency_boost = 20
  elseif delta_seconds < 86400 then
    recency_boost = 5
  end

  local pin_bonus = record.pinned and 1000 or 0
  return (record.count * 2) + recency_boost + pin_bonus
end

---Record execution of a command or keymap
---@param cmd string
---@param kind? "cmd"|"keymap"
---@param raw_keys? string
function M.record_command(cmd, kind, raw_keys)
  local trimmed = vim.trim(cmd)
  if trimmed == "" then
    return
  end

  -- Check if ignored
  for _, pat in ipairs(config.options.ignore_patterns or {}) do
    if trimmed:match(pat) then
      return
    end
  end

  local rec = M.records[trimmed]
  if rec then
    rec.count = rec.count + 1
    rec.last_used = os.time()
    rec.kind = kind or rec.kind or "cmd"
    rec.keys = raw_keys or rec.keys
  else
    M.records[trimmed] = {
      cmd = trimmed,
      count = 1,
      last_used = os.time(),
      pinned = false,
      kind = kind or "cmd",
      keys = raw_keys,
    }
  end

  M.save()
end

---Toggle pin status for a command
---@param cmd string
---@return boolean
function M.toggle_pin(cmd)
  local rec = M.records[cmd]
  if rec then
    rec.pinned = not rec.pinned
    M.save()
    return rec.pinned
  end
  return false
end

---Get top ranked commands sorted by frecency
---@param limit? integer
---@return CmdRecord[]
function M.get_top_commands(limit)
  local list = {}
  for _, rec in pairs(M.records) do
    table.insert(list, rec)
  end

  table.sort(list, function(a, b)
    local score_a = M.calculate_frecency(a)
    local score_b = M.calculate_frecency(b)
    if score_a ~= score_b then
      return score_a > score_b
    end
    return a.last_used > b.last_used
  end)

  local max_items = limit or 20
  local results = {}
  for i = 1, math.min(#list, max_items) do
    table.insert(results, list[i])
  end
  return results
end

---Save history to disk
function M.save()
  local file = get_history_file()
  local encoded = vim.fn.json_encode(M.records)
  local f = io.open(file, "w")
  if f then
    f:write(encoded)
    f:close()
  end
end

---Load history from disk
function M.load()
  local file = get_history_file()
  local f = io.open(file, "r")
  if not f then
    return
  end
  local content = f:read("*a")
  f:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then
      M.records = data
    end
  end
end

return M
