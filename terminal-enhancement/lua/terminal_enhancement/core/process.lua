local uv = vim.uv or vim.loop
local config = require("terminal_enhancement.config")

local M = {}

-- Standard POSIX Signal map
M.SIGNALS = {
  SIGHUP = 1,
  SIGINT = 2,
  SIGQUIT = 3,
  SIGKILL = 9,
  SIGUSR1 = 10,
  SIGUSR2 = 12,
  SIGTERM = 15,
  SIGSTOP = 19,
  SIGCONT = 18,
}

---Normalize signal representation into integer
---@param sig? string|integer
---@return integer
function M.normalize_signal(sig)
  if type(sig) == "number" then
    return sig
  end
  if not sig or sig == "" then
    return 15 -- SIGTERM default
  end

  local s = tostring(sig):upper():gsub("^SIG", "")
  local full = "SIG" .. s
  if M.SIGNALS[full] then
    return M.SIGNALS[full]
  end

  local num = tonumber(sig)
  if num then
    return num
  end

  return 15
end

---Safely read entire contents of a file
---@param path string
---@return string?
local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

---Check if a process is still alive
---@param pid integer
---@return boolean
function M.is_alive(pid)
  if not pid or pid <= 0 then
    return false
  end
  -- Signal 0 checks for existence without sending any actual signal
  local res, err = uv.kill(pid, 0)
  return res == 0 or err == "EPERM"
end

---Safely resolve terminal channel/job ID from table or buffer number
---@param inst_or_buf? table|integer
---@return integer?
local function resolve_channel(inst_or_buf)
  if type(inst_or_buf) == "table" then
    if inst_or_buf.job_id and inst_or_buf.job_id > 0 then
      return inst_or_buf.job_id
    end
    if inst_or_buf.buf and vim.api.nvim_buf_is_valid(inst_or_buf.buf) then
      local c = vim.bo[inst_or_buf.buf].channel
      if c and c > 0 then return c end
      local b_chan = vim.b[inst_or_buf.buf].terminal_job_id
      if b_chan and b_chan > 0 then return b_chan end
    end
  elseif type(inst_or_buf) == "number" and vim.api.nvim_buf_is_valid(inst_or_buf) then
    local c = vim.bo[inst_or_buf].channel
    if c and c > 0 then return c end
    local b_chan = vim.b[inst_or_buf].terminal_job_id
    if b_chan and b_chan > 0 then return b_chan end
  end
  return nil
end

---Detect shell type for a terminal instance, buffer, or command
---@param inst_or_buf? table|integer|string
---@return "powershell"|"bash"|"zsh"|"fish"
function M.detect_shell_type(inst_or_buf)
  -- 1. Check user preference override if configured
  local custom_pref = config.options and config.options.shell_continuation
  if custom_pref == "powershell" or custom_pref == "pwsh" then
    return "powershell"
  end

  local target_pid = nil
  local cmd_hint = nil

  if type(inst_or_buf) == "table" then
    cmd_hint = inst_or_buf.cmd
    local chan = resolve_channel(inst_or_buf)
    if chan then
      local ok_pid, pid = pcall(vim.fn.jobpid, chan)
      if ok_pid and pid and pid > 0 then target_pid = pid end
    end
  elseif type(inst_or_buf) == "number" and vim.api.nvim_buf_is_valid(inst_or_buf) then
    local chan = resolve_channel(inst_or_buf)
    if chan then
      local ok_pid, pid = pcall(vim.fn.jobpid, chan)
      if ok_pid and pid and pid > 0 then target_pid = pid end
    end
  elseif type(inst_or_buf) == "string" then
    cmd_hint = inst_or_buf
  end

  -- 2. Inspect running root process /proc/<pid>/comm or cmdline if pid is available
  if target_pid and target_pid > 0 then
    local comm = read_file(string.format("/proc/%d/comm", target_pid))
    if comm then
      comm = vim.trim(comm):lower()
      if comm:match("pwsh") or comm:match("powershell") then
        return "powershell"
      elseif comm:match("zsh") then
        return "zsh"
      elseif comm:match("fish") then
        return "fish"
      elseif comm:match("bash") or comm:match("sh") then
        return "bash"
      end
    end

    local cmdline = read_file(string.format("/proc/%d/cmdline", target_pid))
    if cmdline then
      cmdline = cmdline:lower()
      if cmdline:match("pwsh") or cmdline:match("powershell") then
        return "powershell"
      elseif cmdline:match("zsh") then
        return "zsh"
      elseif cmdline:match("fish") then
        return "fish"
      elseif cmdline:match("bash") then
        return "bash"
      end
    end
  end

  -- 3. Check cmdline hint
  cmd_hint = (cmd_hint or vim.o.shell or ""):lower()
  if cmd_hint:match("pwsh") or cmd_hint:match("powershell") then
    return "powershell"
  elseif cmd_hint:match("zsh") then
    return "zsh"
  elseif cmd_hint:match("fish") then
    return "fish"
  end

  return "bash"
end

---Get root shell PID for a terminal instance or buffer
---@param inst_or_buf? table|integer
---@return integer?
function M.get_terminal_pid(inst_or_buf)
  local chan = resolve_channel(inst_or_buf)
  if chan and chan > 0 then
    local ok_pid, pid = pcall(vim.fn.jobpid, chan)
    if ok_pid and pid and pid > 0 then
      return pid
    end
  end
  return nil
end

---Get direct child PIDs of a given process
---@param pid integer
---@return integer[]
function M.get_direct_children(pid)
  if not pid or pid <= 0 then
    return {}
  end

  local children = {}
  local seen = {}

  -- 1. Check all thread tasks in /proc/<pid>/task/*/children (handles multi-threaded CLR/JVM/Rust runtimes)
  local task_dir = string.format("/proc/%d/task", pid)
  local handle = uv.fs_scandir(task_dir)
  if handle then
    while true do
      local name, _ = uv.fs_scandir_next(handle)
      if not name then break end
      local content = read_file(string.format("/proc/%d/task/%s/children", pid, name))
      if content and content ~= "" then
        for c in content:gmatch("%d+") do
          local c_num = tonumber(c)
          if c_num and not seen[c_num] then
            seen[c_num] = true
            table.insert(children, c_num)
          end
        end
      end
    end
  end

  -- 2. Fallback to pgrep -P <pid>
  if #children == 0 then
    local ok, pgrep_out = pcall(vim.fn.system, { "pgrep", "-P", tostring(pid) })
    if ok and vim.v.shell_error == 0 and pgrep_out and pgrep_out ~= "" then
      for line in pgrep_out:gmatch("%d+") do
        local c_num = tonumber(line)
        if c_num and not seen[c_num] then
          seen[c_num] = true
          table.insert(children, c_num)
        end
      end
    end
  end

  return children
end

---Get detailed process information
---@param pid integer
---@return { pid: integer, ppid: integer, comm: string, cmdline: string }?
function M.get_process_info(pid)
  if not pid or pid <= 0 or not M.is_alive(pid) then
    return nil
  end

  local comm = read_file(string.format("/proc/%d/comm", pid))
  comm = comm and vim.trim(comm) or "unknown"

  local cmdline_raw = read_file(string.format("/proc/%d/cmdline", pid))
  local cmdline = ""
  if cmdline_raw then
    cmdline = cmdline_raw:gsub("%z", " "):gsub("%s+$", "")
  end
  if cmdline == "" then
    cmdline = comm
  end

  local ppid = 0
  local stat = read_file(string.format("/proc/%d/stat", pid))
  if stat then
    local ppid_str = stat:match("%d+%s+%([^%)]+%)%s+%a%s+(%d+)")
    if ppid_str then
      ppid = tonumber(ppid_str) or 0
    end
  end

  return {
    pid = pid,
    ppid = ppid,
    comm = comm,
    cmdline = cmdline,
  }
end

---Recursively traverse and return the entire process tree starting from root_pid
---@param root_pid integer
---@return table[] list of process info tables { pid, ppid, comm, cmdline }
function M.get_process_tree(root_pid)
  if not root_pid or root_pid <= 0 then
    return {}
  end

  local tree = {}
  local queue = { root_pid }
  local seen = {}

  while #queue > 0 do
    local curr = table.remove(queue, 1)
    if not seen[curr] then
      seen[curr] = true
      local info = M.get_process_info(curr)
      if info then
        table.insert(tree, info)
      end
      local children = M.get_direct_children(curr)
      for _, child in ipairs(children) do
        if not seen[child] then
          table.insert(queue, child)
        end
      end
    end
  end

  return tree
end

---Get the active foreground child process of a terminal (non-shell command currently executing)
---@param inst_or_buf? table|integer
---@return { pid: integer, comm: string, cmdline: string }?
function M.get_foreground_process(inst_or_buf)
  local root_pid = M.get_terminal_pid(inst_or_buf)
  if not root_pid then
    return nil
  end

  local tree = M.get_process_tree(root_pid)
  if #tree <= 1 then
    return nil -- Only shell itself is running
  end

  -- Return the deepest descendant that is not a shell
  for i = #tree, 2, -1 do
    local proc = tree[i]
    local comm = proc.comm:lower()
    if not comm:match("bash") and not comm:match("zsh") and not comm:match("pwsh") and not comm:match("fish") and not comm:match("sh") then
      return proc
    end
  end

  return tree[#tree]
end

---Parse system listening ports and return list of { port: integer, proto: string, pid: integer?, comm: string? }
---@param filter_pids? table<integer, boolean> optional PID lookup set
---@return table[]
function M.get_listening_ports(filter_pids)
  local ports = {}
  local seen_keys = {}

  -- 1. Try ss -tulpnH
  local ok, ss_out = pcall(vim.fn.system, { "ss", "-tulpnH" })
  if ok and ss_out and ss_out ~= "" then
    for line in ss_out:gmatch("[^\r\n]+") do
      local proto = line:match("^([TU][%a%d]+)") or "tcp"
      proto = proto:lower():match("udp") and "udp" or "tcp"

      -- Match local port from column 4 (e.g. 127.0.0.1:8080, [::]:3000, *:5000)
      local port_str = line:match(":(%d+)%s+")
      local port = tonumber(port_str)

      if port then
        -- Match users:(("comm",pid=123,fd=4),...)
        local pids = {}
        for comm, pid_str in line:gmatch('"([^"]+)",pid=(%d+)') do
          local p = tonumber(pid_str)
          if p then
            table.insert(pids, { pid = p, comm = comm })
          end
        end

        if #pids == 0 then
          -- Process info without quotes: pid=123
          for pid_str in line:gmatch("pid=(%d+)") do
            local p = tonumber(pid_str)
            if p then
              table.insert(pids, { pid = p, comm = "unknown" })
            end
          end
        end

        if #pids > 0 then
          for _, proc in ipairs(pids) do
            if not filter_pids or filter_pids[proc.pid] then
              local key = string.format("%s:%d:%d", proto, port, proc.pid)
              if not seen_keys[key] then
                seen_keys[key] = true
                table.insert(ports, {
                  port = port,
                  proto = proto,
                  pid = proc.pid,
                  comm = proc.comm,
                })
              end
            end
          end
        elseif not filter_pids then
          local key = string.format("%s:%d:0", proto, port)
          if not seen_keys[key] then
            seen_keys[key] = true
            table.insert(ports, {
              port = port,
              proto = proto,
              pid = nil,
              comm = nil,
            })
          end
        end
      end
    end
    return ports
  end

  return ports
end

---Get all listening ports opened by processes in a specific terminal's process tree
---@param inst_or_buf? table|integer
---@return table[]
function M.get_terminal_ports(inst_or_buf)
  local root_pid = M.get_terminal_pid(inst_or_buf)
  if not root_pid then
    return {}
  end

  local tree = M.get_process_tree(root_pid)
  local pid_set = {}
  for _, proc in ipairs(tree) do
    pid_set[proc.pid] = true
  end

  return M.get_listening_ports(pid_set)
end

---Find all processes listening on a given port (TCP or UDP)
---@param port integer
---@param proto? "tcp"|"udp"
---@return table[] list of { pid: integer, comm: string }
function M.find_processes_on_port(port, proto)
  local p_num = tonumber(port)
  if not p_num then
    return {}
  end
  local protocol = proto or "tcp"
  local results = {}
  local seen = {}

  -- 1. Try fuser <port>/tcp or <port>/udp
  local ok, fuser_out = pcall(vim.fn.system, { "fuser", string.format("%d/%s", p_num, protocol) })
  if ok and fuser_out and fuser_out ~= "" then
    for pid_str in fuser_out:gmatch("(%d+)") do
      local p = tonumber(pid_str)
      if p and p ~= p_num and not seen[p] and M.is_alive(p) then
        seen[p] = true
        local info = M.get_process_info(p)
        table.insert(results, {
          pid = p,
          comm = info and info.comm or "process",
        })
      end
    end
  end

  -- 2. Check ss as reinforcement
  if #results == 0 then
    local ss_ports = M.get_listening_ports()
    for _, item in ipairs(ss_ports) do
      if item.port == p_num and item.pid and not seen[item.pid] and M.is_alive(item.pid) then
        seen[item.pid] = true
        table.insert(results, {
          pid = item.pid,
          comm = item.comm or "process",
        })
      end
    end
  end

  return results
end

---Send a signal to a process using native libuv with fallback to system kill
---@param pid integer
---@param signal? string|integer
---@return boolean, string
function M.send_signal(pid, signal)
  if not pid or pid <= 0 then
    return false, "Invalid PID"
  end

  local sig_num = M.normalize_signal(signal)

  -- Direct libuv kill (zero external process overhead)
  local res, err = uv.kill(pid, sig_num)
  if res == 0 then
    return true, string.format("Signal %d sent to PID %d", sig_num, pid)
  end

  -- Fallback to system kill command
  local ok = pcall(vim.fn.system, { "kill", "-" .. sig_num, tostring(pid) })
  if ok and vim.v.shell_error == 0 then
    return true, string.format("System kill -%d executed for PID %d", sig_num, pid)
  end

  return false, string.format("Failed to signal PID %d: %s", pid, err or "unknown error")
end

---Send interrupt (SIGINT / Ctrl+C) to a terminal
---@param inst_or_buf? table|integer
---@return boolean, string
function M.send_interrupt(inst_or_buf)
  local chan = nil
  if type(inst_or_buf) == "table" then
    chan = inst_or_buf.job_id or (inst_or_buf.buf and vim.bo[inst_or_buf.buf].channel) or (inst_or_buf.buf and vim.b[inst_or_buf.buf].terminal_job_id)
  elseif type(inst_or_buf) == "number" and vim.api.nvim_buf_is_valid(inst_or_buf) then
    chan = vim.bo[inst_or_buf].channel or vim.b[inst_or_buf].terminal_job_id
  end

  -- Send ETX (\x03, Ctrl+C) into the terminal PTY channel
  if chan and chan > 0 then
    pcall(vim.fn.chansend, chan, "\x03")
  end

  -- Also send SIGINT to foreground child process if one exists
  local fg = M.get_foreground_process(inst_or_buf)
  if fg and fg.pid > 0 then
    M.send_signal(fg.pid, 2) -- SIGINT
    return true, string.format("Sent SIGINT (Ctrl+C) to '%s' (PID %d)", fg.comm, fg.pid)
  end

  return true, "Sent Ctrl+C to terminal"
end

---Kill the entire process tree of a terminal (children first, then root if requested)
---@param inst_or_buf? table|integer
---@param signal? string|integer (default SIGTERM)
---@param kill_shell? boolean (whether to also terminate the root shell, default false)
---@return boolean, string, integer
function M.kill_tree(inst_or_buf, signal, kill_shell)
  local root_pid = M.get_terminal_pid(inst_or_buf)
  if not root_pid then
    return false, "No active terminal process found", 0
  end

  local sig_num = M.normalize_signal(signal or 15)
  local tree = M.get_process_tree(root_pid)
  local killed_count = 0

  -- Signal descendants from leaves to root (skip root_pid if kill_shell is false)
  for i = #tree, 1, -1 do
    local proc = tree[i]
    if proc.pid ~= root_pid or kill_shell then
      local ok = M.send_signal(proc.pid, sig_num)
      if ok then
        killed_count = killed_count + 1
      end
    end
  end

  return true, string.format("Sent signal %d to %d process(es) in tree", sig_num, killed_count), killed_count
end

---Kill any process listening on a specified port, respecting Bash or PowerShell conventions
---@param port integer
---@param signal? string|integer (default SIGTERM / 15)
---@param shell_type? "powershell"|"bash"
---@return boolean, string, table[]
function M.kill_port(port, signal, shell_type)
  local p_num = tonumber(port)
  if not p_num then
    return false, string.format("Invalid port number: '%s'", tostring(port)), {}
  end

  local sig_num = M.normalize_signal(signal or 15)
  local target_shell = shell_type or "bash"

  -- 1. Discover all processes bound to this port
  local procs = M.find_processes_on_port(p_num, "tcp")
  if #procs == 0 then
    -- Also check UDP
    local udp_procs = M.find_processes_on_port(p_num, "udp")
    for _, up in ipairs(udp_procs) do
      table.insert(procs, up)
    end
  end

  -- 2. Deliver signals to discovered processes
  if #procs > 0 then
    for _, p in ipairs(procs) do
      M.send_signal(p.pid, sig_num)
    end
  end

  -- 3. Shell-specific cleanup if needed
  if target_shell == "powershell" then
    local pids_str = {}
    for _, p in ipairs(procs) do
      table.insert(pids_str, tostring(p.pid))
    end
    if #pids_str > 0 and vim.fn.executable("pwsh") == 1 then
      local force_flag = (sig_num == 9) and " -Force" or ""
      pcall(vim.fn.system, {
        "pwsh",
        "-NoProfile",
        "-Command",
        string.format("Stop-Process -Id %s%s -ErrorAction SilentlyContinue", table.concat(pids_str, ","), force_flag),
      })
    end
  else
    -- Fallback to fuser -k
    if vim.fn.executable("fuser") == 1 then
      pcall(vim.fn.system, { "fuser", "-k", string.format("-%d", sig_num), string.format("%d/tcp", p_num) })
    end
  end

  if #procs == 0 then
    -- Even if ss/fuser didn't report pids, still try fuser -k as safety net
    if vim.fn.executable("fuser") == 1 then
      pcall(vim.fn.system, { "fuser", "-k", string.format("-%d", sig_num), string.format("%d/tcp", p_num) })
    end
    return true, string.format("Port %d cleanup command executed (no active PIDs discovered)", p_num), {}
  end

  local proc_desc = {}
  for _, p in ipairs(procs) do
    table.insert(proc_desc, string.format("'%s' (PID %d)", p.comm, p.pid))
  end

  return true, string.format("Killed port %d [%s] with signal %d (%s)", p_num, target_shell, sig_num, table.concat(proc_desc, ", ")), procs
end

---Generate shell-specific command string to kill a port or PID
---@param type "port"|"pid"
---@param target integer
---@param shell_type "powershell"|"bash"
---@param signal? string|integer
---@return string
function M.generate_shell_command(type, target, shell_type, signal)
  local sig = M.normalize_signal(signal or 15)
  if shell_type == "powershell" then
    if type == "port" then
      return string.format("Get-Process -Id (fuser %d/tcp 2>$null) -ErrorAction SilentlyContinue | Stop-Process -Force", target)
    else
      return string.format("Stop-Process -Id %d -Force", target)
    end
  else
    if type == "port" then
      return string.format("fuser -k -%d %d/tcp", sig, target)
    else
      return string.format("kill -%d %d", sig, target)
    end
  end
end

return M
