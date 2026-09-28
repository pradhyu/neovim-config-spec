local history = require("terminal_enhancement.core.history")
local config = require("terminal_enhancement.config")

local M = {}

---Cache of loaded shell & project commands
---@type string[]
M.cached_commands = {}
local cache_loaded = false

---Safely read lines from a file
---@param path string
---@param max_lines? integer
---@return string[]
local function read_lines(path, max_lines)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local lines = {}
  local limit = max_lines or 500
  local count = 0
  for line in f:lines() do
    if line and line ~= "" then
      table.insert(lines, line)
      count = count + 1
      if count >= limit then
        break
      end
    end
  end
  f:close()
  return lines
end

---Extract commands from shell history files (~/.zsh_history, ~/.bash_history)
---@return string[]
local function load_shell_history()
  local home = os.getenv("HOME") or ""
  if home == "" then
    return {}
  end

  local cmds = {}
  local seen = {}

  -- 1. Zsh history (: timestamp:0;command)
  local zsh_hist = home .. "/.zsh_history"
  local z_lines = read_lines(zsh_hist, 600)
  for i = #z_lines, 1, -1 do
    local raw = z_lines[i]
    local cmd = raw:match("^: %d+:%d+;(.*)$") or raw
    cmd = vim.trim(cmd)
    if cmd ~= "" and not seen[cmd] and not cmd:match("^\27") then
      seen[cmd] = true
      table.insert(cmds, cmd)
    end
  end

  -- 2. Bash history
  local bash_hist = home .. "/.bash_history"
  local b_lines = read_lines(bash_hist, 400)
  for i = #b_lines, 1, -1 do
    local cmd = vim.trim(b_lines[i])
    if cmd ~= "" and not seen[cmd] and not cmd:match("^#") then
      seen[cmd] = true
      table.insert(cmds, cmd)
    end
  end

  return cmds
end

---Discover project-specific commands (Cargo.toml, package.json, Makefile, etc.)
---@return string[]
local function load_project_commands()
  local cwd = vim.fn.getcwd()
  local cmds = {}
  local seen = {}

  local function add(c)
    if c and c ~= "" and not seen[c] then
      seen[c] = true
      table.insert(cmds, c)
    end
  end

  -- Node / npm / pnpm / yarn / bun
  local pkg_path = cwd .. "/package.json"
  local pkg_file = io.open(pkg_path, "r")
  if pkg_file then
    local content = pkg_file:read("*a")
    pkg_file:close()
    local ok, parsed = pcall(vim.json.decode, content)
    if ok and parsed and parsed.scripts then
      local runner = "npm run"
      if vim.fn.filereadable(cwd .. "/pnpm-lock.yaml") == 1 then
        runner = "pnpm"
      elseif vim.fn.filereadable(cwd .. "/yarn.lock") == 1 then
        runner = "yarn"
      elseif vim.fn.filereadable(cwd .. "/bun.lockb") == 1 or vim.fn.filereadable(cwd .. "/bun.lock") == 1 then
        runner = "bun"
      end

      for script_name, _ in pairs(parsed.scripts) do
        add(string.format("%s %s", runner, script_name))
        add(string.format("npm run %s", script_name))
      end
    end
  end

  -- Rust / Cargo
  if vim.fn.filereadable(cwd .. "/Cargo.toml") == 1 then
    add("cargo build")
    add("cargo check")
    add("cargo test")
    add("cargo test -- --nocapture")
    add("cargo run")
    add("cargo clippy")
    add("cargo fmt --check")
  end

  -- Go
  if vim.fn.filereadable(cwd .. "/go.mod") == 1 then
    add("go test ./...")
    add("go build ./...")
    add("go run main.go")
    add("go vet ./...")
    add("golangci-lint run")
  end

  -- Python
  if vim.fn.filereadable(cwd .. "/pyproject.toml") == 1 or vim.fn.filereadable(cwd .. "/requirements.txt") == 1 then
    add("pytest")
    add("python -m unittest")
    add("ruff check .")
    add("black --check .")
    add("mypy .")
  end

  -- Makefile
  if vim.fn.filereadable(cwd .. "/Makefile") == 1 then
    local mk_lines = read_lines(cwd .. "/Makefile", 200)
    for _, l in ipairs(mk_lines) do
      local target = l:match("^([%w%-_]+):")
      if target and target ~= ".PHONY" then
        add(string.format("make %s", target))
      end
    end
  end

  -- Git common actions
  add("git status")
  add("git diff")
  add("git log --oneline -n 15")
  add("git branch -a")
  add("git pull")
  add("git push")

  return cmds
end

---Populate and refresh command caches
function M.refresh_cache()
  local list = {}
  local seen = {}

  local function add(cmd)
    local c = vim.trim(cmd)
    if c ~= "" and not seen[c] then
      seen[c] = true
      table.insert(list, c)
    end
  end

  -- 1. History from plugin execution records (highest priority)
  for _, entry in ipairs(history.entries) do
    if entry.command and entry.command ~= "" then
      for _, line in ipairs(vim.split(entry.command, "\n")) do
        add(line)
      end
    end
  end

  -- 2. Project commands
  local proj_cmds = load_project_commands()
  for _, c in ipairs(proj_cmds) do
    add(c)
  end

  -- 3. Shell history
  local shell_cmds = load_shell_history()
  for _, c in ipairs(shell_cmds) do
    add(c)
  end

  M.cached_commands = list
  cache_loaded = true
end

---Get auto-completion / fish ghost text suggestion for a given user input prefix
---@param input string Current string typed by user
---@return { suggestion: string|nil, ghost_suffix: string|nil, matches: string[] }
function M.get_suggestion(input)
  if not cache_loaded or #M.cached_commands == 0 then
    M.refresh_cache()
  end

  if not input or input == "" then
    return {
      suggestion = nil,
      ghost_suffix = nil,
      matches = {},
    }
  end

  local prefix = input
  local prefix_lower = input:lower()
  local matches = {}
  local exact_prefix_matches = {}
  local contains_matches = {}

  for _, cmd in ipairs(M.cached_commands) do
    local cmd_lower = cmd:lower()
    if cmd_lower:sub(1, #prefix_lower) == prefix_lower then
      if cmd ~= prefix then
        table.insert(exact_prefix_matches, cmd)
      end
    elseif cmd_lower:find(prefix_lower, 1, true) then
      table.insert(contains_matches, cmd)
    end
  end

  -- Combine: exact prefix matches first, then substring matches
  for _, c in ipairs(exact_prefix_matches) do
    table.insert(matches, c)
  end
  for _, c in ipairs(contains_matches) do
    table.insert(matches, c)
  end

  local best_match = exact_prefix_matches[1]
  local ghost_suffix = nil

  if best_match then
    -- Extract remaining characters after input prefix preserving original casing
    ghost_suffix = best_match:sub(#input + 1)
  end

  return {
    suggestion = best_match,
    ghost_suffix = ghost_suffix,
    matches = matches,
  }
end

---Get next word of ghost text for incremental word-by-word completion (<Alt-Right> / <M-f>)
---@param current_input string
---@param ghost_suffix string
---@return string word_chunk
function M.get_next_word_chunk(current_input, ghost_suffix)
  if not ghost_suffix or ghost_suffix == "" then
    return ""
  end

  -- Grab whitespace plus first alphanumeric/symbol token
  local match = ghost_suffix:match("^(%s*[^%s]+)")
  return match or ghost_suffix:sub(1, 1)
end

return M
