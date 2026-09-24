local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Format a human-readable display label for terminal picker item (for vim.ui.select fallback)
---@param item table
---@return string
local function format_item_label(item)
  if item.is_action then
    return item.title
  end

  local state_icon = item.is_open and "🟢" or "⚪"
  local shell_badge = string.format("[%s]", item.shell_type or "bash")
  local pid_str = item.pid and string.format("(PID %d)", item.pid) or ""

  local cmd_str = ""
  if item.last_cmd and item.last_cmd ~= "" then
    local clean_cmd = item.last_cmd:gsub("\n.*$", "")
    if #clean_cmd > 35 then
      clean_cmd = clean_cmd:sub(1, 32) .. "..."
    end
    cmd_str = string.format(" ⚡ %s", clean_cmd)
  elseif item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
    cmd_str = string.format(" ➔ %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid)
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

  return string.format("%s %s %s%s%s%s%s%s",
    state_icon, shell_badge, item.title, cmd_str, port_str, pid_str, buf_str, def_badge)
end

---Open terminal switcher using Snacks.picker with live preview window
---@param opts? table
function M.open_snacks(opts)
  if not _G.Snacks or not Snacks.picker then
    error("Snacks.picker not available")
  end

  local active_list = terminal.get_active_terminals()
  local items = {}

  for idx, t in ipairs(active_list) do
    local search_text = string.format("%s %s %s %s %s",
      t.id, t.title, t.shell_type or "", t.last_cmd or "", t.pid and tostring(t.pid) or "")
    if t.ports then
      for _, p in ipairs(t.ports) do
        search_text = search_text .. " " .. tostring(p.port)
      end
    end

    table.insert(items, {
      idx = idx,
      score = idx,
      text = search_text,
      terminal = t,
      is_action = false,
    })
  end

  -- Quick spawn actions
  local action_specs = {
    { id = "__new_float__", title = "➕ [New] Create Floating Terminal (Default)", desc = "Spawns a new centered floating terminal session" },
    { id = "__new_split_h__", title = "➕ [New] Create Horizontal Split Terminal", desc = "Spawns a bottom horizontal split terminal" },
    { id = "__new_split_v__", title = "➕ [New] Create Vertical Split Terminal", desc = "Spawns a right vertical split terminal" },
    { id = "__new_pwsh__", title = "➕ [New] Create PowerShell Terminal (pwsh)", desc = "Spawns a floating PowerShell (pwsh) terminal" },
  }

  if #active_list > 0 then
    table.insert(action_specs, {
      id = "__clean_hidden__",
      title = "🧹 [Clean] Terminate All Hidden Terminals",
      desc = "Closes background terminals, terminates their processes, and frees PTYs/ports",
    })
  end

  for _, a in ipairs(action_specs) do
    table.insert(items, {
      idx = #items + 1,
      score = 100 + #items,
      text = a.title,
      action = a,
      is_action = true,
    })
  end

  Snacks.picker({
    title = " 💻 Switch Terminal ",
    items = items,
    format = function(item)
      if item.is_action then
        return {
          { " " .. item.action.title, "Function" },
        }
      end

      local t = item.terminal
      local state_icon = t.is_open and "🟢" or "⚪"
      local shell_badge = string.format("[%s]", t.shell_type or "bash")
      local pid_str = t.pid and string.format("(PID %d)", t.pid) or ""

      local cmd_str = ""
      if t.last_cmd and t.last_cmd ~= "" then
        local c = t.last_cmd:gsub("\n.*$", "")
        if #c > 35 then
          c = c:sub(1, 32) .. "..."
        end
        cmd_str = " ⚡ " .. c
      end

      local port_str = ""
      if t.ports and #t.ports > 0 then
        local pl = {}
        for _, p in ipairs(t.ports) do
          table.insert(pl, ":" .. p.port)
        end
        port_str = " 🎧 " .. table.concat(pl, ",")
      end

      local def_badge = t.is_default and " ⭐ TARGET" or ""

      local formatted = {
        { state_icon .. " ", "Normal" },
        { shell_badge .. " ", "Keyword" },
        { t.title .. " ", "Title" },
      }

      if cmd_str ~= "" then
        table.insert(formatted, { cmd_str .. " ", "String" })
      end
      if port_str ~= "" then
        table.insert(formatted, { port_str .. " ", "Special" })
      end
      if pid_str ~= "" then
        table.insert(formatted, { pid_str .. " ", "Comment" })
      end
      if def_badge ~= "" then
        table.insert(formatted, { def_badge, "DiagnosticWarn" })
      end

      return formatted
    end,
    preview = function(ctx)
      ctx.preview:reset()

      if ctx.item.is_action then
        local a = ctx.item.action
        local lines = {
          "╭─────────────────────────────────────────────────────────────╮",
          string.format("│  Action: %-50s │", a.title),
          "╰─────────────────────────────────────────────────────────────╯",
          "",
          "  " .. (a.desc or ""),
          "",
          "  Press <CR> to execute this action.",
        }
        ctx.preview:set_lines(lines)
        return
      end

      local t = ctx.item.terminal
      local lines = {}

      table.insert(lines, "╭─────────────────────────────────────────────────────────────╮")
      table.insert(lines, string.format("│ 🖥️  Terminal: %-25s [%s]  •  PID: %-6s │",
        t.id, t.shell_type or "bash", t.pid and tostring(t.pid) or "none"))

      if t.cwd and t.cwd ~= "" then
        table.insert(lines, string.format("│ 📁 CWD: %-52s │", t.cwd))
      end

      if t.last_cmd and t.last_cmd ~= "" then
        table.insert(lines, string.format("│ ⚡ Last Command: %-43s │", t.last_cmd))
      end

      if t.ports and #t.ports > 0 then
        local pl = {}
        for _, p in ipairs(t.ports) do
          table.insert(pl, ":" .. p.port)
        end
        table.insert(lines, string.format("│ 🎧 Listening Ports: %-40s │", table.concat(pl, ", ")))
      end

      table.insert(lines, "╰─────────────────────────────────────────────────────────────╯")
      table.insert(lines, "")

      -- Fetch live lines from terminal buffer to show what's inside
      if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
        local total_lines = vim.api.nvim_buf_line_count(t.buf)
        local max_preview = 60
        local start_line = math.max(0, total_lines - max_preview)
        local term_content = vim.api.nvim_buf_get_lines(t.buf, start_line, total_lines, false)

        table.insert(lines, string.format("--- Live Terminal Output (Buffer #%d, %d lines) ---", t.buf, total_lines))
        table.insert(lines, "")
        for _, l in ipairs(term_content) do
          table.insert(lines, l)
        end
      else
        table.insert(lines, "  [Terminal buffer not available or closed]")
      end

      ctx.preview:set_lines(lines)
      if ctx.win and vim.api.nvim_win_is_valid(ctx.win) then
        pcall(vim.api.nvim_win_set_cursor, ctx.win, { #lines, 0 })
      end
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end

      if item.is_action then
        local a = item.action
        if a.id == "__new_float__" then
          terminal.toggle("float")
        elseif a.id == "__new_split_h__" then
          terminal.toggle("horizontal", nil, "horizontal")
        elseif a.id == "__new_split_v__" then
          terminal.toggle("vertical", nil, "vertical")
        elseif a.id == "__new_pwsh__" then
          terminal.toggle("pwsh", "pwsh", "float")
        elseif a.id == "__clean_hidden__" then
          terminal.kill_hidden()
        end
      elseif item.terminal then
        terminal.focus(item.terminal.id)
      end
    end,
  })
end

---Open the interactive Terminal Switcher (uses Snacks.picker with live preview, with vim.ui.select fallback)
---@param opts? table
function M.open(opts)
  -- 1. Prefer Snacks.picker for rich dual-window live preview
  if _G.Snacks and Snacks.picker then
    local ok, err = pcall(M.open_snacks, opts)
    if ok then
      return
    end
  end

  -- 2. Fallback: vim.ui.select
  local active_list = terminal.get_active_terminals()
  local items = {}

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
      last_cmd = t.last_cmd,
      cwd = t.cwd,
      is_action = false,
    })
  end

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
