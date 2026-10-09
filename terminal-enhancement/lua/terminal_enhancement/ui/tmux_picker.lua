local tmux = require("terminal_enhancement.core.tmux")

local M = {}

---Prompt user to add a new target on the fly
---@param callback? fun(target_name: string)
function M.prompt_add_target(callback)
  vim.ui.select({
    "1. Remote SSH VM / Server",
    "2. WSL Linux Distro (Windows)",
    "3. Custom Command Wrapper",
  }, {
    prompt = "Select Target Type to Add:",
  }, function(choice)
    if not choice then return end

    if choice:match("^1") then
      vim.ui.input({ prompt = "Target Name / ID (e.g. dev_vm, cloud_gpu): " }, function(name)
        if not name or vim.trim(name) == "" then return end
        name = vim.trim(name)

        vim.ui.input({ prompt = "SSH Host (hostname or IP, e.g. dev-box.internal): " }, function(host)
          if not host or vim.trim(host) == "" then return end
          host = vim.trim(host)

          vim.ui.input({ prompt = "SSH User (optional, press Enter to omit): " }, function(user)
            local user_clean = (user and vim.trim(user) ~= "") and vim.trim(user) or nil
            vim.ui.input({ prompt = "SSH Port (optional, default 22): " }, function(port_str)
              local port = tonumber(port_str)
              tmux.register_target(name, {
                type = "ssh",
                host = host,
                user = user_clean,
                port = port,
                desc = string.format("SSH VM [%s%s]", user_clean and (user_clean .. "@") or "", host),
              })
              tmux.set_active_target(name)
              if callback then callback(name) else M.open(name) end
            end)
          end)
        end)
      end)
    elseif choice:match("^2") then
      vim.ui.input({ prompt = "Target Name / ID (e.g. wsl_fedora, wsl_arch): " }, function(name)
        if not name or vim.trim(name) == "" then return end
        name = vim.trim(name)

        vim.ui.input({ prompt = "WSL Distro Name (e.g. Fedora, Debian, Ubuntu): " }, function(distro)
          if not distro or vim.trim(distro) == "" then return end
          distro = vim.trim(distro)

          tmux.register_target(name, {
            type = "wsl",
            distro = distro,
            desc = string.format("WSL [%s]", distro),
          })
          tmux.set_active_target(name)
          if callback then callback(name) else M.open(name) end
        end)
      end)
    else
      vim.ui.input({ prompt = "Target Name / ID: " }, function(name)
        if not name or vim.trim(name) == "" then return end
        name = vim.trim(name)

        vim.ui.input({ prompt = "Tmux Execution Command (e.g. docker exec -it dev tmux): " }, function(cmd_str)
          if not cmd_str or vim.trim(cmd_str) == "" then return end
          local parts = vim.split(vim.trim(cmd_str), "%s+")
          tmux.register_target(name, {
            type = "custom",
            cmd = parts,
            desc = string.format("Custom [%s]", name),
          })
          tmux.set_active_target(name)
          if callback then callback(name) else M.open(name) end
        end)
      end)
    end
  end)
end

---Switch active target picker
---@param on_selected? fun(target_name: string)
function M.switch_target_picker(on_selected)
  local targets = tmux.get_targets()
  local items = {}

  for _, t in ipairs(targets) do
    local is_curr = (t.name == tmux.active_target) and " ⭐ ACTIVE" or ""
    table.insert(items, {
      name = t.name,
      desc = t.desc,
      type = t.type,
      cmd = table.concat(t.cmd, " "),
      label = string.format("[%s] %s (%s)%s", t.name, t.desc, t.type:upper(), is_curr),
    })
  end

  table.insert(items, {
    name = "__add_new__",
    label = "➕ [Add New Target / VM] Register custom WSL Distro or SSH Host",
    is_add = true,
  })

  vim.ui.select(items, {
    prompt = "Select Tmux Target / VM:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    if choice.is_add then
      M.prompt_add_target(on_selected)
    else
      tmux.set_active_target(choice.name)
      if on_selected then
        on_selected(choice.name)
      else
        M.open(choice.name)
      end
    end
  end)
end

---Prompt to create a new session
---@param target_name? string
---@param cwd? string
function M.prompt_new_session(target_name, cwd)
  local target = tmux.get_target(target_name)
  local default_name = cwd and vim.fn.fnamemodify(cwd, ":t") or "work"
  vim.ui.input({
    prompt = string.format("New Tmux Session name on [%s]: ", target.name),
    default = default_name,
  }, function(name)
    if not name or vim.trim(name) == "" then return end
    name = vim.trim(name)
    tmux.create_session(target.name, name, "float", cwd)
  end)
end

---Prompt to rename a session
---@param target_name? string
---@param session_name string
function M.prompt_rename_session(target_name, session_name)
  local target = tmux.get_target(target_name)
  vim.ui.input({
    prompt = string.format("Rename Tmux session '%s' on [%s] to: ", session_name, target.name),
    default = session_name,
  }, function(new_name)
    if not new_name or vim.trim(new_name) == "" or vim.trim(new_name) == session_name then return end
    new_name = vim.trim(new_name)
    local ok, msg = tmux.rename_session(target.name, session_name, new_name)
    if ok then
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.INFO)
      M.open(target.name)
    else
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
    end
  end)
end

---Prompt to add a new window to session
---@param target_name? string
---@param session_name string
function M.prompt_new_window(target_name, session_name)
  local target = tmux.get_target(target_name)
  vim.ui.input({
    prompt = string.format("New Window Name in session '%s' on [%s] (optional): ", session_name, target.name),
  }, function(win_name)
    win_name = (win_name and vim.trim(win_name) ~= "") and vim.trim(win_name) or nil
    local ok, msg = tmux.new_window(target.name, session_name, win_name)
    if ok then
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.INFO)
      M.open(target.name)
    else
      vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
    end
  end)
end

---Prompt to kill a session
---@param target_name? string
---@param session_name string
function M.prompt_kill_session(target_name, session_name)
  local target = tmux.get_target(target_name)
  vim.ui.select({
    "1. Yes, Kill Session",
    "2. Cancel",
  }, {
    prompt = string.format("Kill Tmux session '%s' on [%s]?", session_name, target.name),
  }, function(choice)
    if choice and choice:match("^1") then
      local ok, msg = tmux.kill_session(target.name, session_name)
      if ok then
        vim.notify("[TermEnhance] " .. msg, vim.log.levels.INFO)
        M.open(target.name)
      else
        vim.notify("[TermEnhance] " .. msg, vim.log.levels.WARN)
      end
    end
  end)
end

---Instant Project Session Creator (Zoxide / Git / Workspace picker)
---@param target_name? string
function M.open_project_picker(target_name)
  local target = tmux.get_target(target_name)
  local projects = tmux.get_projects()

  if #projects == 0 then
    vim.notify("[TermEnhance] No project directories detected.", vim.log.levels.WARN)
    return
  end

  if _G.Snacks and Snacks.picker then
    local items = {}
    for idx, p in ipairs(projects) do
      table.insert(items, {
        idx = idx,
        score = idx,
        text = string.format("%s %s %s", p.name, p.path, p.source),
        project = p,
      })
    end

    Snacks.picker({
      title = string.format(" 🚀 Tmux Project Session [%s] ", target.name),
      items = items,
      format = function(item)
        local p = item.project
        return {
          { " 📁 ", "Normal" },
          { p.name .. " ", "Title" },
          { "(" .. p.source .. ") ", "Comment" },
          { p.path, "Directory" },
        }
      end,
      preview = function(ctx)
        ctx.preview:reset()
        local p = ctx.item.project
        local lines = {
          "╭─────────────────────────────────────────────────────────────╮",
          string.format("│ 📁 Project: %-47s │", p.name),
          string.format("│ 📂 Source:  %-47s │", p.source),
          string.format("│ 📍 Path:    %-47s │", p.path:sub(1, 47)),
          "╰─────────────────────────────────────────────────────────────╯",
          "",
          "  Press <CR>   : Create / attach in Floating Window",
          "  Press <C-v>  : Create / attach in Vertical Split",
          "  Press <C-s>  : Create / attach in Horizontal Split",
          "  Press <C-t>  : Create / attach in New Tab",
          "",
          "--- Directory Contents ---",
          "",
        }
        local entries = vim.fn.globpath(p.path, "*", false, true)
        for i = 1, math.min(#entries, 25) do
          local e_name = vim.fn.fnamemodify(entries[i], ":t")
          local is_dir = vim.fn.isdirectory(entries[i]) == 1 and "/" or ""
          table.insert(lines, string.format("  • %s%s", e_name, is_dir))
        end
        ctx.preview:set_lines(lines)
      end,
      actions = {
        tmux_vsplit = function(picker, item)
          picker:close()
          if not item then return end
          local p = item.project
          vim.schedule(function()
            local sessions = tmux.list_sessions(target.name)
            local exists = false
            for _, s in ipairs(sessions) do
              if s.name == p.name then exists = true; break end
            end
            if exists then
              tmux.attach(target.name, p.name, "vertical")
            else
              tmux.create_session(target.name, p.name, "vertical", p.path)
            end
          end)
        end,
        tmux_hsplit = function(picker, item)
          picker:close()
          if not item then return end
          local p = item.project
          vim.schedule(function()
            local sessions = tmux.list_sessions(target.name)
            local exists = false
            for _, s in ipairs(sessions) do
              if s.name == p.name then exists = true; break end
            end
            if exists then
              tmux.attach(target.name, p.name, "horizontal")
            else
              tmux.create_session(target.name, p.name, "horizontal", p.path)
            end
          end)
        end,
        tmux_tab = function(picker, item)
          picker:close()
          if not item then return end
          local p = item.project
          vim.schedule(function()
            local sessions = tmux.list_sessions(target.name)
            local exists = false
            for _, s in ipairs(sessions) do
              if s.name == p.name then exists = true; break end
            end
            if exists then
              tmux.attach(target.name, p.name, "tab")
            else
              tmux.create_session(target.name, p.name, "tab", p.path)
            end
          end)
        end,
      },
      win = {
        input = {
          keys = {
            ["<c-v>"] = { "tmux_vsplit", desc = "Attach in Vertical Split" },
            ["<c-s>"] = { "tmux_hsplit", desc = "Attach in Horizontal Split" },
            ["<c-t>"] = { "tmux_tab", desc = "Attach in New Tab" },
          },
        },
      },
      confirm = function(picker, item)
        picker:close()
        if not item then return end
        local p = item.project
        vim.schedule(function()
          -- Check if session already exists
          local sessions = tmux.list_sessions(target.name)
          local exists = false
          for _, s in ipairs(sessions) do
            if s.name == p.name then
              exists = true
              break
            end
          end
          if exists then
            tmux.attach(target.name, p.name, "float")
          else
            tmux.create_session(target.name, p.name, "float", p.path)
          end
        end)
      end,
    })
  else
    local items = {}
    for _, p in ipairs(projects) do
      table.insert(items, {
        label = string.format("📁 %-20s (%s) %s", p.name, p.source, p.path),
        project = p,
      })
    end
    vim.ui.select(items, {
      prompt = string.format("Create / Attach Tmux Project on [%s]:", target.name),
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      local p = choice.project
      local sessions = tmux.list_sessions(target.name)
      local exists = false
      for _, s in ipairs(sessions) do
        if s.name == p.name then exists = true; break end
      end
      if exists then
        tmux.attach(target.name, p.name, "float")
      else
        tmux.create_session(target.name, p.name, "float", p.path)
      end
    end)
  end
end

---Windows Drill-down Picker
---@param target_name string
---@param session_name string
function M.open_windows_picker(target_name, session_name)
  local target = tmux.get_target(target_name)
  local windows = tmux.list_windows(target.name, session_name)

  if #windows == 0 then
    vim.notify(string.format("[TermEnhance] No windows found in session '%s'.", session_name), vim.log.levels.WARN)
    return
  end

  if _G.Snacks and Snacks.picker then
    local items = {}
    for idx, w in ipairs(windows) do
      table.insert(items, {
        idx = idx,
        score = idx,
        text = string.format("%d %s %s", w.index, w.name, w.is_active and "active" or ""),
        window = w,
        session_name = session_name,
        target = target,
      })
    end

    Snacks.picker({
      title = string.format(" 📑 Windows: %s [%s] ", session_name, target.name),
      items = items,
      format = function(item)
        local w = item.window
        local active_mark = w.is_active and "▶ " or "  "
        return {
          { active_mark, w.is_active and "DiagnosticOk" or "Normal" },
          { string.format("[%d] ", w.index), "Keyword" },
          { w.name .. " ", "Title" },
          { string.format("(%d pane%s)", w.panes, w.panes > 1 and "s" or ""), "Comment" },
          { w.is_active and " [active]" or "", "DiagnosticInfo" },
        }
      end,
      preview = function(ctx)
        ctx.preview:reset()
        local w = ctx.item.window
        local s_spec = string.format("%s:%d", session_name, w.index)
        local pane_lines = tmux.capture_pane(target.name, s_spec, 40)

        local lines = {
          "╭─────────────────────────────────────────────────────────────╮",
          string.format("│ 📑 Window: %-25s Session: %-18s │", w.name, session_name),
          string.format("│ 📍 Index:  %-25d Panes:   %-18d │", w.index, w.panes),
          "╰─────────────────────────────────────────────────────────────╯",
          "",
          "─── Live Screen Content (capture-pane) ───────────────────────",
          "",
        }
        if #pane_lines > 0 then
          for _, l in ipairs(pane_lines) do
            table.insert(lines, l)
          end
        else
          table.insert(lines, "  [No output lines captured from window pane]")
        end
        ctx.preview:set_lines(lines)
      end,
      actions = {
        tmux_vsplit = function(picker, item)
          picker:close()
          if not item then return end
          local w = item.window
          local spec = string.format("%s:%d", session_name, w.index)
          vim.schedule(function()
            tmux.attach(target.name, spec, "vertical")
          end)
        end,
        tmux_hsplit = function(picker, item)
          picker:close()
          if not item then return end
          local w = item.window
          local spec = string.format("%s:%d", session_name, w.index)
          vim.schedule(function()
            tmux.attach(target.name, spec, "horizontal")
          end)
        end,
        tmux_tab = function(picker, item)
          picker:close()
          if not item then return end
          local w = item.window
          local spec = string.format("%s:%d", session_name, w.index)
          vim.schedule(function()
            tmux.attach(target.name, spec, "tab")
          end)
        end,
      },
      win = {
        input = {
          keys = {
            ["<c-v>"] = { "tmux_vsplit", desc = "Attach in Vertical Split" },
            ["<c-s>"] = { "tmux_hsplit", desc = "Attach in Horizontal Split" },
            ["<c-t>"] = { "tmux_tab", desc = "Attach in New Tab" },
          },
        },
      },
      confirm = function(picker, item)
        picker:close()
        if not item then return end
        local w = item.window
        local spec = string.format("%s:%d", session_name, w.index)
        vim.schedule(function()
          tmux.attach(target.name, spec, "float")
        end)
      end,
    })
  else
    local items = {}
    for _, w in ipairs(windows) do
      table.insert(items, {
        label = string.format("[%d] %s (%d panes)%s", w.index, w.name, w.panes, w.is_active and " [active]" or ""),
        spec = string.format("%s:%d", session_name, w.index),
      })
    end
    vim.ui.select(items, {
      prompt = string.format("Select Window in '%s' to Attach:", session_name),
      format_item = function(item) return item.label end,
    }, function(choice)
      if choice then
        tmux.attach(target.name, choice.spec, "float")
      end
    end)
  end
end

---Open interactive tmux session manager
---@param target_name? string
function M.open(target_name)
  local current_target = target_name or tmux.active_target
  if _G.Snacks and Snacks.picker then
    M.open_snacks(current_target)
  else
    M.open_select(current_target)
  end
end

---Open Tmux picker using Snacks.picker with rich dual-window preview & capture-pane
---@param target_name? string
function M.open_snacks(target_name)
  local current_target = target_name or tmux.active_target
  local target = tmux.get_target(current_target)
  local sessions, err = tmux.list_sessions(target.name)

  local items = {}

  for idx, s in ipairs(sessions) do
    local search_text = string.format("%s %s %d windows %s", s.name, target.name, s.windows, s.is_attached and "attached" or "detached")
    table.insert(items, {
      idx = idx,
      score = idx,
      text = search_text,
      session = s,
      target = target,
      is_action = false,
    })
  end

  -- Action items
  local actions = {
    {
      id = "__project_session__",
      title = "🚀 [Projects / Zoxide] Instant Session from Workspace / Zoxide",
      desc = "Search projects across ~/git, ~/projects, or zoxide and create/attach instantly",
    },
    {
      id = "__new_session__",
      title = string.format("➕ [New Session] Create & Attach on [%s]", target.name),
      desc = string.format("Spawns a new tmux session on target '%s' and attaches immediately", target.name),
    },
    {
      id = "__switch_target__",
      title = string.format("🔄 [Switch Target/VM] Current: [%s] (%s)", target.name, target.desc),
      desc = "Switch target environment (local machine, WSL distro, remote SSH host, or add new target)",
    },
    {
      id = "__add_target__",
      title = "➕ [Add Target] Configure New WSL Distro / SSH VM",
      desc = "Register a new WSL distro name or SSH VM host for instant Tmux session management",
    },
  }

  for _, a in ipairs(actions) do
    table.insert(items, {
      idx = #items + 1,
      score = 200 + #items,
      text = a.title,
      action = a,
      target = target,
      is_action = true,
    })
  end

  local function do_attach(item, layout)
    if not item then return end
    if item.is_action then
      local a = item.action
      if a.id == "__project_session__" then
        vim.schedule(function() M.open_project_picker(target.name) end)
      elseif a.id == "__new_session__" then
        M.prompt_new_session(target.name)
      elseif a.id == "__switch_target__" then
        vim.schedule(function()
          M.switch_target_picker(function(new_tgt) M.open(new_tgt) end)
        end)
      elseif a.id == "__add_target__" then
        vim.schedule(function()
          M.prompt_add_target(function(new_tgt) M.open(new_tgt) end)
        end)
      end
      return
    end

    local s = item.session
    local t = item.target
    vim.schedule(function()
      tmux.attach(t.name, s.name, layout or "float")
    end)
  end

  Snacks.picker({
    title = string.format(" 🪟 Tmux Sessions [%s: %s] ", target.name, target.desc),
    items = items,
    actions = {
      tmux_vsplit = function(picker, item)
        picker:close()
        do_attach(item, "vertical")
      end,
      tmux_hsplit = function(picker, item)
        picker:close()
        do_attach(item, "horizontal")
      end,
      tmux_tab = function(picker, item)
        picker:close()
        do_attach(item, "tab")
      end,
      tmux_kill = function(picker, item)
        if item and not item.is_action then
          picker:close()
          M.prompt_kill_session(item.target.name, item.session.name)
        end
      end,
      tmux_rename = function(picker, item)
        if item and not item.is_action then
          picker:close()
          M.prompt_rename_session(item.target.name, item.session.name)
        end
      end,
      tmux_new_win = function(picker, item)
        if item and not item.is_action then
          picker:close()
          M.prompt_new_window(item.target.name, item.session.name)
        end
      end,
      tmux_windows = function(picker, item)
        if item and not item.is_action then
          picker:close()
          vim.schedule(function()
            M.open_windows_picker(item.target.name, item.session.name)
          end)
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-v>"] = { "tmux_vsplit", desc = "Attach in Vertical Split" },
          ["<c-s>"] = { "tmux_hsplit", desc = "Attach in Horizontal Split" },
          ["<c-t>"] = { "tmux_tab", desc = "Attach in New Tab" },
          ["<c-x>"] = { "tmux_kill", desc = "Kill Session" },
          ["<c-r>"] = { "tmux_rename", desc = "Rename Session" },
          ["<c-n>"] = { "tmux_new_win", desc = "New Window in Session" },
          ["<c-w>"] = { "tmux_windows", desc = "Drill Down into Windows" },
        },
      },
    },
    format = function(item)
      if item.is_action then
        return {
          { " " .. item.action.title, "Function" },
        }
      end

      local s = item.session
      local state_icon = s.is_attached and "🟢" or "⚪"
      local attach_label = s.is_attached and "[attached]" or "[detached]"
      local win_label = string.format("(%d win)", s.windows)

      return {
        { state_icon .. " ", "Normal" },
        { s.name .. " ", "Title" },
        { win_label .. " ", "Keyword" },
        { attach_label .. " ", s.is_attached and "DiagnosticOk" or "Comment" },
        { s.created ~= "" and (" ⏱️ " .. s.created) or "", "DiagnosticInfo" },
      }
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

      local s = ctx.item.session
      local t = ctx.item.target
      local lines = {}

      table.insert(lines, "╭─────────────────────────────────────────────────────────────╮")
      table.insert(lines, string.format("│ 🪟 Session: %-25s Target: %-18s │", s.name, t.name))
      table.insert(lines, string.format("│ 🖥️  Host Type: %-23s Status: %-18s │",
        t.type:upper(), s.is_attached and "Attached" or "Detached"))
      if t.distro then
        table.insert(lines, string.format("│ 🐧 WSL Distro: %-44s │", t.distro))
      elseif t.host then
        table.insert(lines, string.format("│ 🌐 SSH Host: %-46s │", t.host))
      end
      if s.created and s.created ~= "" then
        table.insert(lines, string.format("│ 🕒 Created: %-47s │", s.created))
      end
      table.insert(lines, string.format("│ 📑 Total Windows: %-41d │", s.windows))
      table.insert(lines, "╰─────────────────────────────────────────────────────────────╯")
      table.insert(lines, "")

      -- Query windows list
      local windows = tmux.list_windows(t.name, s.name)
      if #windows > 0 then
        table.insert(lines, string.format("--- Active Windows in '%s' (%d windows) ---", s.name, #windows))
        for _, w in ipairs(windows) do
          local active_mark = w.is_active and "▶ " or "  "
          local active_badge = w.is_active and " [active]" or ""
          local pane_info = string.format("(%d pane%s)", w.panes, w.panes > 1 and "s" or "")
          table.insert(lines, string.format(" %s[%d] %-20s %s%s", active_mark, w.index, w.name, pane_info, active_badge))
        end
        table.insert(lines, "")
      end

      -- Live Screen Capture (capture-pane)
      local live_screen = tmux.capture_pane(t.name, s.name, 35)
      table.insert(lines, "─── Live Terminal Output (Active Pane) ────────────────────────")
      table.insert(lines, "")
      if #live_screen > 0 then
        for _, l in ipairs(live_screen) do
          table.insert(lines, l)
        end
      else
        table.insert(lines, "  [No live terminal output captured or pane idle]")
      end

      table.insert(lines, "")
      table.insert(lines, "───────────────────────────────────────────────────────────────")
      table.insert(lines, "  Keybindings:")
      table.insert(lines, "    <CR>  : Attach in Float          <C-v> : Attach in Vertical Split")
      table.insert(lines, "    <C-s> : Attach in H-Split        <C-t> : Attach in New Tab")
      table.insert(lines, "    <C-w> : Drill into Windows       <C-r> : Rename Session")
      table.insert(lines, "    <C-n> : Add New Window           <C-x> : Kill Session")
      table.insert(lines, "    Ctrl+b d : Inside session, cleanly detach & return to Neovim")

      ctx.preview:set_lines(lines)
    end,
    confirm = function(picker, item)
      picker:close()
      do_attach(item, "float")
    end,
  })
end

---Fallback session selector using vim.ui.select
---@param target_name? string
function M.open_select(target_name)
  local current_target = target_name or tmux.active_target
  local target = tmux.get_target(current_target)
  local sessions, err = tmux.list_sessions(target.name)

  local items = {}

  for _, s in ipairs(sessions) do
    local state_icon = s.is_attached and "🟢" or "⚪"
    local label = string.format("%s %s (%d windows) %s",
      state_icon, s.name, s.windows, s.is_attached and "[attached]" or "[detached]")
    table.insert(items, {
      label = label,
      session = s,
      target = target,
    })
  end

  table.insert(items, {
    label = "🚀 [Projects / Zoxide] Instant Session from Workspace / Zoxide",
    action = "project",
  })
  table.insert(items, {
    label = string.format("➕ [New Session] Create on [%s]", target.name),
    action = "new",
  })
  table.insert(items, {
    label = string.format("🔄 [Switch Target/VM] Current: [%s]", target.name),
    action = "switch",
  })
  table.insert(items, {
    label = "➕ [Add Target] Configure New WSL Distro / SSH VM",
    action = "add",
  })

  vim.ui.select(items, {
    prompt = string.format("Tmux Sessions [%s: %s]:", target.name, target.desc),
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end

    if choice.action == "project" then
      M.open_project_picker(target.name)
    elseif choice.action == "new" then
      M.prompt_new_session(target.name)
    elseif choice.action == "switch" then
      M.switch_target_picker(function(new_tgt)
        M.open(new_tgt)
      end)
    elseif choice.action == "add" then
      M.prompt_add_target(function(new_tgt)
        M.open(new_tgt)
      end)
    elseif choice.session then
      tmux.attach(choice.target.name, choice.session.name)
    end
  end)
end

return M
