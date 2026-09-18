local config = require("terminal_enhancement.config")
local window_ui = require("terminal_enhancement.ui.window")

local M = {}

---@class TermInstance
---@field id string
---@field buf integer
---@field win? integer
---@field job_id? integer
---@field cmd? string
---@field direction? string
---@field title? string

---@type table<string, TermInstance>
M.instances = {}

---@type string? Default target terminal ID for sending text
M.default_target = nil

---Get all currently active and valid terminal instances
---@return table[] list of { id: string, title: string, is_open: boolean, is_default: boolean }
function M.get_active_terminals()
  local list = {}
  for id, inst in pairs(M.instances) do
    if inst and inst.buf and vim.api.nvim_buf_is_valid(inst.buf) then
      local is_open = inst.win ~= nil and vim.api.nvim_win_is_valid(inst.win)
      local is_default = (M.default_target == id)
      table.insert(list, {
        id = id,
        title = inst.title or string.format("Terminal: %s", id),
        buf = inst.buf,
        win = inst.win,
        is_open = is_open,
        is_default = is_default,
      })
    end
  end

  table.sort(list, function(a, b)
    if a.is_default ~= b.is_default then
      return a.is_default and not b.is_default
    end
    return a.id < b.id
  end)

  return list
end

---Set the default target terminal for code sending
---@param id string
function M.set_default_target(id)
  M.default_target = id
  vim.notify(string.format("[TermEnhance] Active target terminal set to '%s'", id), vim.log.levels.INFO)
end

---Interactive prompt to select or change default target terminal
---@param on_selected? fun(id: string)
function M.select_target_terminal(on_selected)
  local active = M.get_active_terminals()

  local items = {}
  for _, item in ipairs(active) do
    local state = item.is_open and "Visible" or "Hidden"
    local def_badge = (M.default_target == item.id) and " [ACTIVE TARGET]" or ""
    table.insert(items, {
      id = item.id,
      label = string.format("• %s (%s)%s", item.title, state, def_badge),
    })
  end

  table.insert(items, {
    id = "__new__",
    label = "➕ Create & Open New Named Terminal...",
  })

  vim.ui.select(items, {
    prompt = "Select / Switch Target Terminal:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.id == "__new__" then
      local default_name = "term_" .. (#active + 1)
      vim.ui.input({ prompt = "New Terminal Name (e.g. python, node, term2): ", default = default_name }, function(name)
        if not name or name == "" then
          return
        end
        local clean_name = name:gsub("%s+", "_")
        local custom_title = string.format(" Terminal: %s ", clean_name)
        M.get_or_create(clean_name, nil, nil, custom_title)
        M.set_default_target(clean_name)
        -- Open the new terminal and keep it open with that custom title!
        M.toggle(clean_name, nil, nil, custom_title, true)
        if on_selected then
          on_selected(clean_name)
        end
      end)
    else
      M.set_default_target(choice.id)
      -- Ensure the selected terminal is open and visible
      local inst = M.instances[choice.id]
      if inst and not (inst.win and vim.api.nvim_win_is_valid(inst.win)) then
        M.toggle(choice.id, nil, nil, inst.title, false)
      end
      if on_selected then
        on_selected(choice.id)
      end
    end
  end)
end

---Get or create a terminal instance
---@param id? string
---@param cmd? string
---@param direction? "float"|"horizontal"|"vertical"
---@param title? string
---@return TermInstance
function M.get_or_create(id, cmd, direction, title)
  local term_id = id or "default"
  local inst = M.instances[term_id]

  if inst and vim.api.nvim_buf_is_valid(inst.buf) then
    if cmd and cmd ~= inst.cmd then
      inst.cmd = cmd
    end
    if direction then
      inst.direction = direction
    end
    if title then
      inst.title = title
    end
    return inst
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal", { buf = buf })

  local command = cmd or vim.o.shell

  inst = {
    id = term_id,
    buf = buf,
    cmd = command,
    direction = direction or config.options.direction or "float",
    title = title or string.format(" Terminal: %s ", term_id),
  }

  M.instances[term_id] = inst

  -- If no default target is set yet, make this one the default
  if not M.default_target then
    M.default_target = term_id
  end

  return inst
end

---Toggle terminal window visibility
---@param id? string
---@param cmd? string
---@param direction? "float"|"horizontal"|"vertical"
---@param title? string
---@param focus? boolean (default true)
function M.toggle(id, cmd, direction, title, focus)
  if focus == nil then
    focus = true
  end

  local term_id = id or M.default_target or "default"
  local inst = M.get_or_create(term_id, cmd, direction, title)

  -- If window is currently open and valid, close/hide it
  if inst.win and vim.api.nvim_win_is_valid(inst.win) then
    pcall(vim.api.nvim_win_close, inst.win, true)
    inst.win = nil
    return
  end

  local orig_win = vim.api.nvim_get_current_win()

  -- Open window
  local dir = direction or inst.direction or config.options.direction or "float"
  local win = window_ui.create_window(inst.buf, dir, title or inst.title)
  inst.win = win

  -- Listen for window close event to keep inst.win in sync
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if inst.win == win then
        inst.win = nil
      end
    end,
  })

  -- If terminal job not spawned yet or terminated, start it
  if not inst.job_id or inst.job_id <= 0 then
    vim.api.nvim_win_call(win, function()
      inst.job_id = vim.fn.jobstart(inst.cmd or vim.o.shell, {
        term = true,
        on_exit = function()
          if inst.win and vim.api.nvim_win_is_valid(inst.win) then
            pcall(vim.api.nvim_win_close, inst.win, true)
            inst.win = nil
          end
          if vim.api.nvim_buf_is_valid(inst.buf) then
            pcall(vim.api.nvim_buf_delete, inst.buf, { force = true })
          end
          M.instances[term_id] = nil
          if M.default_target == term_id then
            M.default_target = nil
          end
        end,
      })
    end)
  end

  if focus and config.options.auto_insert then
    vim.cmd("startinsert")
  elseif not focus then
    -- Restore original window focus
    if orig_win and vim.api.nvim_win_is_valid(orig_win) then
      pcall(vim.api.nvim_set_current_win, orig_win)
    end
  end
end

---Send raw text/command into a terminal instance and keep it open
---@param id string
---@param text string
function M.send(id, text)
  local target_id = id or M.default_target or "default"
  local inst = M.instances[target_id]
  local just_started = false

  if not inst or not inst.job_id or inst.job_id <= 0 or not (inst.win and vim.api.nvim_win_is_valid(inst.win)) then
    -- Open terminal window if not already visible, but preserve user editor focus
    M.toggle(target_id, nil, nil, nil, false)
    inst = M.instances[target_id]
    just_started = true
  end

  local payload = text
  if not payload:match("\n$") then
    payload = payload .. "\n"
  end

  if just_started then
    -- Allow shell 60ms to initialize pty stdin
    vim.defer_fn(function()
      if inst and inst.job_id and inst.job_id > 0 then
        vim.fn.chansend(inst.job_id, payload)
      end
    end, 60)
  else
    if inst and inst.job_id and inst.job_id > 0 then
      vim.fn.chansend(inst.job_id, payload)
    end
  end
end

return M
