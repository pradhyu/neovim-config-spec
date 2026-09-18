local config = require("terminal_enhancement.config")

local M = {}

---Apply clean terminal options to a buffer and window
---@param buf integer
---@param win integer
function M.apply_terminal_styling(buf, win)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local opts = config.options

  if opts.clean_buffer then
    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
    vim.api.nvim_set_option_value("spell", false, { win = win })
    vim.api.nvim_set_option_value("list", false, { win = win })
  end

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,NormalNC:NormalFloatNC,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
    { win = win }
  )
end

---Open a window according to specified direction
---@param buf integer
---@param direction? "float"|"horizontal"|"vertical"
---@param title? string
---@return integer win_id
function M.create_window(buf, direction, title)
  local dir = direction or config.options.direction or "float"
  local win_id = nil

  if dir == "horizontal" then
    local height = config.options.split_size.horizontal or 15
    vim.cmd(string.format("botright %dsplit", height))
    win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_id, buf)
  elseif dir == "vertical" then
    local width = config.options.split_size.vertical or 60
    vim.cmd(string.format("botright %dvsplit", width))
    win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_id, buf)
  else
    -- High-performance Centered Floating Window
    local f_opts = config.options.float_opts
    local total_w = vim.o.columns
    local total_h = vim.o.lines

    local width = math.floor(total_w * (f_opts.width or 0.85))
    local height = math.floor(total_h * (f_opts.height or 0.80))
    local row = math.floor((total_h - height) / 2)
    local col = math.floor((total_w - width) / 2)

    local win_title = title or f_opts.title or " ⚡ Terminal (Float) "

    local win_config = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = f_opts.border or "rounded",
      title = win_title,
      title_pos = f_opts.title_pos or "center",
    }

    win_id = vim.api.nvim_open_win(buf, true, win_config)
  end

  M.apply_terminal_styling(buf, win_id)
  require("terminal_enhancement.core.keymaps").attach_to_buffer(buf, win_id)
  return win_id
end

return M
