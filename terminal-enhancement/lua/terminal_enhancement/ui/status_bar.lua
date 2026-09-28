local process = require("terminal_enhancement.core.process")
local config = require("terminal_enhancement.config")

local M = {}

---Store metadata per terminal buffer { cmd: string, duration: string, pid: number, shell: string, name: string }
local term_status_cache = {}

---Resolve the internal name/ID of a terminal instance
---@param buf integer
---@return string
local function get_internal_name(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return string.format("buf_%d", buf or 0)
  end

  local term_mod = package.loaded["terminal_enhancement.core.terminal"]
  if term_mod and term_mod.instances then
    for id, inst in pairs(term_mod.instances) do
      if inst and inst.buf == buf then
        return inst.id or tostring(id)
      end
    end
  end

  return string.format("buf_%d", buf)
end

---Resolve the Neovim buffer name for a terminal buffer
---@param buf integer
---@return string
local function get_buffer_name(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local raw = vim.api.nvim_buf_get_name(buf)
  if raw and raw ~= "" then
    if #raw > 40 then
      local shortened = vim.fn.pathshorten(raw)
      if #shortened <= 40 then
        return shortened
      end
      return raw:sub(1, 18) .. "..." .. raw:sub(-18)
    end
    return raw
  end

  local bname = vim.fn.bufname(buf)
  if bname and bname ~= "" then
    if #bname > 40 then
      return bname:sub(1, 18) .. "..." .. bname:sub(-18)
    end
    return bname
  end

  return string.format("term://%d", buf)
end

---Resolve a clean, human-readable buffer name for a terminal buffer
---@param buf integer
---@return string
local function get_buffer_display_name(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return "term"
  end

  -- 1. Check if terminal instance is registered with a custom ID or title
  local term_mod = package.loaded["terminal_enhancement.core.terminal"]
  if term_mod and term_mod.instances then
    for id, inst in pairs(term_mod.instances) do
      if inst and inst.buf == buf then
        if inst.title and inst.title ~= "" then
          local clean = inst.title:gsub("^%s*⚡%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
          if clean ~= "" then
            return clean
          end
        elseif inst.id and inst.id ~= "" then
          return inst.id
        end
      end
    end
  end

  -- 2. Check buffer-local terminal title variables set by terminal emulator
  local ok, b_title = pcall(function()
    return vim.b[buf].term_title
      or vim.b[buf].terminal_title
      or vim.b[buf].terminal_name
  end)
  if ok and b_title and type(b_title) == "string" and b_title ~= "" then
    local clean = b_title:gsub("[\r\n]", ""):gsub("%z", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if clean ~= "" then
      -- If title is long (e.g. user@host: ~/path), extract base or last section
      if #clean > 30 then
        clean = clean:match("([^:/~]+)$") or clean:sub(1, 27) .. "..."
      end
      return clean
    end
  end

  -- 3. Parse Neovim's internal buffer name: term://<path>//<pid>:<cmd>
  local raw_name = vim.api.nvim_buf_get_name(buf)
  if raw_name and raw_name ~= "" then
    local term_cmd = raw_name:match("//%d+:(.+)$")
    if term_cmd and term_cmd ~= "" then
      local base_cmd = vim.fn.fnamemodify(term_cmd, ":t")
      if base_cmd and base_cmd ~= "" then
        return base_cmd
      end
      return term_cmd
    end

    local term_tail = raw_name:match("([^:/]+)$")
    if term_tail and term_tail ~= "" and not term_tail:match("^term://") then
      return term_tail
    end

    local b_short = vim.fn.fnamemodify(raw_name, ":t")
    if b_short ~= "" and not b_short:match("^term://") then
      return b_short
    end
  end

  return string.format("term-%d", buf)
end

---Resolve the current working directory for a terminal buffer
---@param buf integer
---@return string
local function get_terminal_directory(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local cwd = process.get_terminal_cwd(buf) or vim.fn.getcwd()
  if cwd and cwd ~= "" then
    local pretty_dir = vim.fn.fnamemodify(cwd, ":~")
    if #pretty_dir > 32 then
      local shortened = vim.fn.pathshorten(pretty_dir)
      if #shortened <= 32 then
        return shortened
      end
      return pretty_dir:sub(1, 14) .. "..." .. pretty_dir:sub(-14)
    end
    return pretty_dir
  end
  return ""
end

---Format a clean lower status bar string for a terminal window/buffer
---@param buf integer
---@return string
function M.render(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local cache = term_status_cache[buf] or {}
  local internal_name = cache.internal_name or get_internal_name(buf)
  local buf_name = cache.buf_name or get_buffer_name(buf)
  local shell = cache.shell or process.detect_shell_type(buf) or "term"
  local cwd = cache.cwd or get_terminal_directory(buf)
  local pid = cache.pid or process.get_terminal_pid(buf)
  local last_cmd = cache.cmd or process.get_last_command(buf) or ""
  local duration = cache.duration or ""

  -- Clean and truncate command if needed
  if last_cmd ~= "" then
    local c = last_cmd:gsub("\n.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #c > 45 then
      c = c:sub(1, 42) .. "..."
    end
    last_cmd = " ⚡ " .. c
  end

  local dur_badge = (duration ~= "") and string.format(" %%#DiagnosticInfo#⏱️ %s%%#StatusLine#", duration) or ""
  local pid_str = pid and string.format(" %%#Comment#(PID %d)%%#StatusLine#", pid) or ""
  local cwd_str = (cwd ~= "") and string.format(" %%#Directory#📁 %s%%#StatusLine#", cwd) or ""
  local buf_badge = string.format("%%#Keyword# [ID: %s • Name: %s #%d • %s]%%#StatusLine#", internal_name, buf_name, buf, shell)
  local mode = vim.api.nvim_get_mode().mode
  local mode_str = (mode == "t") and "%#DiagnosticOk#🟢 TERMINAL%#StatusLine#" or "%#Comment#⚪ NORMAL%#StatusLine#"

  return string.format(
    "%s%s%%#Title#%s%%#StatusLine#%s%s %%=%s ",
    buf_badge, cwd_str, last_cmd, dur_badge, pid_str, mode_str
  )
end

---Format a clean string for floating window border footer (zero collision with Lualine/global statusline)
---@param buf integer
---@return string
function M.render_float_footer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local cache = term_status_cache[buf] or {}
  local internal_name = cache.internal_name or get_internal_name(buf)
  local buf_name = cache.buf_name or get_buffer_name(buf)
  local shell = cache.shell or process.detect_shell_type(buf) or "term"
  local cwd = cache.cwd or get_terminal_directory(buf)
  local pid = cache.pid or process.get_terminal_pid(buf)
  local last_cmd = cache.cmd or process.get_last_command(buf) or ""
  local duration = cache.duration or ""

  local cmd_str = ""
  if last_cmd ~= "" then
    local c = last_cmd:gsub("\n.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #c > 35 then
      c = c:sub(1, 32) .. "..."
    end
    cmd_str = " ⚡ " .. c
  end

  local dur_str = (duration ~= "") and (" ⏱️ " .. duration) or ""
  local pid_str = pid and string.format(" (PID %d)", pid) or ""
  local cwd_str = (cwd ~= "") and (" 📁 " .. cwd) or ""
  local mode = vim.api.nvim_get_mode().mode
  local mode_icon = (mode == "t") and "🟢" or "⚪"

  return string.format(" %s [ID: %s • Name: %s #%d • %s]%s%s%s%s ",
    mode_icon, internal_name, buf_name, buf, shell, cwd_str, cmd_str, dur_str, pid_str)
end

---Evaluated dynamically by Neovim on statusline/winbar redraws
---@return string
function M.draw()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return ""
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return M.render(buf)
end

---Update the lower status bar / footer of a window (instant, flicker-free)
---@param win integer
---@param buf integer
function M.update_window(win, buf)
  if not win or not vim.api.nvim_win_is_valid(win) or not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local status_opts = config.options.status_bar or config.options.sticky_scroll or {}
  if status_opts.enabled == false then
    pcall(vim.api.nvim_set_option_value, "statusline", "", { win = win })
    pcall(vim.api.nvim_set_option_value, "winbar", "", { win = win })
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative and cfg.relative ~= "" then
      pcall(vim.api.nvim_win_set_config, win, { footer = "" })
    end
    return
  end

  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= "" then
    -- Floating Window: render into border footer (never overridden by Lualine/global statusline)
    local footer_text = M.render_float_footer(buf)
    pcall(vim.api.nvim_win_set_config, win, {
      footer = footer_text,
      footer_pos = "left",
    })
    pcall(vim.api.nvim_set_option_value, "winbar", "", { win = win })
  else
    -- Split / Normal Window: use dynamic statusline expression & winbar for laststatus=3
    local expr = "%!v:lua.require('terminal_enhancement.ui.status_bar').draw()"
    pcall(vim.api.nvim_set_option_value, "statusline", expr, { win = win })
    if vim.o.laststatus == 3 then
      pcall(vim.api.nvim_set_option_value, "winbar", expr, { win = win })
    end
  end
end

---Update all windows showing this buffer
---@param buf integer
function M.update_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      M.update_window(win, buf)
    end
  end
end

---Record newly executed command and update status bar instantly
---@param bufnr integer
---@param cmd string
---@param duration? string
function M.record_command(bufnr, cmd, duration)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local clean_cmd = cmd and vim.trim(cmd:gsub("\n.*$", "")) or ""
  term_status_cache[bufnr] = term_status_cache[bufnr] or {}
  term_status_cache[bufnr].cmd = clean_cmd
  if duration then
    term_status_cache[bufnr].duration = duration
  end
  term_status_cache[bufnr].pid = process.get_terminal_pid(bufnr)
  term_status_cache[bufnr].shell = process.detect_shell_type(bufnr)
  term_status_cache[bufnr].internal_name = get_internal_name(bufnr)
  term_status_cache[bufnr].buf_name = get_buffer_name(bufnr)
  term_status_cache[bufnr].cwd = get_terminal_directory(bufnr)
  term_status_cache[bufnr].name = get_buffer_display_name(bufnr)

  M.update_buffer(bufnr)
end

---Update duration for a buffer
---@param buf integer
---@param duration string
function M.record_duration(buf, duration)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  term_status_cache[buf] = term_status_cache[buf] or {}
  term_status_cache[buf].duration = duration
  term_status_cache[buf].internal_name = get_internal_name(buf)
  term_status_cache[buf].buf_name = get_buffer_name(buf)
  term_status_cache[buf].cwd = get_terminal_directory(buf)
  term_status_cache[buf].name = get_buffer_display_name(buf)

  M.update_buffer(buf)
end

---Attach lower status bar to a terminal window
---@param buf integer
---@param win integer
function M.attach(buf, win)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return
  end

  -- Initial fast render and clearing of sticky winbar
  M.update_window(win, buf)

  -- Minimalist event group: ONLY on focus change, ZERO overhead on scroll or typing
  local group = vim.api.nvim_create_augroup("TermEnhanceStatusBar_" .. buf .. "_" .. win, { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "TermEnter", "TermLeave", "ModeChanged" }, {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
        M.update_window(win, buf)
      end
    end,
  })
end

---Toggle lower status bar on or off
function M.toggle()
  config.options.status_bar = config.options.status_bar or {}
  config.options.status_bar.enabled = not (config.options.status_bar.enabled ~= false)
  local state = config.options.status_bar.enabled and "ENABLED" or "DISABLED"

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local b = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(b) and (vim.bo[b].buftype == "terminal" or vim.bo[b].filetype:match("terminal")) then
        pcall(vim.api.nvim_set_option_value, "winbar", "", { win = win })
        if config.options.status_bar.enabled then
          M.update_window(win, b)
        else
          pcall(vim.api.nvim_set_option_value, "statusline", "", { win = win })
        end
      end
    end
  end

  vim.notify(string.format("[TermEnhance] Terminal Lower Status Bar: %s", state), vim.log.levels.INFO)
end

return M
