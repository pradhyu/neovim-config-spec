local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Format a human-readable display label for terminal picker item
---@param item table
---@return string
local function format_item_label(item)
  if item.is_action then
    return item.title
  end

  local state_icon = item.is_open and "🟢" or "⚪"
  local shell_badge = string.format("[%s]", item.shell_type or "bash")
  local pid_str = item.pid and string.format("(PID %d)", item.pid) or ""

  local proc_str = ""
  if item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
    proc_str = string.format(" ➔ %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid)
  end

  local port_str = ""
  if item.ports and #item.ports > 0 then
    local p_list = {}
    for _, p in ipairs(item.ports) do
      table.insert(p_list, ":" .. p.port)
    end
    port_str = string.format(" 🎧 %s", table.concat(p_list, ","))
  end

  local def_badge = item.is_default and " ⭐ TARGET" or ""
  local buf_str = item.buf and string.format(" (Buf #%d)", item.buf) or ""

  return string.format("%s %s %s %s%s%s%s%s",
    state_icon, shell_badge, item.title, pid_str, proc_str, port_str, buf_str, def_badge)
end

---Open the interactive Terminal Switcher (uses vim.ui.select / Snacks.picker)
---@param opts? table
function M.open(opts)
  local active_list = terminal.get_active_terminals()
  local items = {}

  -- 1. Add all active terminals first
  for _, t in ipairs(active_list) do
    table.insert(items, {
      id = t.id,
      title = t.title,
      shell_type = t.shell_type,
      pid = t.pid,
      fg_proc = t.fg_proc,
      ports = t.ports,
      buf = t.buf,
      is_open = t.is_open,
      is_default = t.is_default,
      is_action = false,
    })
  end

  -- 2. Add quick spawn actions
  table.insert(items, {
    id = "__new_float__",
    title = "➕ [New] Create Floating Terminal (Default)",
    shell_type = "bash",
    is_action = true,
  })
  table.insert(items, {
    id = "__new_split_h__",
    title = "➕ [New] Create Horizontal Split Terminal",
    shell_type = "bash",
    is_action = true,
  })
  table.insert(items, {
    id = "__new_split_v__",
    title = "➕ [New] Create Vertical Split Terminal",
    shell_type = "bash",
    is_action = true,
  })
  table.insert(items, {
    id = "__new_pwsh__",
    title = "➕ [New] Create PowerShell Terminal (pwsh)",
    shell_type = "pwsh",
    is_action = true,
  })

  if #active_list > 0 then
    table.insert(items, {
      id = "__clean_hidden__",
      title = "🧹 [Clean] Terminate All Hidden Terminals",
      is_action = true,
    })
  end

  vim.ui.select(items, {
    prompt = " 💻 Switch Terminal (Type to filter): ",
    format_item = function(item)
      return format_item_label(item)
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.id == "__new_float__" then
      terminal.toggle("float")
    elseif choice.id == "__new_split_h__" then
      terminal.toggle("horizontal", nil, "horizontal")
    elseif choice.id == "__new_split_v__" then
      terminal.toggle("vertical", nil, "vertical")
    elseif choice.id == "__new_pwsh__" then
      terminal.toggle("pwsh", "pwsh", "float")
    elseif choice.id == "__clean_hidden__" then
      terminal.kill_hidden()
    else
      terminal.focus(choice.id)
    end
  end)
end

return M
