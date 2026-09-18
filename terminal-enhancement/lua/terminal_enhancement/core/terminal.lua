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

---@type string? Default target terminal ID or buffer string for sending text
M.default_target = nil

---Format a clean display title for any terminal buffer
---@param buf integer
---@param raw_name string
---@return string
local function format_term_display(buf, raw_name)
  local prog = raw_name:match("([^:/]+)$") or "terminal"
  local win = vim.fn.bufwinid(buf)
  local is_open = (win ~= -1)
  local state = is_open and string.format("Visible in Win #%d", win) or "Background"
  return string.format("Terminal [%s] (Buf #%d, %s)", prog, buf, state)
end

---Get all active terminals (both managed instances and any open terminal splits/buffers)
---@return table[] list of { id: string, title: string, is_open: boolean, is_default: boolean, buf: integer, chan: integer }
function M.get_active_terminals()
  local list = {}
  local seen_bufs = {}

  -- 1. Add managed instances
  for id, inst in pairs(M.instances) do
    if inst and inst.buf and vim.api.nvim_buf_is_valid(inst.buf) then
      local win = inst.win
      local win_on_screen = vim.fn.bufwinid(inst.buf)
      local is_open = (win ~= nil and vim.api.nvim_win_is_valid(win)) or (win_on_screen ~= -1)
      local is_default = (M.default_target == id or M.default_target == tostring(inst.buf))
      local chan = inst.job_id or vim.bo[inst.buf].channel or vim.b[inst.buf].terminal_job_id or 0

      table.insert(list, {
        id = id,
        title = inst.title or string.format("Terminal: %s", id),
        buf = inst.buf,
        win = win or (win_on_screen ~= -1 and win_on_screen or nil),
        chan = chan,
        is_open = is_open,
        is_default = is_default,
      })
      seen_bufs[inst.buf] = true
    end
  end

  -- 2. Discover any other open terminal buffers in Neovim (e.g. sidekick, split terminals, :terminal)
  local all_bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(all_bufs) do
    if not seen_bufs[buf] and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      local b_name = vim.api.nvim_buf_get_name(buf)
      local win = vim.fn.bufwinid(buf)
      local is_open = (win ~= -1)
      local id_str = "buf_" .. buf
      local is_default = (M.default_target == id_str or M.default_target == tostring(buf))
      local chan = vim.bo[buf].channel or vim.b[buf].terminal_job_id or 0

      local display_title = format_term_display(buf, b_name)

      -- Register into instances so it can be targeted and toggled seamlessly
      M.instances[id_str] = {
        id = id_str,
        buf = buf,
        win = (win ~= -1) and win or nil,
        job_id = chan,
        cmd = b_name,
        title = display_title,
        direction = "float",
      }

      table.insert(list, {
        id = id_str,
        title = display_title,
        buf = buf,
        win = (win ~= -1) and win or nil,
        chan = chan,
        is_open = is_open,
        is_default = is_default,
      })
    end
  end

  -- Sort: visible terminals first, default target at top
  table.sort(list, function(a, b)
    if a.is_default ~= b.is_default then
      return a.is_default and not b.is_default
    end
    if a.is_open ~= b.is_open then
      return a.is_open and not b.is_open
    end
    return a.id < b.id
  end)

  return list
end

---Set the default target terminal for code sending
---@param id string
function M.set_default_target(id)
  M.default_target = id
  vim.notify(string.format("[TermEnhance] Target terminal set to '%s'", id), vim.log.levels.INFO)
end

---Interactive prompt to select or change target terminal (shows all open & hidden terminals)
---@param on_selected? fun(id: string)
function M.select_target_terminal(on_selected)
  local active = M.get_active_terminals()

  local items = {}
  local hidden_count = 0
  for _, item in ipairs(active) do
    if not item.is_open then
      hidden_count = hidden_count + 1
    end
    local state = item.is_open and "🟢 Visible" or "⚪ Background"
    local def_badge = (M.default_target == item.id) and " [ACTIVE TARGET]" or ""
    table.insert(items, {
      id = item.id,
      label = string.format("%-14s %s%s", state, item.title, def_badge),
    })
  end

  table.insert(items, {
    id = "__new__",
    label = "➕ Create & Open New Terminal...",
  })

  if hidden_count > 0 then
    table.insert(items, {
      id = "__clean_hidden__",
      label = string.format("🧹 Clean %d Background / Hidden Terminal(s)...", hidden_count),
    })
  end

  if #active > 0 then
    table.insert(items, {
      id = "__kill_menu__",
      label = "❌ Kill / Terminate Terminals...",
    })
  end

  vim.ui.select(items, {
    prompt = "Select Target Terminal for Code Execution:",
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
        -- Open the new terminal and keep it open
        M.toggle(clean_name, nil, nil, custom_title, true)
        if on_selected then
          on_selected(clean_name)
        end
      end)
    elseif choice.id == "__clean_hidden__" then
      M.kill_hidden()
    elseif choice.id == "__kill_menu__" then
      M.kill_interactive()
    else
      M.set_default_target(choice.id)
      if on_selected then
        on_selected(choice.id)
      end
    end
  end)
end

---Get or create a terminal instance as a listed visible buffer
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

  -- Create listed buffer (visible in :ls, bufferline tabs, telescope buffers)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal", { buf = buf })

  -- Set buffer name for bufferline tab display
  pcall(vim.api.nvim_buf_set_name, buf, "term://" .. term_id)

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

---Open terminal directly into the active editor window like a standard buffer
---@param id? string
function M.open_as_buffer(id)
  local term_id = id or M.default_target or "default"
  local inst = M.get_or_create(term_id)

  vim.api.nvim_set_current_buf(inst.buf)
  window_ui.apply_terminal_styling(inst.buf, vim.api.nvim_get_current_win())

  if not inst.job_id or inst.job_id <= 0 then
    inst.job_id = vim.fn.jobstart(inst.cmd or vim.o.shell, {
      term = true,
      on_exit = function()
        if vim.api.nvim_buf_is_valid(inst.buf) then
          pcall(vim.api.nvim_buf_delete, inst.buf, { force = true })
        end
        M.instances[term_id] = nil
        if M.default_target == term_id then
          M.default_target = nil
        end
      end,
    })
  end

  if config.options.auto_insert then
    vim.cmd("startinsert")
  end
end

---Send raw text/command into any target terminal (open split, visible window, or background instance)
---@param id? string
---@param text string
function M.send(id, text)
  local target_id = id or M.default_target or "default"
  local inst = M.instances[target_id]
  local just_started = false

  -- If target not registered or invalid, try to get/create
  if not inst then
    inst = M.get_or_create(target_id)
  end

  local chan = inst.job_id or (inst.buf and vim.bo[inst.buf].channel) or (inst.buf and vim.b[inst.buf].terminal_job_id)

  -- If terminal job is not running or window not visible and not open anywhere:
  local is_open = (inst.win and vim.api.nvim_win_is_valid(inst.win)) or (inst.buf and vim.fn.bufwinid(inst.buf) ~= -1)

  if not is_open or not chan or chan <= 0 then
    -- Open terminal split/float if not already visible anywhere
    M.toggle(target_id, nil, nil, nil, false)
    inst = M.instances[target_id]
    chan = inst.job_id or (inst.buf and vim.bo[inst.buf].channel) or (inst.buf and vim.b[inst.buf].terminal_job_id)
    just_started = true
  end

  local payload = text
  if not payload:match("\n$") then
    payload = payload .. "\n"
  end

  if just_started then
    -- Allow shell 60ms to initialize pty stdin
    vim.defer_fn(function()
      local active_chan = inst.job_id or (inst.buf and vim.bo[inst.buf].channel) or (inst.buf and vim.b[inst.buf].terminal_job_id)
      if active_chan and active_chan > 0 then
        vim.fn.chansend(active_chan, payload)
      end
    end, 60)
  else
    if chan and chan > 0 then
      vim.fn.chansend(chan, payload)
    end
  end
end

---Kill and purge a terminal by ID or buffer number
---@param id_or_buf? string|integer
---@return boolean, string
function M.kill(id_or_buf)
  local target_id = id_or_buf or M.default_target or "default"
  local target_buf = nil
  local inst = nil

  if type(target_id) == "number" then
    target_buf = target_id
    for id, i in pairs(M.instances) do
      if i.buf == target_buf then
        inst = i
        target_id = id
        break
      end
    end
  else
    inst = M.instances[tostring(target_id)]
    if inst then
      target_buf = inst.buf
    else
      local b_num = tonumber(tostring(target_id):match("^buf_(%d+)$") or tostring(target_id))
      if b_num and vim.api.nvim_buf_is_valid(b_num) then
        target_buf = b_num
      end
    end
  end

  if not target_buf or not vim.api.nvim_buf_is_valid(target_buf) then
    return false, string.format("Terminal '%s' not found or already closed", tostring(id_or_buf or target_id))
  end

  -- Close any open window for this instance/buffer
  if inst and inst.win and vim.api.nvim_win_is_valid(inst.win) then
    pcall(vim.api.nvim_win_close, inst.win, true)
    inst.win = nil
  end
  local win_on_screen = vim.fn.bufwinid(target_buf)
  if win_on_screen ~= -1 and vim.api.nvim_win_is_valid(win_on_screen) then
    local tab_wins = vim.api.nvim_tabpage_list_wins(0)
    if #tab_wins > 1 then
      pcall(vim.api.nvim_win_close, win_on_screen, true)
    end
  end

  -- Stop job channel
  local chan = (inst and inst.job_id) or vim.bo[target_buf].channel or vim.b[target_buf].terminal_job_id or 0
  if chan and chan > 0 then
    pcall(vim.fn.jobstop, chan)
  end

  -- Delete buffer
  pcall(vim.api.nvim_buf_delete, target_buf, { force = true })

  -- Cleanup instance table
  if inst then
    M.instances[inst.id] = nil
  end
  for k, v in pairs(M.instances) do
    if v.buf == target_buf then
      M.instances[k] = nil
    end
  end

  -- Reset default_target if it matched
  if M.default_target == tostring(target_id) or M.default_target == tostring(target_buf) then
    M.default_target = nil
    local remaining = M.get_active_terminals()
    if #remaining > 0 then
      M.default_target = remaining[1].id
    end
  end

  return true, string.format("Killed terminal '%s' (Buf #%d)", tostring(target_id), target_buf)
end

---Kill all hidden/background terminal buffers to free memory and PTYs
---@return integer count of terminals killed
function M.kill_hidden()
  local all_bufs = vim.api.nvim_list_bufs()
  local killed_count = 0

  for _, buf in ipairs(all_bufs) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      local win = vim.fn.bufwinid(buf)
      if win == -1 then
        -- This terminal is in the background
        local chan = vim.bo[buf].channel or vim.b[buf].terminal_job_id or 0
        if chan and chan > 0 then
          pcall(vim.fn.jobstop, chan)
        end
        pcall(vim.api.nvim_buf_delete, buf, { force = true })

        -- Clean up instances
        for k, v in pairs(M.instances) do
          if v.buf == buf then
            M.instances[k] = nil
            if M.default_target == k or M.default_target == tostring(buf) then
              M.default_target = nil
            end
          end
        end

        killed_count = killed_count + 1
      end
    end
  end

  -- Pick remaining default target if reset
  if not M.default_target then
    local remaining = M.get_active_terminals()
    if #remaining > 0 then
      M.default_target = remaining[1].id
    end
  end

  if killed_count > 0 then
    vim.notify(string.format("[TermEnhance] 🧹 Cleaned %d hidden terminal(s). Freed PTYs and memory.", killed_count), vim.log.levels.INFO)
  else
    vim.notify("[TermEnhance] No hidden/background terminals found to clean.", vim.log.levels.INFO)
  end

  return killed_count
end

---Kill all active terminals (both visible and hidden)
---@return integer count of terminals killed
function M.kill_all()
  local active = M.get_active_terminals()
  local count = 0
  for _, item in ipairs(active) do
    local ok = M.kill(item.id)
    if ok then
      count = count + 1
    end
  end
  M.instances = {}
  M.default_target = nil
  vim.notify(string.format("[TermEnhance] 🧹 Terminated all %d active terminal(s).", count), vim.log.levels.INFO)
  return count
end

---Interactive prompt to kill specific terminal, kill hidden, or kill all
function M.kill_interactive()
  local active = M.get_active_terminals()
  if #active == 0 then
    vim.notify("[TermEnhance] No running terminals to kill.", vim.log.levels.INFO)
    return
  end

  local hidden_count = 0
  for _, item in ipairs(active) do
    if not item.is_open then
      hidden_count = hidden_count + 1
    end
  end

  local items = {}

  if hidden_count > 0 then
    table.insert(items, {
      action = "clean_hidden",
      label = string.format("🧹 Clean All Hidden Terminals (%d background %s)", hidden_count, hidden_count == 1 and "buffer" or "buffers"),
    })
  end

  table.insert(items, {
    action = "kill_all",
    label = string.format("💥 Kill ALL Terminals (%d total)", #active),
  })

  for _, item in ipairs(active) do
    local state = item.is_open and "🟢 Visible" or "⚪ Background"
    local def_badge = (M.default_target == item.id) and " [ACTIVE TARGET]" or ""
    table.insert(items, {
      action = "kill_one",
      id = item.id,
      label = string.format("❌ Kill %-12s %s%s", state, item.title, def_badge),
    })
  end

  vim.ui.select(items, {
    prompt = "Select Terminal to Terminate/Kill:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.action == "clean_hidden" then
      M.kill_hidden()
    elseif choice.action == "kill_all" then
      M.kill_all()
    elseif choice.action == "kill_one" and choice.id then
      local ok, msg = M.kill(choice.id)
      if ok then
        vim.notify("[TermEnhance] " .. msg, vim.log.levels.INFO)
      else
        vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
      end
    end
  end)
end

return M
