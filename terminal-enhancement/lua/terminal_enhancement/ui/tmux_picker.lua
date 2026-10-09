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
      vim.ui.input({ prompt = "Target Name / ID (e.g. wsl_ubuntu, wsl_arch): " }, function(name)
        if not name or vim.trim(name) == "" then return end
        name = vim.trim(name)

        vim.ui.input({ prompt = "WSL Distro Name (e.g. Ubuntu, Debian, Arch): " }, function(distro)
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
function M.prompt_new_session(target_name)
  local target = tmux.get_target(target_name)
  vim.ui.input({
    prompt = string.format("New Tmux Session name on [%s]: ", target.name),
    default = "work",
  }, function(name)
    if not name or vim.trim(name) == "" then return end
    name = vim.trim(name)
    tmux.create_session(target.name, name)
  end)
end

---Open interactive tmux session manager
---@param target_name? string
function M.open(target_name)
  local current_target = target_name or tmux.active_target
  local target = tmux.get_target(current_target)

  if _G.Snacks and Snacks.picker then
    M.open_snacks(current_target)
  else
    M.open_select(current_target)
  end
end

---Open Tmux picker using Snacks.picker with rich dual-window preview
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
      id = "__new_session__",
      title = string.format("➕ [New Session] Create & Attach on [%s]", target.name),
      desc = string.format("Spawns a new tmux session on target '%s' and attaches immediately in a Neovim terminal modal", target.name),
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

  Snacks.picker({
    title = string.format(" 🪟 Tmux Sessions [%s: %s] ", target.name, target.desc),
    items = items,
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
          "  Press <CR> to select.",
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

      -- Query windows for this session
      local windows = tmux.list_windows(t.name, s.name)
      if #windows > 0 then
        table.insert(lines, string.format("--- Windows in '%s' (%d windows) ---", s.name, #windows))
        table.insert(lines, "")
        for _, w in ipairs(windows) do
          local active_mark = w.is_active and "▶ " or "  "
          local active_badge = w.is_active and " [active]" or ""
          local pane_info = string.format("(%d pane%s)", w.panes, w.panes > 1 and "s" or "")
          table.insert(lines, string.format(" %s[%d] %-20s %s%s", active_mark, w.index, w.name, pane_info, active_badge))
        end
      else
        table.insert(lines, "  [No active window details returned]")
      end

      table.insert(lines, "")
      table.insert(lines, "───────────────────────────────────────────────────────────────")
      table.insert(lines, "  Keybindings:")
      table.insert(lines, "    <CR>      : Attach to session in Neovim terminal window")
      table.insert(lines, "    <C-x> / d : Kill / Terminate session")
      table.insert(lines, "    Ctrl+b d  : Inside session, detach & cleanly return to Neovim")

      ctx.preview:set_lines(lines)
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end

      if item.is_action then
        local a = item.action
        if a.id == "__new_session__" then
          M.prompt_new_session(target.name)
        elseif a.id == "__switch_target__" then
          vim.schedule(function()
            M.switch_target_picker(function(new_tgt)
              M.open(new_tgt)
            end)
          end)
        elseif a.id == "__add_target__" then
          vim.schedule(function()
            M.prompt_add_target(function(new_tgt)
              M.open(new_tgt)
            end)
          end)
        end
        return
      end

      -- Attach to session
      local s = item.session
      local t = item.target
      vim.schedule(function()
        tmux.attach(t.name, s.name)
      end)
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

    if choice.action == "new" then
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
