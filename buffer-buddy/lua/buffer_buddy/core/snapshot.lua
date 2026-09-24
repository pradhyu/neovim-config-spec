local config = require("buffer_buddy.config")

local M = {}

---@class BufferSnapshot
---@field id integer
---@field name string
---@field time string
---@field lines string[]
---@field cursor integer[]

---@type table<integer, BufferSnapshot[]>
M.snapshots = {}

---Create a new named snapshot checkpoint for a buffer
---@param name? string
---@param buf? integer
---@return string
function M.create_snapshot(name, buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return "Invalid buffer"
  end

  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local time_str = os.date("%H:%M:%S")
  local snap_name = name or string.format("Snapshot @ %s", time_str)

  M.snapshots[target_buf] = M.snapshots[target_buf] or {}
  local list = M.snapshots[target_buf]

  local snap = {
    id = #list + 1,
    name = snap_name,
    time = time_str,
    lines = lines,
    cursor = cursor,
  }

  table.insert(list, 1, snap) -- newest first

  local max_snaps = config.options.max_snapshots_per_buffer or 10
  while #list > max_snaps do
    table.remove(list)
  end

  vim.notify(string.format("[BufferBuddy] 📸 Checkpoint created: '%s' (%d lines)", snap_name, #lines), vim.log.levels.INFO)
  return snap_name
end

---Get all snapshots for a buffer
---@param buf? integer
---@return BufferSnapshot[]
function M.get_snapshots(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  return M.snapshots[target_buf] or {}
end

---Restore buffer to a snapshot
---@param index? integer (1 = newest)
---@param buf? integer
---@return boolean, string
function M.restore_snapshot(index, buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local list = M.get_snapshots(target_buf)
  if #list == 0 then
    return false, "No snapshots available for this buffer"
  end

  local snap_idx = index or 1
  local snap = list[snap_idx]
  if not snap then
    return false, string.format("Snapshot index %d not found", snap_idx)
  end

  vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, snap.lines)
  pcall(vim.api.nvim_win_set_cursor, 0, snap.cursor)
  vim.notify(string.format("[BufferBuddy] ⏪ Reverted to snapshot '%s' (%s)", snap.name, snap.time), vim.log.levels.INFO)
  return true, "Restored snapshot"
end

---Interactive snapshot selector
---@param buf? integer
function M.select_snapshot_interactive(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local list = M.get_snapshots(target_buf)

  if #list == 0 then
    vim.notify("[BufferBuddy] No snapshots created for this buffer yet (use :BufferSnapshot)", vim.log.levels.WARN)
    return
  end

  local items = {}
  for idx, snap in ipairs(list) do
    table.insert(items, {
      idx = idx,
      label = string.format("[%d] %s (%s, %d lines)", idx, snap.name, snap.time, #snap.lines),
    })
  end

  vim.ui.select(items, {
    prompt = "Select Snapshot to Revert:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    M.restore_snapshot(choice.idx, target_buf)
  end)
end

return M
