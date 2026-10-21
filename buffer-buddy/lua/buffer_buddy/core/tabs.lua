local config = require("buffer_buddy.config")

local M = {
  ---@type table<integer, table<integer, boolean>> tab_handle -> set of buf_handles
  _tab_buffers = {},
  ---@type table<integer, string> tab_handle -> custom name
  _tab_names = {},
  ---@type table<integer, boolean> buf_handle -> true if pinned globally across all tabs
  _global_buffers = {},
}

---Get tabpage handle from tab index or handle
---@param tab? integer
---@return integer tab_handle
local function resolve_tab(tab)
  if not tab or tab == 0 then
    return vim.api.nvim_get_current_tabpage()
  end
  if vim.api.nvim_tabpage_is_valid(tab) then
    return tab
  end
  -- Maybe it's a 1-based tab index (e.g. 1, 2, 3)
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_get_number(t) == tab then
      return t
    end
  end
  return vim.api.nvim_get_current_tabpage()
end

---Check if buffer is an internal or ignorable buffer
---@param buf integer
---@return boolean
local function is_ignorable_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return true
  end
  local ft = vim.bo[buf].filetype or ""
  if ft == "bufferbuddy_hud" or ft == "bufferbuddy_scratch_picker" then
    return true
  end
  if ft:match("^blink%-cmp") or ft:match("^snacks") or ft:match("^notify") or ft:match("^noice") then
    return true
  end
  local bt = vim.bo[buf].buftype or ""
  if bt == "quickfix" or bt == "prompt" or bt == "nofile" then
    return true
  end
  return false
end

---Initialize a tabpage tracking table if not present
---@param tab_handle integer
local function ensure_tab(tab_handle)
  if not M._tab_buffers[tab_handle] then
    M._tab_buffers[tab_handle] = {}
  end
end

---Add a buffer to a tab's workspace
---@param buf integer
---@param tab? integer
function M.add_buffer_to_tab(buf, tab)
  if is_ignorable_buffer(buf) then
    return
  end
  local t = resolve_tab(tab)
  if not vim.api.nvim_tabpage_is_valid(t) then
    return
  end
  ensure_tab(t)
  M._tab_buffers[t][buf] = true
end

---Remove a buffer from a tab's workspace
---@param buf integer
---@param tab? integer
function M.remove_buffer_from_tab(buf, tab)
  local t = resolve_tab(tab)
  if M._tab_buffers[t] then
    M._tab_buffers[t][buf] = nil
  end
end

---Check if a buffer belongs to a tab
---@param buf integer
---@param tab? integer
---@return boolean
function M.is_buffer_in_tab(buf, tab)
  local t = resolve_tab(tab)
  return M._tab_buffers[t] and M._tab_buffers[t][buf] == true or false
end

---Get all buffer numbers belonging to a tab
---@param tab? integer
---@return integer[]
function M.get_tab_buffers(tab)
  local t = resolve_tab(tab)
  local list = {}
  if M._tab_buffers[t] then
    for buf, _ in pairs(M._tab_buffers[t]) do
      if vim.api.nvim_buf_is_valid(buf) then
        table.insert(list, buf)
      end
    end
  end
  table.sort(list)
  return list
end

---Check if a buffer is exclusive to a tab (not present in any other tab)
---@param buf integer
---@param tab? integer
---@return boolean
function M.is_buffer_exclusive_to_tab(buf, tab)
  local target_tab = resolve_tab(tab)
  if not M.is_buffer_in_tab(buf, target_tab) then
    return false
  end
  if M.is_global_buffer(buf) then
    return false
  end

  for t, bufs in pairs(M._tab_buffers) do
    if t ~= target_tab and vim.api.nvim_tabpage_is_valid(t) and bufs[buf] then
      return false
    end
  end
  return true
end

---Get list of tabs that contain a specific buffer
---@param buf integer
---@return integer[] tab_handles
function M.get_buffer_tabs(buf)
  local tabs = {}
  for t, bufs in pairs(M._tab_buffers) do
    if vim.api.nvim_tabpage_is_valid(t) and bufs[buf] then
      table.insert(tabs, t)
    end
  end
  return tabs
end

-- =============================================================================
-- Global Buffer Pinning (Visible across all tabs)
-- =============================================================================

---Check if a buffer is globally pinned across all tabs
---@param buf? integer
---@return boolean
function M.is_global_buffer(buf)
  local target = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target) then
    return false
  end
  return M._global_buffers[target] == true or vim.b[target].buffer_buddy_global_pin == true
end

---Set global pin state for a buffer
---@param buf? integer
---@param is_global boolean
function M.set_global_buffer(buf, is_global)
  local target = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target) then
    return
  end
  if is_global then
    M._global_buffers[target] = true
    vim.b[target].buffer_buddy_global_pin = true
    -- Ensure listed in current tab
    vim.bo[target].buflisted = true
    local name = vim.api.nvim_buf_get_name(target)
    local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or string.format("Buf #%d", target)
    vim.notify(string.format("[BufferBuddy] 🌐 Buffer '%s' is now pinned GLOBALLY (visible across all tabs)", short), vim.log.levels.INFO)
  else
    M._global_buffers[target] = nil
    vim.b[target].buffer_buddy_global_pin = false
    local name = vim.api.nvim_buf_get_name(target)
    local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or string.format("Buf #%d", target)
    vim.notify(string.format("[BufferBuddy] 🔓 Buffer '%s' global pin removed", short), vim.log.levels.INFO)
  end
  M.sync_tab_scoping()
end

---Toggle global pin state
---@param buf? integer
---@return boolean new_state
function M.toggle_global_buffer(buf)
  local target = buf or vim.api.nvim_get_current_buf()
  local new_state = not M.is_global_buffer(target)
  M.set_global_buffer(target, new_state)
  return new_state
end

-- =============================================================================
-- Tab Naming & Metadata
-- =============================================================================

---Trigger bufferline / tabline redraw across the editor
function M.refresh_tabline()
  pcall(function()
    local ok, ui = pcall(require, "bufferline.ui")
    if ok and ui and ui.refresh then
      ui.refresh()
    end
  end)
  pcall(vim.cmd, "redrawtabline")
end

---Update tab variable `name` for bufferline / tablines based on custom name or active buffer
---@param tab? integer
function M.update_tab_name(tab)
  local t = resolve_tab(tab)
  if not vim.api.nvim_tabpage_is_valid(t) then
    return
  end

  -- 1. Prioritize explicit user-assigned name
  if M._tab_names[t] and M._tab_names[t] ~= "" then
    pcall(function()
      vim.t[t].name = M._tab_names[t]
      vim.t[t].bb_tab_name = M._tab_names[t]
    end)
    return
  end

  -- 2. If tab_auto_name is enabled, derive from the active window's buffer in this tab
  if config.options.tab_auto_name then
    local cur_win = vim.api.nvim_tabpage_get_win(t)
    local cur_buf = vim.api.nvim_win_is_valid(cur_win) and vim.api.nvim_win_get_buf(cur_win) or 0
    local bname = (vim.api.nvim_buf_is_valid(cur_buf) and not is_ignorable_buffer(cur_buf))
      and vim.api.nvim_buf_get_name(cur_buf) or ""

    if bname == "" then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
        if vim.api.nvim_win_is_valid(win) then
          local b = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_is_valid(b) and not is_ignorable_buffer(b) then
            local n = vim.api.nvim_buf_get_name(b)
            if n ~= "" then
              bname = n
              break
            end
          end
        end
      end
    end

    if bname ~= "" then
      local label = vim.fn.fnamemodify(bname, ":t")
      pcall(function()
        vim.t[t].name = label
      end)
      return
    end
  end

  -- Default: clear explicit name so bufferline displays default or tabnr
  pcall(function()
    vim.t[t].name = nil
  end)
end

---Set custom name for a tab
---@param name string
---@param tab? integer
function M.set_tab_name(name, tab)
  local t = resolve_tab(tab)
  local num = vim.api.nvim_tabpage_get_number(t)
  if name and name:match("%S") then
    local trimmed = name:match("^%s*(.-)%s*$")
    M._tab_names[t] = trimmed
    pcall(function()
      vim.t[t].bb_tab_name = trimmed
      vim.t[t].name = trimmed
    end)
    vim.notify(string.format("[BufferBuddy] 🏷️ Tab %d workspace named: '%s'", num, trimmed), vim.log.levels.INFO)
  else
    M._tab_names[t] = nil
    pcall(function()
      vim.t[t].bb_tab_name = nil
      vim.t[t].name = nil
    end)
    vim.notify(string.format("[BufferBuddy] 🏷️ Tab %d name reset to default", num), vim.log.levels.INFO)
  end
  M.update_tab_name(t)
  M.refresh_tabline()
end

---Get display name for a tab
---@param tab? integer
---@return string
function M.get_tab_name(tab)
  local t = resolve_tab(tab)
  local num = vim.api.nvim_tabpage_get_number(t)
  if M._tab_names[t] and M._tab_names[t] ~= "" then
    return M._tab_names[t]
  end

  -- Check vim tab variable
  local ok, var = pcall(function() return vim.t[t].name or vim.t[t].bb_tab_name end)
  if ok and var and var ~= "" then
    M._tab_names[t] = var
    return var
  end

  if config.options.tab_auto_name then
    -- Derive from active window buffer in this tab
    local wins = vim.api.nvim_tabpage_list_wins(t)
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) then
        local b = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(b) and not is_ignorable_buffer(b) then
          local bname = vim.api.nvim_buf_get_name(b)
          if bname ~= "" then
            return vim.fn.fnamemodify(bname, ":t")
          end
        end
      end
    end
  end

  return string.format("Tab %d", num)
end

---Prompt user to rename current tab workspace
---@param tab? integer
function M.rename_tab_interactive(tab)
  local t = resolve_tab(tab)
  local num = vim.api.nvim_tabpage_get_number(t)
  local current = M._tab_names[t] or ""
  vim.ui.input({
    prompt = string.format("Rename Workspace Tab %d: ", num),
    default = current,
  }, function(input)
    if input ~= nil then
      M.set_tab_name(input, t)
    end
  end)
end

---Create a new named tab workspace
---@param name? string
function M.new_tab(name)
  vim.cmd("tabnew")
  local new_t = vim.api.nvim_get_current_tabpage()
  ensure_tab(new_t)
  if name and name ~= "" then
    M.set_tab_name(name, new_t)
  else
    M.rename_tab_interactive(new_t)
  end
  M.sync_tab_scoping()
end

-- =============================================================================
-- Workspace Scoping & Buflisted Synchronization
-- =============================================================================

---Synchronize buflisted status across all buffers based on active tab
function M.sync_tab_scoping()
  if not config.options.tab_scoping then
    return
  end

  local cur_tab = vim.api.nvim_get_current_tabpage()
  if not vim.api.nvim_tabpage_is_valid(cur_tab) then
    return
  end

  ensure_tab(cur_tab)

  local tab_bufs = M._tab_buffers[cur_tab] or {}

  -- Update buflisted status for all loaded buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and not is_ignorable_buffer(buf) then
      local is_global = M.is_global_buffer(buf)
      local in_cur = tab_bufs[buf] == true

      if is_global or in_cur then
        if not vim.bo[buf].buflisted then
          vim.bo[buf].buflisted = true
        end
      else
        -- Check if tracked in any other active tab
        local in_other = false
        for t, bufs in pairs(M._tab_buffers) do
          if t ~= cur_tab and vim.api.nvim_tabpage_is_valid(t) and bufs[buf] then
            in_other = true
            break
          end
        end
        if in_other then
          if vim.bo[buf].buflisted then
            vim.bo[buf].buflisted = false
          end
        end
      end
    end
  end
end

---Filter function for bufferline.nvim or custom tablines
---@param buf_number integer
---@return boolean
function M.bufferline_filter(buf_number)
  if not config.options.tab_scoping then
    return true
  end
  local cur_tab = vim.api.nvim_get_current_tabpage()
  return M.is_global_buffer(buf_number) or M.is_buffer_in_tab(buf_number, cur_tab)
end

-- =============================================================================
-- Tab Buffer Navigation & Movement
-- =============================================================================

---Cycle to next buffer within the current tab
function M.next_buffer()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local bufs = M.get_tab_buffers(cur_tab)
  if #bufs <= 1 then
    return
  end
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_idx = 1
  for i, b in ipairs(bufs) do
    if b == cur_buf then
      cur_idx = i
      break
    end
  end
  local next_idx = (cur_idx % #bufs) + 1
  vim.api.nvim_win_set_buf(0, bufs[next_idx])
end

---Cycle to previous buffer within the current tab
function M.prev_buffer()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local bufs = M.get_tab_buffers(cur_tab)
  if #bufs <= 1 then
    return
  end
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_idx = 1
  for i, b in ipairs(bufs) do
    if b == cur_buf then
      cur_idx = i
      break
    end
  end
  local prev_idx = cur_idx - 1
  if prev_idx < 1 then
    prev_idx = #bufs
  end
  vim.api.nvim_win_set_buf(0, bufs[prev_idx])
end

---Move buffer to a target tab
---@param target_tab integer|string Tab index or name
---@param buf? integer Buffer to move (default: current buffer)
function M.move_buffer_to_tab(target_tab, buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return
  end

  local cur_tab = vim.api.nvim_get_current_tabpage()
  local dest_tab = resolve_tab(tonumber(target_tab) or target_tab)

  if not vim.api.nvim_tabpage_is_valid(dest_tab) then
    vim.notify(string.format("[BufferBuddy] Invalid target tab '%s'", tostring(target_tab)), vim.log.levels.WARN)
    return
  end

  if dest_tab == cur_tab then
    vim.notify("[BufferBuddy] Buffer is already in the current tab workspace", vim.log.levels.INFO)
    return
  end

  -- Add to dest tab, remove from cur tab
  M.add_buffer_to_tab(target_buf, dest_tab)
  M.remove_buffer_from_tab(target_buf, cur_tab)

  -- If target_buf was displayed in current window, switch to alternate buffer
  local alt = vim.fn.bufnr("#")
  if alt > 0 and alt ~= target_buf and vim.api.nvim_buf_is_valid(alt) and M.is_buffer_in_tab(alt, cur_tab) then
    vim.api.nvim_win_set_buf(0, alt)
  else
    local tab_bufs = M.get_tab_buffers(cur_tab)
    local replaced = false
    for _, b in ipairs(tab_bufs) do
      if b ~= target_buf and vim.api.nvim_buf_is_valid(b) then
        vim.api.nvim_win_set_buf(0, b)
        replaced = true
        break
      end
    end
    if not replaced then
      local fresh = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_win_set_buf(0, fresh)
      M.add_buffer_to_tab(fresh, cur_tab)
    end
  end

  M.sync_tab_scoping()

  local bname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(target_buf), ":t")
  if bname == "" then bname = string.format("Buf #%d", target_buf) end
  local dest_name = M.get_tab_name(dest_tab)
  local dest_num = vim.api.nvim_tabpage_get_number(dest_tab)
  vim.notify(string.format("[BufferBuddy] 📦 Moved '%s' to Tab %d [%s]", bname, dest_num, dest_name), vim.log.levels.INFO)
end

---Send/share buffer to target tab without removing from current tab
---@param target_tab integer|string
---@param buf? integer
function M.send_buffer_to_tab(target_tab, buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return
  end

  local dest_tab = resolve_tab(tonumber(target_tab) or target_tab)
  if not vim.api.nvim_tabpage_is_valid(dest_tab) then
    vim.notify(string.format("[BufferBuddy] Invalid target tab '%s'", tostring(target_tab)), vim.log.levels.WARN)
    return
  end

  M.add_buffer_to_tab(target_buf, dest_tab)
  local bname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(target_buf), ":t")
  if bname == "" then bname = string.format("Buf #%d", target_buf) end
  local dest_name = M.get_tab_name(dest_tab)
  local dest_num = vim.api.nvim_tabpage_get_number(dest_tab)
  vim.notify(string.format("[BufferBuddy] 📋 Shared '%s' with Tab %d [%s]", bname, dest_num, dest_name), vim.log.levels.INFO)
end

---Interactively select a tab to move current buffer to
---@param buf? integer
function M.move_buffer_interactive(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local tabs = vim.api.nvim_list_tabpages()

  if #tabs <= 1 then
    vim.notify("[BufferBuddy] Only 1 tab exists. Use :tabnew or <leader>BN to create a workspace first.", vim.log.levels.INFO)
    return
  end

  local items = {}
  local tab_map = {}
  for _, t in ipairs(tabs) do
    if t ~= cur_tab then
      local num = vim.api.nvim_tabpage_get_number(t)
      local name = M.get_tab_name(t)
      local count = #M.get_tab_buffers(t)
      local label = string.format("Tab %d: %s (%d buffers)", num, name, count)
      table.insert(items, label)
      tab_map[label] = t
    end
  end

  vim.ui.select(items, { prompt = "Move Buffer to Workspace Tab:" }, function(choice)
    if choice and tab_map[choice] then
      M.move_buffer_to_tab(tab_map[choice], target_buf)
    end
  end)
end

-- =============================================================================
-- Safe Tab Workspace Close
-- =============================================================================

---Safely close a tab workspace and clean up its exclusive buffers
---@param tab? integer
---@param force? boolean
function M.close_tab_safe(tab, force)
  local t = resolve_tab(tab)
  if not vim.api.nvim_tabpage_is_valid(t) then
    return
  end

  local all_tabs = vim.api.nvim_list_tabpages()
  if #all_tabs <= 1 then
    vim.notify("[BufferBuddy] Cannot close the only remaining tab", vim.log.levels.WARN)
    return
  end

  local tab_num = vim.api.nvim_tabpage_get_number(t)
  local tab_name = M.get_tab_name(t)
  local bufs = M.get_tab_buffers(t)

  -- Check for unsaved changes in exclusive buffers
  local unsaved = {}
  for _, b in ipairs(bufs) do
    if M.is_buffer_exclusive_to_tab(b, t) and vim.bo[b].modified then
      table.insert(unsaved, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t"))
    end
  end

  if #unsaved > 0 and not force then
    vim.notify(string.format("[BufferBuddy] ⚠️ Cannot close tab %d: %d buffer(s) have unsaved changes (%s). Save them first or force close.",
      tab_num, #unsaved, table.concat(unsaved, ", ")), vim.log.levels.ERROR)
    return
  end

  local pin = require("buffer_buddy.core.pin")
  local hygiene = require("buffer_buddy.core.hygiene")

  -- Clean up exclusive unpinned buffers
  local closed_count = 0
  for _, b in ipairs(bufs) do
    if M.is_buffer_exclusive_to_tab(b, t) and not pin.is_pinned(b) then
      if hygiene.close_buffer_safely(b, force) then
        closed_count = closed_count + 1
      end
    end
  end

  -- Close the tabpage
  local cur_t = vim.api.nvim_get_current_tabpage()
  if t == cur_t then
    vim.cmd("tabclose")
  else
    -- Switch, close, return
    vim.api.nvim_set_current_tabpage(t)
    vim.cmd("tabclose")
  end

  -- Clean tracking
  M._tab_buffers[t] = nil
  M._tab_names[t] = nil

  M.sync_tab_scoping()
  vim.notify(string.format("[BufferBuddy] 🚪 Closed Tab %d [%s] and cleaned %d exclusive buffer(s)", tab_num, tab_name, closed_count), vim.log.levels.INFO)
end

-- =============================================================================
-- Workspace Overview & Statusline Helpers
-- =============================================================================

---Get full workspace intelligence report for all tabs
---@return table[]
function M.get_all_tabs_info()
  local pin = require("buffer_buddy.core.pin")
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local result = {}

  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    local num = vim.api.nvim_tabpage_get_number(t)
    local name = M.get_tab_name(t)
    local bufs = M.get_tab_buffers(t)
    local buf_info = {}

    for _, b in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(b) then
        local raw_name = vim.api.nvim_buf_get_name(b)
        local short = raw_name ~= "" and vim.fn.fnamemodify(raw_name, ":t") or string.format("Buf #%d", b)
        table.insert(buf_info, {
          buf = b,
          name = short,
          modified = vim.bo[b].modified,
          is_pinned = pin.is_pinned(b),
          is_global = M.is_global_buffer(b),
        })
      end
    end

    table.insert(result, {
      tab = t,
      num = num,
      name = name,
      is_active = (t == cur_tab),
      buffers = buf_info,
    })
  end

  return result
end

---Get compact workspace label for statusline
---@return string
function M.get_workspace_label()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local num = vim.api.nvim_tabpage_get_number(cur_tab)
  local name = M.get_tab_name(cur_tab)
  local count = #M.get_tab_buffers(cur_tab)
  return string.format("󰓩 %d:%s (%d)", num, name, count)
end

-- =============================================================================
-- Setup Autocmds
-- =============================================================================

---Setup tab lifecycle autocommands
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("BufferBuddyTabs", { clear = true })

  -- Track buffers as they open in windows and maintain workspace labels
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
    group = group,
    callback = function(args)
      local buf = args.buf
      if vim.api.nvim_buf_is_valid(buf) and not is_ignorable_buffer(buf) then
        local cur_tab = vim.api.nvim_get_current_tabpage()
        M.add_buffer_to_tab(buf, cur_tab)
        M.update_tab_name(cur_tab)
        M.refresh_tabline()
      end
    end,
  })

  -- When switching tabs, update scoping and refresh tabline
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      local cur_tab = vim.api.nvim_get_current_tabpage()
      M.sync_tab_scoping()
      M.update_tab_name(cur_tab)
      M.refresh_tabline()
    end,
  })

  -- When creating a new tab
  vim.api.nvim_create_autocmd("TabNewEntered", {
    group = group,
    callback = function()
      local cur_tab = vim.api.nvim_get_current_tabpage()
      ensure_tab(cur_tab)
      local cur_buf = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(cur_buf) and not is_ignorable_buffer(cur_buf) then
        M.add_buffer_to_tab(cur_buf, cur_tab)
      end
      M.sync_tab_scoping()
      M.update_tab_name(cur_tab)
      M.refresh_tabline()
    end,
  })

  -- When closing a tab, clean up stale references
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      -- Prune any tab handle that is no longer valid
      for t, _ in pairs(M._tab_buffers) do
        if not vim.api.nvim_tabpage_is_valid(t) then
          M._tab_buffers[t] = nil
          M._tab_names[t] = nil
        end
      end
      vim.schedule(function()
        M.sync_tab_scoping()
        M.refresh_tabline()
      end)
    end,
  })

  -- When a buffer is completely wiped out, clean from all tab sets
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      local buf = args.buf
      for _, bufs in pairs(M._tab_buffers) do
        bufs[buf] = nil
      end
      M._global_buffers[buf] = nil
    end,
  })

  -- Initial population of active tab
  local initial_tab = vim.api.nvim_get_current_tabpage()
  ensure_tab(initial_tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(initial_tab)) do
    if vim.api.nvim_win_is_valid(win) then
      local b = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(b) and not is_ignorable_buffer(b) then
        M.add_buffer_to_tab(b, initial_tab)
      end
    end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and not is_ignorable_buffer(b) then
      M.add_buffer_to_tab(b, initial_tab)
    end
  end
  M.sync_tab_scoping()

  -- Initialize tab names for all existing tabpages
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_is_valid(t) then
      M.update_tab_name(t)
    end
  end
  M.refresh_tabline()
end

return M
