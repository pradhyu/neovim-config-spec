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

---Close all unmodified buffers
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
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d unmodified buffer(s)", closed), vim.log.levels.INFO)
  return closed
end

---Close all hidden buffers (not visible in any window)
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
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d hidden buffer(s)", closed), vim.log.levels.INFO)
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
  vim.notify(string.format("[BufferBuddy] 🧹 Closed %d other buffer(s)", closed), vim.log.levels.INFO)
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

return M
