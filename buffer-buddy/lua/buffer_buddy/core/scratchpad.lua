local config = require("buffer_buddy.config")

local M = {}

---@type table<string, integer> cache of scratchpad buffers by filetype
M.cached_pads = {}

---Open or create a scratchpad buffer
---@param filetype? string ("markdown"|"lua"|"sql"|"json"|"sh"|"python")
---@param style? "float"|"split"|"vsplit"
---@return integer buf, integer win
function M.open_scratchpad(filetype, style)
  local ft = filetype or "markdown"
  local target_style = style or config.options.scratchpad_style or "float"

  -- Check if cached buffer is still valid
  local buf = M.cached_pads[ft]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = ft
    vim.api.nvim_buf_set_name(buf, string.format("[Scratchpad: %s]", ft:upper()))

    -- Add default header comment
    local header = {
      string.format("<!-- Scratchpad [%s] - Ephemeral notes & snippets -->", ft:upper()),
      "",
    }
    if ft == "lua" or ft == "sql" or ft == "sh" or ft == "python" then
      local comment_prefix = (ft == "lua" or ft == "sql") and "--" or "#"
      header = {
        string.format("%s Scratchpad [%s] - Ephemeral notes & snippets", comment_prefix, ft:upper()),
        "",
      }
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
    M.cached_pads[ft] = buf
  end

  local win = nil
  if target_style == "float" then
    local width = math.min(100, math.floor(vim.o.columns * 0.85))
    local height = math.min(30, math.floor(vim.o.lines * 0.8))
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = string.format(" 📝 Scratchpad: %s ", ft:upper()),
      title_pos = "center",
    })
  elseif target_style == "vsplit" then
    vim.cmd("vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  else
    vim.cmd("split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  end

  return buf, win
end

return M
