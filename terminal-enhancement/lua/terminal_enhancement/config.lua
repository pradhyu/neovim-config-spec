local M = {}

---@class TermEnhanceOptions
---@field direction "float"|"horizontal"|"vertical" Default terminal direction
---@field float_opts table Floating window geometry (width, height, border)
---@field split_size table Split size ratios
---@field auto_insert boolean Enter insert mode automatically on terminal open
---@field clean_buffer boolean Disable numbers, signcolumn, foldcolumn in term buffers
---@field smart_navigation boolean Enable <Esc><Esc> and <C-h/j/k/l> terminal navigation
---@field smart_link_resolver boolean Enable smart click, <CR>, and gf file/URL resolution
---@field tools table<string, { cmd: string, direction?: string, desc?: string }>

M.defaults = {
  direction = "float",
  float_opts = {
    width = 0.85,
    height = 0.80,
    border = "rounded",
    title = " Terminal ",
    title_pos = "center",
  },
  split_size = {
    horizontal = 15, -- 15 lines height
    vertical = 60,   -- 60 columns width
  },
  auto_insert = true,
  clean_buffer = true,
  smart_navigation = true,
  smart_link_resolver = true,
  bracketed_paste = true,
  auto_dedent = true,
  shell_continuation = "auto", -- "auto" (detects bash/zsh vs pwsh), "bash" (\), "powershell" (`)
  tools = {
    lazygit = { cmd = "lazygit", direction = "float", desc = "LazyGit GUI" },
    htop = { cmd = "htop", direction = "float", desc = "Process Monitor (htop)" },
    agy = { cmd = "agy", direction = "float", desc = "Antigravity AI Agent CLI" },
    python = { cmd = "python3", direction = "horizontal", desc = "Python Interactive REPL" },
    node = { cmd = "node", direction = "horizontal", desc = "Node.js Interactive REPL" },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
  return M.options
end

return M
