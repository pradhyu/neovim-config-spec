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

  -- Clear winbar to prevent sticky top bar flickering
  pcall(vim.api.nvim_set_option_value, "winbar", "", { win = win })

  local status_opt = opts.status_bar or opts.sticky_scroll or {}
  if status_opt.enabled ~= false then
    require("terminal_enhancement.ui.status_bar").attach(buf, win)
  end
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
    local f_opts = vim.tbl_deep_extend("force", config.defaults.float_opts or {}, config.options.float_opts or {})
    local total_w = vim.o.columns
    local total_h = vim.o.lines

    local width = math.floor(total_w * (f_opts.width or 0.85))
    local height = math.floor(total_h * (f_opts.height or 0.80))
    local row = math.floor((total_h - height) / 2)
    local col = math.floor((total_w - width) / 2)

    local win_title = title or f_opts.title or " ⚡ Terminal (Float) "

    local status_opts = config.options.status_bar or config.options.sticky_scroll or {}
    local footer_text = nil
    if status_opts.enabled ~= false then
      local status_bar = require("terminal_enhancement.ui.status_bar")
      footer_text = status_bar.render_float_footer(buf)
    end

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

    if footer_text and footer_text ~= "" then
      win_config.footer = footer_text
      win_config.footer_pos = "left"
    end

    win_id = vim.api.nvim_open_win(buf, true, win_config)
  end

  M.apply_terminal_styling(buf, win_id)
  require("terminal_enhancement.core.keymaps").attach_to_buffer(buf, win_id)
  return win_id
end

---Stored original geometry for zoomed windows
---@type table<integer, { width: integer, height: integer, row: number, col: number, border: any }>
M.zoomed_windows = {}

---Toggle maximize / zoom for active or specified terminal window
---@param win_id? integer
---@return boolean is_now_zoomed
function M.toggle_zoom(win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win_id) then
    return false
  end

  local cfg = vim.api.nvim_win_get_config(win_id)
  local is_float = (cfg.relative ~= "")

  if is_float then
    if M.zoomed_windows[win_id] then
      -- Restore original floating window geometry
      local orig = M.zoomed_windows[win_id]
      M.zoomed_windows[win_id] = nil
      vim.api.nvim_win_set_config(win_id, {
        relative = "editor",
        width = orig.width,
        height = orig.height,
        row = orig.row,
        col = orig.col,
        border = orig.border,
      })
      vim.notify("[TermEnhance] 🔍 Restored modal geometry", vim.log.levels.INFO)
      return false
    else
      -- Save original geometry and maximize to full screen
      M.zoomed_windows[win_id] = {
        width = cfg.width,
        height = cfg.height,
        row = tonumber(cfg.row) or 0,
        col = tonumber(cfg.col) or 0,
        border = cfg.border,
      }
      local max_w = math.max(1, vim.o.columns - 2)
      local max_h = math.max(1, vim.o.lines - 3)
      vim.api.nvim_win_set_config(win_id, {
        relative = "editor",
        width = max_w,
        height = max_h,
        row = 0,
        col = 0,
        border = "rounded",
      })
      vim.notify("[TermEnhance] 🔍 Maximized terminal to full screen", vim.log.levels.INFO)
      return true
    end
  else
    -- Split window: toggle maximize via standard window sizing
    if vim.w[win_id].is_split_zoomed then
      vim.w[win_id].is_split_zoomed = false
      vim.cmd("wincmd =")
      vim.notify("[TermEnhance] Restored split sizes", vim.log.levels.INFO)
      return false
    else
      vim.w[win_id].is_split_zoomed = true
      vim.cmd("wincmd _")
      vim.cmd("wincmd |")
      vim.notify("[TermEnhance] 🔍 Maximized split window", vim.log.levels.INFO)
      return true
    end
  end
end

return M
