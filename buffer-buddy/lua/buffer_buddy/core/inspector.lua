local pin = require("buffer_buddy.core.pin")

local M = {}

---Format bytes into human-readable string
---@param bytes integer
---@return string
local function format_bytes(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.2f MB", bytes / (1024 * 1024))
  end
end

---Get comprehensive metrics and inspection info for a buffer
---@param buf? integer
---@return table
function M.get_info(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return { valid = false }
  end

  local name = vim.api.nvim_buf_get_name(target_buf)
  local line_count = vim.api.nvim_buf_line_count(target_buf)
  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)

  local char_count = 0
  local word_count = 0

  for _, line in ipairs(lines) do
    char_count = char_count + #line + 1
    for _ in line:gmatch("%S+") do
      word_count = word_count + 1
    end
  end

  -- LLM Token estimation: ~4 chars per token, or ~0.75 words per token
  local est_tokens = math.ceil(char_count / 4)

  local file_size = char_count
  if name ~= "" and vim.fn.filereadable(name) == 1 then
    file_size = vim.fn.getfsize(name)
  end

  local is_pinned = pin.is_pinned(target_buf)
  local is_modified = vim.bo[target_buf].modified
  local is_readonly = vim.bo[target_buf].readonly or not vim.bo[target_buf].modifiable
  local filetype = vim.bo[target_buf].filetype
  local encoding = vim.bo[target_buf].fileencoding ~= "" and vim.bo[target_buf].fileencoding or vim.o.encoding
  local fileformat = vim.bo[target_buf].fileformat

  return {
    valid = true,
    buf = target_buf,
    name = name ~= "" and name or "[No Name]",
    short_name = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]",
    relative_path = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]",
    lines = line_count,
    words = word_count,
    chars = char_count,
    tokens = est_tokens,
    size_bytes = file_size,
    size_formatted = format_bytes(file_size),
    is_pinned = is_pinned,
    is_modified = is_modified,
    is_readonly = is_readonly,
    filetype = filetype ~= "" and filetype or "text",
    encoding = encoding,
    fileformat = fileformat,
  }
end

return M
