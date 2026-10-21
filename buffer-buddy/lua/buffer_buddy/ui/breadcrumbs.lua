local config = require("buffer_buddy.config")
local pin = require("buffer_buddy.core.pin")
local tabs = require("buffer_buddy.core.tabs")

local M = {}

---Setup default highlight groups for breadcrumbs
function M.setup_highlights()
  local defs = {
    BufferBuddyBreadcrumbWorkspace = { link = "Special", default = true },
    BufferBuddyBreadcrumbDir = { link = "Directory", default = true },
    BufferBuddyBreadcrumbFile = { link = "Bold", default = true },
    BufferBuddyBreadcrumbSep = { link = "Comment", default = true },
    BufferBuddyBreadcrumbMod = { link = "DiagnosticWarn", default = true },
    BufferBuddyBreadcrumbRO = { link = "DiagnosticError", default = true },
    BufferBuddyBreadcrumbPin = { link = "DiagnosticHint", default = true },
    BufferBuddyBreadcrumbFolder = { link = "Directory", default = true },
  }
  for group, spec in pairs(defs) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

---Check if window or buffer is excluded from breadcrumbs
---@param win integer
---@param buf integer
---@return boolean
local function is_excluded(win, buf)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return true
  end
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return true
  end

  -- Exclude floating windows
  local win_config = vim.api.nvim_win_get_config(win)
  if win_config.relative and win_config.relative ~= "" then
    return true
  end

  local ft = vim.bo[buf].filetype or ""
  local bt = vim.bo[buf].buftype or ""

  local b_opts = (config.options and config.options.breadcrumbs) or {}
  for _, excluded_ft in ipairs(b_opts.excluded_filetypes or {}) do
    if ft == excluded_ft then
      return true
    end
  end

  for _, excluded_bt in ipairs(b_opts.excluded_buftypes or {}) do
    if bt == excluded_bt then
      return true
    end
  end

  return false
end

---Get icon and highlight for a file
---@param buf integer
---@param filename string
---@return string icon, string hl_group
local function get_file_icon(buf, filename)
  local b_opts = (config.options and config.options.breadcrumbs) or {}
  if not b_opts.show_icon then
    return "", ""
  end

  local ft = vim.bo[buf].filetype or ""
  local icon, hl = nil, nil

  -- 1. Try mini.icons (standard in modern Neovim / LazyVim setups)
  if package.loaded["mini.icons"] then
    local ok, mini_icons = pcall(require, "mini.icons")
    if ok then
      icon, hl = mini_icons.get("file", filename)
      if not icon and ft ~= "" then
        icon, hl = mini_icons.get("filetype", ft)
      end
    end
  end

  -- 2. Try nvim-web-devicons
  if not icon and package.loaded["nvim-web-devicons"] then
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
      local ext = vim.fn.fnamemodify(filename, ":e")
      icon, hl = devicons.get_icon(filename, ext, { default = true })
    end
  end

  icon = icon or "󰈔"
  hl = hl or "BufferBuddyBreadcrumbFile"
  return icon, hl
end

---Parse path into directory segments and filename
---@param full_path string
---@return string[] dirs, string filename
local function parse_path_segments(full_path)
  local cwd = vim.fn.getcwd()
  local rel_path = ""

  if full_path:sub(1, #cwd) == cwd then
    rel_path = full_path:sub(#cwd + 2)
  else
    rel_path = vim.fn.fnamemodify(full_path, ":~")
  end

  local parts = {}
  for part in string.gmatch(rel_path, "[^/]+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return {}, vim.fn.fnamemodify(full_path, ":t")
  end

  local filename = table.remove(parts)
  local b_opts = (config.options and config.options.breadcrumbs) or {}
  local max_depth = b_opts.max_depth or 5

  if #parts > max_depth then
    local first = parts[1]
    local truncated = { first, "…" }
    local keep = max_depth - 2
    for i = #parts - keep + 1, #parts do
      table.insert(truncated, parts[i])
    end
    parts = truncated
  end

  return parts, filename
end

---Render breadcrumb for a terminal buffer
---@param buf integer
---@return string
local function render_terminal(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local term_cmd = name:match("term://.*:(.+)$") or "terminal"
  local b_opts = (config.options and config.options.breadcrumbs) or {}
  local sep = b_opts.separator or "  "
  local parts = {
    " %#BufferBuddyBreadcrumbDir# Terminal%*",
    "%#BufferBuddyBreadcrumbSep#" .. sep .. "%*",
    "%#BufferBuddyBreadcrumbFile#" .. vim.fn.fnamemodify(term_cmd, ":t") .. "%*",
  }
  return table.concat(parts, "")
end

---Build the complete breadcrumb winbar string
---@param win integer
---@param buf integer
---@return string
function M.build_breadcrumb_string(win, buf)
  local b_opts = (config.options and config.options.breadcrumbs) or {}
  local sep = b_opts.separator or "  "
  local folder_icon = b_opts.folder_icon or " "
  local segments = {}

  -- 1. Workspace Tab Badge (if tab scoping is active)
  if b_opts.show_workspace and config.options.tab_scoping then
    local cur_tab = vim.api.nvim_win_get_tabpage(win)
    if vim.api.nvim_tabpage_is_valid(cur_tab) then
      local ws_name = tabs.get_tab_name(cur_tab)
      if ws_name and ws_name ~= "" then
        table.insert(segments, string.format("%%#BufferBuddyBreadcrumbWorkspace#󰓩 %s%%* ", ws_name))
        table.insert(segments, "%#BufferBuddyBreadcrumbSep#│ %*")
      end
    end
  end

  local full_path = vim.api.nvim_buf_get_name(buf)

  -- Terminal buffer handling
  if vim.bo[buf].buftype == "terminal" then
    table.insert(segments, render_terminal(buf))
    return table.concat(segments, "")
  end

  -- Empty / Unnamed buffer
  if full_path == "" then
    table.insert(segments, "%#BufferBuddyBreadcrumbFile#[No Name]%*")
    return table.concat(segments, "")
  end

  -- Directory hierarchy
  local dirs, filename = parse_path_segments(full_path)
  for _, dir in ipairs(dirs) do
    if dir == "…" then
      table.insert(segments, "%#BufferBuddyBreadcrumbSep#…%*")
      table.insert(segments, string.format("%%#BufferBuddyBreadcrumbSep#%s%%*", sep))
    else
      table.insert(segments, string.format("%%#BufferBuddyBreadcrumbFolder#%s%%*", folder_icon))
      table.insert(segments, string.format("%%#BufferBuddyBreadcrumbDir#%s%%*", dir))
      table.insert(segments, string.format("%%#BufferBuddyBreadcrumbSep#%s%%*", sep))
    end
  end

  -- File icon and name
  local icon, icon_hl = get_file_icon(buf, filename)
  if icon ~= "" then
    table.insert(segments, string.format("%%#%s#%s %%*", icon_hl, icon))
  end
  table.insert(segments, string.format("%%#BufferBuddyBreadcrumbFile#%s%%*", filename))

  -- Modified state indicator
  if b_opts.show_modified and vim.bo[buf].modified then
    table.insert(segments, " %#BufferBuddyBreadcrumbMod#●%*")
  end

  -- Read-only indicator
  if b_opts.show_readonly and (vim.bo[buf].readonly or not vim.bo[buf].modifiable) then
    table.insert(segments, " %#BufferBuddyBreadcrumbRO#🔒%*")
  end

  -- Pin badge
  if b_opts.show_pin then
    if pin.is_global(buf) then
      table.insert(segments, " %#BufferBuddyBreadcrumbPin#🌐%*")
    elseif pin.is_pinned(buf) then
      table.insert(segments, " %#BufferBuddyBreadcrumbPin#📌%*")
    end
  end

  return " " .. table.concat(segments, "")
end

---Render winbar expression
---@return string
function M.render()
  local b_opts = (config.options and config.options.breadcrumbs) or {}
  if not b_opts.enabled then
    return ""
  end

  local win = vim.g.actual_curwin or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return ""
  end

  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) or is_excluded(win, buf) then
    return ""
  end

  return M.build_breadcrumb_string(win, buf)
end

---Toggle breadcrumbs on or off
function M.toggle()
  config.options.breadcrumbs = config.options.breadcrumbs or {}
  config.options.breadcrumbs.enabled = not config.options.breadcrumbs.enabled
  local state = config.options.breadcrumbs.enabled and "Enabled" or "Disabled"
  vim.notify(string.format("[BufferBuddy] 🍞 Breadcrumbs %s", state), vim.log.levels.INFO)
  pcall(vim.cmd, "redrawstatus!")
end

---Enable breadcrumbs
function M.enable()
  config.options.breadcrumbs = config.options.breadcrumbs or {}
  config.options.breadcrumbs.enabled = true
  pcall(vim.cmd, "redrawstatus!")
end

---Disable breadcrumbs
function M.disable()
  config.options.breadcrumbs = config.options.breadcrumbs or {}
  config.options.breadcrumbs.enabled = false
  pcall(vim.cmd, "redrawstatus!")
end

---Check if breadcrumbs are currently enabled
---@return boolean
function M.is_enabled()
  return config.options.breadcrumbs and config.options.breadcrumbs.enabled == true or false
end

---Setup breadcrumbs winbar and autocommands
function M.setup()
  M.setup_highlights()

  if not config.options.breadcrumbs or not config.options.breadcrumbs.enabled then
    return
  end

  -- Set global winbar expression
  vim.o.winbar = "%{%v:lua.require('buffer_buddy.ui.breadcrumbs').render()%}"

  local group = vim.api.nvim_create_augroup("BufferBuddyBreadcrumbs", { clear = true })

  -- Ensure winbar is set on newly opened windows and re-render on events
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufEnter" }, {
    group = group,
    callback = function(args)
      local win = vim.api.nvim_get_current_win()
      if not is_excluded(win, args.buf) and config.options.breadcrumbs.enabled then
        pcall(function()
          vim.wo[win].winbar = "%{%v:lua.require('buffer_buddy.ui.breadcrumbs').render()%}"
        end)
      end
    end,
  })

  -- Redraw on buffer modifications or write
  vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufWritePost" }, {
    group = group,
    callback = function()
      if config.options.breadcrumbs.enabled then
        pcall(vim.cmd, "redrawstatus")
      end
    end,
  })
end

return M
