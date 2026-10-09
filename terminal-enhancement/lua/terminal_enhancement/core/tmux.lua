local config = require("terminal_enhancement.config")

local M = {}

---Default targets registry
---@type table<string, { name: string, desc: string, type: "local"|"wsl"|"ssh"|"custom", cmd: string[], distro?: string, host?: string, user?: string, port?: integer }>
M.targets = {
  ["local"] = {
    name = "local",
    desc = "Local Host Tmux",
    type = "local",
    cmd = { "tmux" },
  },
  ["wsl"] = {
    name = "wsl",
    desc = "WSL (Default Linux Distro)",
    type = "wsl",
    cmd = vim.fn.has("win32") == 1 and { "wsl.exe", "--", "tmux" } or { "wsl", "--", "tmux" },
  },
}

---Current active target name
M.active_target = "local"

---Initialize targets from user config
function M.setup(opts)
  local tmux_opts = (opts and opts.tmux) or config.options.tmux or {}
  if tmux_opts.default_target then
    M.active_target = tmux_opts.default_target
  elseif vim.fn.has("win32") == 1 then
    M.active_target = "wsl"
  else
    M.active_target = "local"
  end

  if tmux_opts.targets then
    for name, spec in pairs(tmux_opts.targets) do
      M.register_target(name, spec)
    end
  end
end

---Register or update a tmux target (e.g. custom WSL distro, remote SSH VM, container)
---@param name string Unique identifier for target (e.g. 'ubuntu', 'dev_vm', 'cloud_gpu')
---@param spec table Target configuration
function M.register_target(name, spec)
  local target_type = spec.type or "custom"
  local cmd = spec.cmd

  if not cmd then
    if spec.distro then
      target_type = "wsl"
      local wsl_bin = vim.fn.has("win32") == 1 and "wsl.exe" or "wsl"
      cmd = { wsl_bin, "-d", spec.distro, "--", "tmux" }
    elseif spec.host then
      target_type = "ssh"
      local host_str = spec.user and string.format("%s@%s", spec.user, spec.host) or spec.host
      cmd = { "ssh", "-t" }
      if spec.port then
        table.insert(cmd, "-p")
        table.insert(cmd, tostring(spec.port))
      end
      if spec.identity_file then
        table.insert(cmd, "-i")
        table.insert(cmd, vim.fn.expand(spec.identity_file))
      end
      table.insert(cmd, host_str)
      table.insert(cmd, "tmux")
    else
      cmd = { "tmux" }
    end
  end

  M.targets[name] = {
    name = name,
    desc = spec.desc or string.format("Tmux Target [%s]", name),
    type = target_type,
    cmd = cmd,
    distro = spec.distro,
    host = spec.host,
    user = spec.user,
    port = spec.port,
  }
end

---Get list of all configured targets
---@return table[] list of targets
function M.get_targets()
  local list = {}
  for _, t in pairs(M.targets) do
    table.insert(list, t)
  end
  table.sort(list, function(a, b)
    if a.name == "local" then return true end
    if b.name == "local" then return false end
    if a.name == "wsl" then return true end
    if b.name == "wsl" then return false end
    return a.name < b.name
  end)
  return list
end

---Get active target specification
---@param target_name? string
---@return table target
function M.get_target(target_name)
  local name = target_name or M.active_target
  return M.targets[name] or M.targets["local"] or { name = "local", cmd = { "tmux" }, desc = "Local Tmux" }
end

---Set active default target
---@param name string
function M.set_active_target(name)
  if M.targets[name] then
    M.active_target = name
    vim.notify(string.format("[TermEnhance] Active Tmux target switched to '%s' (%s)", name, M.targets[name].desc), vim.log.levels.INFO)
    return true
  end
  return false
end

---Build full command line with arguments for a target
---@param target_name string?
---@param args string[]
---@return string[]
local function build_cmd(target_name, args)
  local target = M.get_target(target_name)
  local full = vim.deepcopy(target.cmd)
  for _, a in ipairs(args) do
    table.insert(full, a)
  end
  return full
end

---Query active tmux sessions for a target
---@param target_name? string
---@return table[] list of { name: string, windows: integer, is_attached: boolean, created: string, target: string }
---@return string? error_msg
function M.list_sessions(target_name)
  local target = M.get_target(target_name)
  local cmd = build_cmd(target.name, {
    "list-sessions",
    "-F",
    "#{session_name}:#{session_windows}:#{session_attached}:#{session_created}",
  })

  local ok, out = pcall(vim.fn.system, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    local err = vim.trim(out or "Tmux server not running or host unreachable")
    return {}, err
  end

  local sessions = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local s_name, s_windows, s_attached, s_created = line:match("([^:]+):(%d+):(%d+):(%d+)")
    if s_name then
      local created_date = ""
      if s_created then
        local ts = tonumber(s_created)
        if ts then
          created_date = os.date("%Y-%m-%d %H:%M", ts)
        end
      end

      table.insert(sessions, {
        name = s_name,
        windows = tonumber(s_windows) or 1,
        is_attached = (s_attached == "1"),
        created = created_date,
        target = target.name,
      })
    end
  end

  return sessions, nil
end

---Query windows for a specific tmux session
---@param target_name string?
---@param session_name string
---@return table[] list of { index: integer, name: string, is_active: boolean, panes: integer }
function M.list_windows(target_name, session_name)
  local target = M.get_target(target_name)
  local cmd = build_cmd(target.name, {
    "list-windows",
    "-t",
    session_name,
    "-F",
    "#{window_index}:#{window_name}:#{window_active}:#{window_panes}",
  })

  local ok, out = pcall(vim.fn.system, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    return {}
  end

  local windows = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local w_idx, w_name, w_active, w_panes = line:match("(%d+):([^:]*):(%d+):(%d+)")
    if w_idx then
      table.insert(windows, {
        index = tonumber(w_idx) or 0,
        name = w_name,
        is_active = (w_active == "1"),
        panes = tonumber(w_panes) or 1,
      })
    end
  end

  return windows
end

---Attach to a tmux session in a Neovim terminal window (float, split, or tab)
---@param target_name string?
---@param session_name string
---@param layout? "float"|"horizontal"|"vertical"|"tab"
function M.attach(target_name, session_name, layout)
  local target = M.get_target(target_name)
  local attach_cmd = build_cmd(target.name, { "attach-session", "-t", session_name })
  local win_title = string.format(" Tmux [%s]: %s ", target.name, session_name)

  layout = layout or (config.options.tmux and config.options.tmux.layout) or "float"

  if layout == "float" then
    -- Open in centered floating modal window
    local width = math.floor(vim.o.columns * 0.90)
    local height = math.floor(vim.o.lines * 0.85)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = win_title,
      title_pos = "center",
    })

    vim.fn.termopen(attach_cmd, {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
        vim.notify(string.format("[TermEnhance] Detached from Tmux session '%s' (%s)", session_name, target.name), vim.log.levels.INFO)
      end,
    })
    vim.cmd("startinsert")
  elseif layout == "horizontal" then
    vim.cmd("botright 15split")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)

    vim.fn.termopen(attach_cmd, {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end,
    })
    vim.cmd("startinsert")
  elseif layout == "vertical" then
    vim.cmd("botright 75vsplit")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)

    vim.fn.termopen(attach_cmd, {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end,
    })
    vim.cmd("startinsert")
  else
    -- Full tab
    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)

    vim.fn.termopen(attach_cmd, {
      on_exit = function()
        pcall(vim.cmd, "tabclose")
      end,
    })
    vim.cmd("startinsert")
  end
end

---Create a new tmux session in target and attach to it
---@param target_name string?
---@param session_name string
---@param layout? "float"|"horizontal"|"vertical"|"tab"
function M.create_session(target_name, session_name, layout)
  local target = M.get_target(target_name)
  local new_cmd = build_cmd(target.name, { "new-session", "-s", session_name })
  local win_title = string.format(" Tmux [%s]: %s (New) ", target.name, session_name)

  layout = layout or (config.options.tmux and config.options.tmux.layout) or "float"

  if layout == "float" then
    local width = math.floor(vim.o.columns * 0.90)
    local height = math.floor(vim.o.lines * 0.85)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = win_title,
      title_pos = "center",
    })

    vim.fn.termopen(new_cmd, {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end,
    })
    vim.cmd("startinsert")
  else
    vim.cmd("botright 15split")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)

    vim.fn.termopen(new_cmd, {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end,
    })
    vim.cmd("startinsert")
  end
end

---Kill a tmux session
---@param target_name string?
---@param session_name string
---@return boolean success, string message
function M.kill_session(target_name, session_name)
  local target = M.get_target(target_name)
  local cmd = build_cmd(target.name, { "kill-session", "-t", session_name })
  local ok, out = pcall(vim.fn.system, cmd)
  if ok and vim.v.shell_error == 0 then
    return true, string.format("Terminated session '%s' on %s", session_name, target.name)
  else
    return false, string.format("Failed to kill session '%s': %s", session_name, vim.trim(out or "error"))
  end
end

return M
