local config = require("super_keychord.config")

local M = {}

---@class UsageRecord
---@field count integer Number of times used
---@field last_used integer Unix timestamp
---@field from_search? boolean Whether it was executed from the keychord search picker

---@type table<string, UsageRecord>
M.stats = {}

---Get path to persistent stats JSON file
---@return string
local function get_stats_file()
  local dir = config.options.storage_dir or (vim.fn.stdpath("state") .. "/super-keychord")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir .. "/usage.json"
end

---Record usage of a keychord
---@param chord_key string Typically the display_lhs or raw_lhs (e.g. "<leader>e")
---@param from_search? boolean
function M.record_usage(chord_key, from_search)
  if not chord_key or chord_key == "" then return end

  local rec = M.stats[chord_key]
  if not rec then
    rec = {
      count = 0,
      last_used = os.time(),
      from_search = from_search or false,
    }
    M.stats[chord_key] = rec
  end

  rec.count = rec.count + 1
  rec.last_used = os.time()
  if from_search then
    rec.from_search = true
  end

  M.save()
end

---Get usage record for a chord
---@param chord_key string
---@return UsageRecord|nil
function M.get_record(chord_key)
  return M.stats[chord_key]
end

---Calculate a frecency / priority score for an entry
---Higher score means it appears higher at the top
---@param chord_key string
---@param raw_lhs string
---@return number score, integer count, boolean is_frequent
function M.get_frecency_score(chord_key, raw_lhs)
  local rec = M.stats[chord_key] or M.stats[raw_lhs]
  if not rec or rec.count <= 0 then
    return 0, 0, false
  end

  local now = os.time()
  local age_seconds = math.max(0, now - (rec.last_used or 0))

  -- Recency multiplier:
  -- Used in last 15 min: +100
  -- Used in last 2 hours: +50
  -- Used in last 24 hours: +20
  -- Used in last 7 days: +10
  local recency_boost = 0
  if age_seconds < 900 then
    recency_boost = 100
  elseif age_seconds < 7200 then
    recency_boost = 50
  elseif age_seconds < 86400 then
    recency_boost = 20
  elseif age_seconds < 604800 then
    recency_boost = 10
  end

  -- Search boost: if user specifically selected it via search, give small bonus
  local search_boost = rec.from_search and 15 or 0

  local score = (rec.count * 10) + recency_boost + search_boost
  return score, rec.count, true
end

---Save stats to disk
function M.save()
  local file = get_stats_file()
  local encoded = vim.fn.json_encode(M.stats)
  local f = io.open(file, "w")
  if f then
    f:write(encoded)
    f:close()
  end
end

---Load stats from disk
function M.load()
  local file = get_stats_file()
  local f = io.open(file, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then
      M.stats = data
    end
  end
end

return M
