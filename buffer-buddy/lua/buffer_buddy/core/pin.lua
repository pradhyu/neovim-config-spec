local M = {}

---Check if a buffer is pinned
---@param buf? integer
---@return boolean
function M.is_pinned(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return false
  end
  return vim.b[target_buf].buffer_buddy_pinned == true
      or vim.b[target_buf].bufferline_pinned == true
      or vim.b[target_buf].pinned == true
end

---Pin a buffer to protect it from automated closing
---@param buf? integer
function M.pin(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(target_buf) then
    vim.b[target_buf].buffer_buddy_pinned = true
    local name = vim.api.nvim_buf_get_name(target_buf)
    local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or string.format("Buf #%d", target_buf)
    vim.notify(string.format("[BufferBuddy] 📌 Pinned buffer '%s'", short), vim.log.levels.INFO)
  end
end

---Unpin a buffer
---@param buf? integer
function M.unpin(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(target_buf) then
    vim.b[target_buf].buffer_buddy_pinned = false
    local name = vim.api.nvim_buf_get_name(target_buf)
    local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or string.format("Buf #%d", target_buf)
    vim.notify(string.format("[BufferBuddy] 🔓 Unpinned buffer '%s'", short), vim.log.levels.INFO)
  end
end

---Toggle pin status for a buffer
---@param buf? integer
---@return boolean new_status
function M.toggle_pin(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if M.is_pinned(target_buf) then
    M.unpin(target_buf)
    return false
  else
    M.pin(target_buf)
    return true
  end
end

---Get list of all currently pinned buffers
---@return integer[]
function M.get_pinned_buffers()
  local pinned = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and M.is_pinned(buf) then
      table.insert(pinned, buf)
    end
  end
  return pinned
end

return M
