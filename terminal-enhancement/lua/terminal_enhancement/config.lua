local M = {}

---@class TermEnhanceOptions
---@field direction "float"|"horizontal"|"vertical" Default terminal direction
---@field float_opts table Floating window geometry (width, height, border)
---@field split_size table Split size ratios
---@field auto_insert boolean Enter insert mode automatically on terminal open
---@field clean_buffer boolean Disable numbers, signcolumn, foldcolumn in term buffers
---@field smart_navigation boolean Enable <Esc><Esc> and <C-h/j/k/l> terminal navigation
---@field smart_link_resolver boolean Enable smart click, <CR>, and gf file/URL resolution
---@field bracketed_paste boolean Wrap dispatched commands in bracketed paste escape codes
---@field auto_dedent boolean Auto dedent multi-line code blocks
---@field shell_continuation "auto"|"bash"|"powershell"
---@field markdown table Markdown prompt stripping and extraction options
---@field highlight table Flash highlight feedback on sent ranges
---@field history table Execution outcome recording & clipboard sync
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
    horizontal = 15,
    vertical = 60,
  },
  auto_insert = true,
  clean_buffer = true,
  smart_navigation = true,
  smart_link_resolver = true,
  bracketed_paste = true,
  auto_dedent = true,
  auto_newline = true,
  shell_continuation = "auto", -- "auto" (detects bash/zsh vs pwsh), "bash" (\), "powershell" (`)

  -- Terminal Lower Status Bar
  status_bar = {
    enabled = true,
    show_line_info = true,
    show_shell_badge = true,
  },
  sticky_scroll = {
    enabled = false, -- Sticky winbar disabled to prevent flickering
  },

  -- Fish-like Ghost Text & Autocomplete
  autocomplete = {
    enabled = true,
    ghost_text = true,
  },

  -- Markdown & Prompt Extraction Engine
  markdown = {
    strip_prompts = true,          -- Automatically strip `$ `, `PS >`, `>>> `, `... ` prompts
    filter_output_lines = true,    -- Filter out tutorial output lines in mixed markdown code blocks
    prefer_inline = true,          -- Prefer executing inline `cmd` when cursor is on it
    strip_comments = false,        -- Strip comment lines from execution
  },

  -- Visual flash highlight feedback
  highlight = {
    enabled = true,
    hl_group = "IncSearch",
    duration = 150,
  },

  -- Outcome Recording & History Engine
  history = {
    enabled = true,
    max_entries = 100,
    capture_output = true,
    capture_timeout = 800,
    copy_output_to_clipboard = true,  -- Automatically copy terminal outcome to clipboard
    notify_on_copy = true,
    paste_output_to_buffer = false,   -- Automatically paste outcome below command as comment
    comment_prefix = nil,             -- Auto-detected by language (#, --, //)
  },

  tools = {
    lazygit = { cmd = "lazygit", direction = "float", desc = "LazyGit GUI" },
    htop = { cmd = "htop", direction = "float", desc = "Process Monitor (htop)" },
    agy = { cmd = "agy", direction = "float", desc = "Antigravity AI Agent CLI" },
    leaf = { cmd = "leaf -w %", direction = "float", desc = "Leaf Markdown Reader (Watch Mode)" },
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
