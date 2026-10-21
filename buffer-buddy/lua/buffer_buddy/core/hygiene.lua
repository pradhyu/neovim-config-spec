local pin = require("buffer_buddy.core.pin")
local config = require("buffer_buddy.config")

local M = {}

---Check if a buffer is currently visible in any window in any tabpage
---@param buf integer
---@return boolean
function M.is_buffer_visible(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

---Check if a buffer is currently visible in any window within a specific tabpage
---@param buf integer
---@param tab? integer
---@return boolean
function M.is_buffer_visible_in_tab(buf, tab)
  local t = tab or vim.api.nvim_get_current_tabpage()
  if not vim.api.nvim_tabpage_is_valid(t) then
    return false
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

---Safely delete a buffer while preserving window layouts
---@param buf integer
---@param force? boolean
---@return boolean
function M.close_buffer_safely(buf, force)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if not force and config.options.protect_pinned and pin.is_pinned(buf) then
    return false
  end

  -- If buffer is displayed in any window, switch window to alternate/previous buffer first
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
        vim.api.nvim_win_set_buf(win, alt)
      else
        local found_other = false
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= buf and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
            vim.api.nvim_win_set_buf(win, b)
            found_other = true
            break
          end
        end
        if not found_other then
          -- Create fresh empty scratch buffer
          local new_b = vim.api.nvim_create_buf(true, false)
          vim.api.nvim_win_set_buf(win, new_b)
        end
      end
    end
  end

  local ok, _ = pcall(vim.api.nvim_buf_delete, buf, { force = force or false })
  return ok
end

-- =============================================================================
-- Global Sweepers (All Tabs)
-- =============================================================================

---Close all unmodified buffers across entire session
---@return integer closed_count
function M.close_unmodified()
  local closed = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not vim.bo[buf].modified and vim.bo[buf].buftype ~= "terminal" then
        if not (config.options.protect_pinned and pin.is_pinned(buf)) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        end
      end
    end
  end
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d unmodified buffer(s) across all tabs", closed), vim.log.levels.INFO)
  return closed
end

---Close all hidden buffers (not visible in any window in any tab)
---@return integer closed_count
function M.close_hidden()
  local closed = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not M.is_buffer_visible(buf) and not vim.bo[buf].modified then
        if not (config.options.protect_pinned and pin.is_pinned(buf)) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        end
      end
    end
  end
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d hidden buffer(s) across all tabs", closed), vim.log.levels.INFO)
  return closed
end

---Close all buffers except the active one
---@return integer closed_count
function M.close_others()
  local current = vim.api.nvim_get_current_buf()
  local closed = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not vim.bo[buf].modified then
        if not (config.options.protect_pinned and pin.is_pinned(buf)) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        end
      end
    end
  end
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d other buffer(s) across all tabs", closed), vim.log.levels.INFO)
  return closed
end

---Close dead / orphaned buffers (files that were deleted from disk)
---@return integer closed_count
function M.close_dead()
  local closed = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.filereadable(name) == 0 and not vim.bo[buf].modified then
        if M.close_buffer_safely(buf, true) then
          closed = closed + 1
        end
      end
    end
  end
  vim.notify(string.format("[BufferBuddy] 🧹 Cleaned %d orphaned/deleted buffer(s)", closed), vim.log.levels.INFO)
  return closed
end

-- =============================================================================
-- Tab-Scoped Sweepers (Workspace-Isolated)
-- =============================================================================

---Close unmodified buffers belonging to the specified tab workspace
---@param tab? integer
---@return integer closed_count
function M.close_tab_unmodified(tab)
  local tabs = require("buffer_buddy.core.tabs")
  local t = tab or vim.api.nvim_get_current_tabpage()
  local bufs = tabs.get_tab_buffers(t)
  local tab_num = vim.api.nvim_tabpage_get_number(t)
  local tab_name = tabs.get_tab_name(t)
  local closed = 0

  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified and vim.bo[buf].buftype ~= "terminal" then
      if not (config.options.protect_pinned and pin.is_pinned(buf)) then
        if tabs.is_buffer_exclusive_to_tab(buf, t) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        else
          -- Shared with another tab: just remove from this tab's workspace
          tabs.remove_buffer_from_tab(buf, t)
          closed = closed + 1
        end
      end
    end
  end

  tabs.sync_tab_scoping()
  vim.notify(string.format("[BufferBuddy] 🧹 Tab %d [%s]: Cleaned %d unmodified buffer(s)", tab_num, tab_name, closed), vim.log.levels.INFO)
  return closed
end

---Close buffers not currently visible in any window of the specified tab workspace
---@param tab? integer
---@return integer closed_count
function M.close_tab_hidden(tab)
  local tabs = require("buffer_buddy.core.tabs")
  local t = tab or vim.api.nvim_get_current_tabpage()
  local bufs = tabs.get_tab_buffers(t)
  local tab_num = vim.api.nvim_tabpage_get_number(t)
  local tab_name = tabs.get_tab_name(t)
  local closed = 0

  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) and not M.is_buffer_visible_in_tab(buf, t) and not vim.bo[buf].modified then
      if not (config.options.protect_pinned and pin.is_pinned(buf)) then
        if tabs.is_buffer_exclusive_to_tab(buf, t) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        else
          tabs.remove_buffer_from_tab(buf, t)
          closed = closed + 1
        end
      end
    end
  end

  tabs.sync_tab_scoping()
  vim.notify(string.format("[BufferBuddy] 🧹 Tab %d [%s]: Cleaned %d hidden buffer(s)", tab_num, tab_name, closed), vim.log.levels.INFO)
  return closed
end

---Close other buffers in current tab except the active one
---@param tab? integer
---@return integer closed_count
function M.close_tab_others(tab)
  local tabs = require("buffer_buddy.core.tabs")
  local t = tab or vim.api.nvim_get_current_tabpage()
  local bufs = tabs.get_tab_buffers(t)
  local current = vim.api.nvim_get_current_buf()
  local tab_num = vim.api.nvim_tabpage_get_number(t)
  local tab_name = tabs.get_tab_name(t)
  local closed = 0

  for _, buf in ipairs(bufs) do
    if buf ~= current and vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
      if not (config.options.protect_pinned and pin.is_pinned(buf)) then
        if tabs.is_buffer_exclusive_to_tab(buf, t) then
          if M.close_buffer_safely(buf, false) then
            closed = closed + 1
          end
        else
          tabs.remove_buffer_from_tab(buf, t)
          closed = closed + 1
        end
      end
    end
  end

  tabs.sync_tab_scoping()
  vim.notify(string.format("[BufferBuddy] 🧹 Tab %d [%s]: Closed %d other buffer(s)", tab_num, tab_name, closed), vim.log.levels.INFO)
  return closed
end

return M
