local M = {}

---Diff current buffer against the saved file on disk
---@param buf? integer
function M.diff_disk(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(target_buf)

  if file_path == "" or vim.fn.filereadable(file_path) == 0 then
    vim.notify("[BufferBuddy] Current buffer has no corresponding file on disk", vim.log.levels.WARN)
    return
  end

  if not vim.bo[target_buf].modified then
    vim.notify("[BufferBuddy] Buffer has no unsaved modifications compared to disk", vim.log.levels.INFO)
    return
  end

  local ft = vim.bo[target_buf].filetype
  -- Read original disk file contents
  local disk_lines = vim.fn.readfile(file_path)

  -- Create scratch buffer for disk version
  local disk_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[disk_buf].buftype = "nofile"
  vim.bo[disk_buf].bufhidden = "wipe"
  vim.bo[disk_buf].swapfile = false
  vim.bo[disk_buf].filetype = ft
  vim.api.nvim_buf_set_name(disk_buf, "[Disk: " .. vim.fn.fnamemodify(file_path, ":t") .. "]")
  vim.api.nvim_buf_set_lines(disk_buf, 0, -1, false, disk_lines)
  vim.bo[disk_buf].modifiable = false

  -- Open vertical split
  vim.cmd("vertical diffsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, disk_buf)

  vim.notify("[BufferBuddy] 🔀 Diffing buffer against disk version (Close with :bd or :diffoff)", vim.log.levels.INFO)
end

---Diff current buffer against system clipboard
---@param buf? integer
function M.diff_clipboard(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local clipboard_content = vim.fn.getreg("+")

  if not clipboard_content or clipboard_content == "" then
    clipboard_content = vim.fn.getreg('"')
  end

  if not clipboard_content or clipboard_content == "" then
    vim.notify("[BufferBuddy] Clipboard is empty", vim.log.levels.WARN)
    return
  end

  local clip_lines = vim.split(clipboard_content, "\n")
  local ft = vim.bo[target_buf].filetype

  -- Create scratch buffer for clipboard
  local clip_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[clip_buf].buftype = "nofile"
  vim.bo[clip_buf].bufhidden = "wipe"
  vim.bo[clip_buf].swapfile = false
  vim.bo[clip_buf].filetype = ft
  vim.api.nvim_buf_set_name(clip_buf, "[Clipboard Diff]")
  vim.api.nvim_buf_set_lines(clip_buf, 0, -1, false, clip_lines)
  vim.bo[clip_buf].modifiable = false

  -- Turn diff on in current window and open split
  vim.cmd("diffthis")
  vim.cmd("vertical split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, clip_buf)
  vim.cmd("diffthis")

  vim.notify("[BufferBuddy] 🔀 Diffing buffer against clipboard", vim.log.levels.INFO)
end

return M
