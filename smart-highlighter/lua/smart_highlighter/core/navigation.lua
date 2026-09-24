local engine = require("smart_highlighter.core.engine")

local M = {}

---Find the slot corresponding to word under cursor
---@return integer?, table?
function M.get_current_slot()
  local cword = vim.fn.expand("<cword>")
  if cword and cword ~= "" then
    local id, slot = engine.find_slot_by_pattern(cword)
    if id then
      return id, slot
    end
  end

  -- Fallback: check cursor position against extmark highlights
  local cur = vim.api.nvim_win_get_cursor(0)
  local row = cur[1] - 1
  local col = cur[2]

  local extmarks = vim.api.nvim_buf_get_extmarks(0, engine.ns_id, { row, 0 }, { row, -1 }, { details = true })
  for _, mark in ipairs(extmarks) do
    local m_col = mark[3]
    local details = mark[4] or {}
    local end_col = details.end_col or m_col
    if col >= m_col and col <= end_col then
      local hl_group = details.hl_group or ""
      local slot_id = tonumber(hl_group:match("SmartHighlightSlot(%d+)"))
      if slot_id and engine.slots[slot_id] then
        return slot_id, engine.slots[slot_id]
      end
    end
  end

  return nil, nil
end

---Jump to next or previous match of a specific slot
---@param slot_id integer
---@param forward boolean
function M.jump_slot(slot_id, forward)
  local matches = engine.get_matches(slot_id, 0)
  if #matches == 0 then
    vim.notify(string.format("[SmartHighlight] No matches for slot #%d", slot_id), vim.log.levels.WARN)
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_row = cur[1]
  local cur_col = cur[2]

  local target = nil
  if forward then
    -- Find first match after current position
    for _, m in ipairs(matches) do
      if m.row > cur_row or (m.row == cur_row and m.col > cur_col) then
        target = m
        break
      end
    end
    -- Wrap around to first match
    if not target then
      target = matches[1]
    end
  else
    -- Find last match before current position
    for i = #matches, 1, -1 do
      local m = matches[i]
      if m.row < cur_row or (m.row == cur_row and m.col < cur_col) then
        target = m
        break
      end
    end
    -- Wrap around to last match
    if not target then
      target = matches[#matches]
    end
  end

  if target then
    vim.api.nvim_win_set_cursor(0, { target.row, target.col })
    local current_idx = 1
    for idx, m in ipairs(matches) do
      if m.row == target.row and m.col == target.col then
        current_idx = idx
        break
      end
    end
    vim.notify(string.format("[SmartHighlight #%d] [%d/%d] %s", slot_id, current_idx, #matches, target.text), vim.log.levels.INFO)
  end
end

---Jump to next match of current slot
function M.jump_next()
  local slot_id, _ = M.get_current_slot()
  if not slot_id then
    -- If not on a highlighted word, jump across all highlights
    M.jump_any(true)
    return
  end
  M.jump_slot(slot_id, true)
end

---Jump to prev match of current slot
function M.jump_prev()
  local slot_id, _ = M.get_current_slot()
  if not slot_id then
    M.jump_any(false)
    return
  end
  M.jump_slot(slot_id, false)
end

---Jump to next or previous match across ALL active slots
---@param forward boolean
function M.jump_any(forward)
  local all_matches = {}
  for id, slot in pairs(engine.slots) do
    if slot.enabled then
      local slot_matches = engine.get_matches(id, 0)
      for _, m in ipairs(slot_matches) do
        m.slot_id = id
        table.insert(all_matches, m)
      end
    end
  end

  if #all_matches == 0 then
    vim.notify("[SmartHighlight] No active highlighted matches found in buffer", vim.log.levels.WARN)
    return
  end

  -- Sort all matches by document position (row, then col)
  table.sort(all_matches, function(a, b)
    if a.row ~= b.row then
      return a.row < b.row
    end
    return a.col < b.col
  end)

  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_row = cur[1]
  local cur_col = cur[2]

  local target = nil
  if forward then
    for _, m in ipairs(all_matches) do
      if m.row > cur_row or (m.row == cur_row and m.col > cur_col) then
        target = m
        break
      end
    end
    if not target then
      target = all_matches[1]
    end
  else
    for i = #all_matches, 1, -1 do
      local m = all_matches[i]
      if m.row < cur_row or (m.row == cur_row and m.col < cur_col) then
        target = m
        break
      end
    end
    if not target then
      target = all_matches[#all_matches]
    end
  end

  if target then
    vim.api.nvim_win_set_cursor(0, { target.row, target.col })
    local current_idx = 1
    for idx, m in ipairs(all_matches) do
      if m.row == target.row and m.col == target.col then
        current_idx = idx
        break
      end
    end
    vim.notify(string.format("[SmartHighlight (All)] [%d/%d] Slot #%d: '%s'", current_idx, #all_matches, target.slot_id, target.text), vim.log.levels.INFO)
  end
end

return M
