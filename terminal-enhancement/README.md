# ⚡ terminal-enhancement.nvim

> **Modern, intelligent, and seamless terminal workflow suite for Neovim.**  
> High-performance multi-direction terminals, smart link & stacktrace resolution, atomic multi-line code runners, multi-select process termination, and automatic background resource management.

---

## 📑 Table of Contents

- [✨ Core Features](#-core-features)
- [📦 Installation & LazyVim Spec](#-installation--lazyvim-spec)
- [⌨️ Keybindings Quick Reference](#️-keybindings-quick-reference)
- [💻 User Commands](#-user-commands)
- [🚀 Feature Deep Dive](#-feature-deep-dive)
  - [1. Smart Multi-Line Code Execution & Auto-Expansion](#1-smart-multi-line-code-execution--auto-expansion)
  - [2. Multi-Terminal Management & Renaming](#2-multi-terminal-management--renaming)
  - [3. Multi-Select Process Killer & Memory Purge](#3-multi-select-process-killer--memory-purge)
  - [4. Universal Window Quick-Close](#4-universal-window-quick-close)
  - [5. Smart Link & Compiler Error Trace Resolver](#5-smart-link--compiler-error-trace-resolver)
  - [6. Dedicated Tool Launchers](#6-dedicated-tool-launchers)
- [⚙️ Full Configuration Options](#️-full-configuration-options)
- [📄 License](#-license)

---

## ✨ Core Features

* 🪟 **Multi-Direction Windows**: Instant toggling between **Floating popups**, **Horizontal bottom splits**, and **Vertical right splits** with persistent shell jobs.
* 🔗 **Atomic Multi-Line Execution**: Sends multi-line commands as single atomic paste blocks with auto-dedent and terminal **Bracketed Paste** (`\e[200~ ... \e[201~`).
* 🧠 **Smart Multi-Line Auto-Expansion**: Selecting or placing cursor on **any line** of a multi-line command with **`\` (Bash/Zsh)** or **`` ` `` (PowerShell)** automatically captures and executes the entire multi-line command.
* 🏷️ **Dynamic Terminal Renaming**: Give custom names to any active terminal session (`term://<name>`) to organize backend servers, REPLs, and test watchers.
* 🛑 **Multi-Select Process Killer**: Interactive floating manager (`<Space>`, `a`, `h`, `<CR>`) to selectively or batch-terminate background terminal jobs.
* 🧹 **Instant Background Purge**: One-key command to terminate all hidden/background terminals and reclaim PTYs and system memory.
* 🪟 **Universal Quick-Close (`q` / `<C-q>`)**: Consistent single-key window hiding across floats, horizontal splits, and vertical splits.
* 🔎 **Smart Link & Error Trace Resolver**: Intelligent `gf`, `<CR>`, and `<C-LeftMouse>` jump resolver that navigates compiler errors (`file:line:col`), stack traces, GitHub markdown links, `file:///path#L10-L20`, and web URLs.
* 🛠️ **Dedicated Tool Launchers**: Built-in floating runners for `lazygit`, `htop`, `agy` (Antigravity AI Agent CLI), Python interactive REPL, and Node.js.

---

## 📦 Installation & LazyVim Spec

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add the following spec to `~/.config/nvim/lua/plugins/terminal_enhancement.lua` (or your lazy.nvim plugins folder):

```lua
return {
  {
    dir = "/Users/pkshrestha/git/neovim-config/terminal-enhancement", -- or git repo URI
    name = "terminal-enhancement.nvim",
    cmd = {
      "TermToggle",
      "TermFloat",
      "TermSplit",
      "TermTool",
      "TermRun",
      "TermSend",
      "TermSendJoined",
      "TermSelect",
      "TermTarget",
      "TermRename",
      "TermBuffer",
      "TermList",
      "TermKill",
      "TermClean",
      "TermKillHidden",
      "TermKillAll",
      "TermKillPort",
      "TermSignal",
      "TermInterrupt",
      "TermKillTree",
      "TermInfo",
      "TermPicker",
      "TermSwitch",
      "TermFind",
    },
    keys = {
      -- Terminal Toggling & Live Switching
      { "<leader>tt", "<cmd>TermToggle<cr>", desc = "Toggle Terminal (Default)" },
      { "<leader>tl", "<cmd>TermPicker<cr>", desc = "List & Filter Terminals (Switcher)" },
      { "<leader>tf", "<cmd>TermFloat<cr>", desc = "Toggle Floating Terminal" },
      { "<leader>th", "<cmd>TermToggle horizontal<cr>", desc = "Toggle Terminal (Horizontal Split)" },
      { "<leader>tv", "<cmd>TermToggle vertical<cr>", desc = "Toggle Terminal (Vertical Split)" },
      
      -- Code Execution
      { "<leader>ts", "<cmd>TermSend<cr>", mode = { "n", "v" }, desc = "Send Line / Selection (Bracketed Paste)" },
      { "<leader>tS", "<cmd>TermSendJoined<cr>", mode = { "n", "v" }, desc = "Send Lines Joined with \\ or `" },
      
      -- Terminal Management
      { "<leader>tc", "<cmd>TermPicker<cr>", desc = "Select / Switch Target Terminal (Live Filter)" },
      { "<leader>tr", "<cmd>TermRename<cr>", desc = "Rename Terminal" },
      { "<leader>tB", "<cmd>TermBuffer<cr>", desc = "Open Terminal as Regular Buffer" },
      
      -- Process & Port Management (Bash / PowerShell)
      { "<leader>tk", "<cmd>TermKill<cr>", desc = "Process & Port Manager (Interactive)" },
      { "<leader>tp", "<cmd>TermKillPort<cr>", desc = "Kill Process Listening on Port (Bash/PowerShell)" },
      { "<leader>ti", "<cmd>TermInterrupt<cr>", desc = "Send Interrupt (Ctrl+C) to Terminal" },
      { "<leader>tX", "<cmd>TermClean<cr>", desc = "Clean All Hidden Terminals" },
      
      -- Dedicated Tools
      { "<leader>tg", "<cmd>TermTool lazygit<cr>", desc = "LazyGit GUI Terminal" },
      { "<leader>top", "<cmd>TermTool htop<cr>", desc = "htop Process Monitor" },
    },
    opts = {
      direction = "float",
      auto_insert = true,
      clean_buffer = true,
      smart_navigation = true,
      smart_link_resolver = true,
      bracketed_paste = true,
      auto_dedent = true,
      shell_continuation = "auto", -- "auto", "bash" (\), or "powershell" (`)
    },
    config = function(_, opts)
      require("terminal_enhancement").setup(opts)
    end,
  },
}
```

---

## ⌨️ Keybindings Quick Reference

### Global Navigation & Management

| Keybinding | Mode | Action | Description |
| :--- | :--- | :--- | :--- |
| **`<leader>tt`** | Normal | **Toggle Default** | Toggles default persistent floating terminal |
| **`<leader>tl`** | Normal | **Live Filter Switcher** | Opens interactive live-filter fuzzy picker to search and switch terminals |
| **`<leader>tf`** | Normal | **Toggle Float** | Opens centered floating terminal popup |
| **`<leader>th`** | Normal | **Horizontal Split** | Opens/hides persistent horizontal bottom split |
| **`<leader>tv`** | Normal | **Vertical Split** | Opens/hides persistent vertical right split |
| **`<leader>ts`** | Normal / Visual | **Send Code** | Sends current line or selection with Bracketed Paste (auto-expands multi-line commands) |
| **`<leader>tS`** | Normal / Visual | **Send Joined** | Joins multiple lines with `\` (Bash) or `` ` `` (PowerShell) |
| **`<leader>tc`** | Normal | **Select Target** | Live fuzzy filter to select default target terminal for code execution |
| **`<leader>tr`** | Normal | **Rename Terminal** | Prompt to rename active or selected terminal session |
| **`<leader>tk`** | Normal | **Process & Port Manager** | Opens multi-select manager to inspect PIDs, listening ports, send SIGTERM/SIGKILL |
| **`<leader>tp`** | Normal | **Kill Port** | Scans and terminates any process listening on specified port (Bash/PowerShell) |
| **`<leader>ti`** | Normal | **Interrupt** | Sends `Ctrl+C` (SIGINT) to interrupt running foreground process |
| **`<leader>tX`** | Normal | **Clean Hidden** | Instantly purges all background/hidden terminals and frees ports/memory |
| **`<leader>tB`** | Normal | **Buffer Mode** | Opens terminal directly into active window like a normal buffer |
| **`<leader>tg`** | Normal | **LazyGit** | Dedicated LazyGit floating terminal |
| **`<leader>top`** | Normal | **htop** | Dedicated htop process monitor |

### Inside Any Terminal Buffer (Float, Horizontal, Vertical)

| Keybinding | Mode | Action | Description |
| :--- | :--- | :--- | :--- |
| **`q`** | Normal Mode | **Quick Hide** | Hides/closes the terminal window immediately |
| **`<Esc><Esc><Esc>`** | Terminal / Normal Mode | **Quick Hide** | Triple Escape closes the terminal window immediately |
| **`<C-q>`** | Terminal Mode | **Instant Hide** | Hides/closes the terminal window directly without leaving terminal mode |
| **`<C-\><C-n>`** | Terminal Mode | **Normal Mode** | Exits terminal input mode to normal mode for text navigation/yanking |
| **`<C-h/j/k/l>`** | Terminal Mode | **Navigate Window** | Jumps focus to adjacent editor window left/down/up/right |
| **`<CR>`** | Normal Mode on error/path | **Smart Jump** | Resolves stack trace / compiler error under cursor and opens the target file |
| **`gf`** | Normal Mode | **Smart Resolver** | Resolves and jumps to file / URL under cursor |

---

## 💻 User Commands

| Command | Arguments | Description |
| :--- | :--- | :--- |
| **`:TermToggle`** | `[float\|horizontal\|vertical]` | Toggles persistent terminal in specified layout direction. |
| **`:TermFloat`** | — | Opens centered floating terminal. |
| **`:TermSplit`** | `[horizontal\|vertical]` | Opens split terminal (defaults to horizontal). |
| **`:TermBuffer`** | `[id]` | Opens terminal directly into current window as a regular listed buffer. |
| **`:TermTool`** | `<name>` | Opens dedicated tool (`lazygit`, `htop`, `agy`, `python`, `node`). |
| **`:TermRun`** | `<command>` | Runs arbitrary shell command in a dedicated floating terminal. |
| **`:TermSend`** | `[range]` | Sends selection or line to target terminal with Bracketed Paste and dedent. |
| **`:TermSendJoined`**| `[continuation\|and]` | Sends lines joined with line continuations (`\` or `` ` ``) or `&&`. |
| **`:TermSelect`** | — | Interactive selector to switch default target terminal. |
| **`:TermTarget`** | `[id]` | Sets default target terminal ID directly or opens picker. |
| **`:TermRename`** | `[new_name]` | Renames terminal instance, buffer name, and window title. |
| **`:TermList`** | — | Prints status, buffer IDs, PIDs, and visibility of all running terminals. |
| **`:TermClean`** | — | Kills all background/hidden terminal jobs to reclaim memory and PTYs. |
| **`:TermKill`** | `[id\|buf]` | Interactively select terminals to kill, or kill specified terminal ID. |
| **`:TermKillAll`** | — | Kills and terminates all active terminal sessions across Neovim. |

---

## 🚀 Feature Deep Dive

### 1. Smart Multi-Line Code Execution & Auto-Expansion

Sending multi-line commands (like Docker runs, build scripts, or PowerShell pipelines) often fails in standard terminal setups due to premature line execution or line-break formatting corruptions.

#### 🔹 Single-Line Selection Auto-Expansion
If you have a multi-line command in your buffer:
```bash
docker run -d \
  -p 8080:80 \       <-- If you highlight or press <leader>ts on ONLY this line
  -v /data:/data \
  --name my_app \
  nginx:latest
```
* **Normal Mode (`<leader>ts`)**: Pressing `<leader>ts` on **any line** of the command scans upwards and downwards, automatically capturing and executing the **entire 5-line block**.
* **Visual Mode (`V` -> `<leader>ts`)**: Even if you highlight only 1 line (or lines 2–3), it automatically detects the connected `\` or `` ` `` continuations and sends the complete command.

#### 🔹 Cross-Shell Continuation Support
* **Bash / Zsh / POSIX**: Preserves and joins with **`\`**
* **PowerShell (`pwsh`)**: Preserves and joins with **`` ` ``**

#### 🔹 Atomic Bracketed Paste
All multi-line payloads are wrapped in terminal Bracketed Paste sequences (`\e[200~ ... \e[201~`). The shell treats the code block as an atomic clipboard paste, ensuring line 1 is never executed before line 5 arrives.

---

### 2. Multi-Terminal Management & Renaming

Organize separate shells for building, testing, servers, and REPLs:

* **Target Switching (`<leader>tc` / `:TermSelect`)**: Switch which terminal receives `<leader>ts` code dispatches.
* **Renaming (`<leader>tr` / `:TermRename <name>`)**: Rename any terminal at runtime. Updates:
  * Buffer name (`term://api_server`)
  * Floating window title (` Terminal: api_server `)
  * Target selector label
* **First-Class Listed Buffers**: Terminals are registered in `:ls`, bufferline tabs, and Telescope buffer pickers for seamless buffer switching.

---

### 3. Multi-Select Process Killer & Memory Purge

When running test suites or spawning multiple terminals, background processes can accumulate and consume memory.

#### 🔹 Interactive Multi-Select Killer (`<leader>tk` / `:TermKill`)
Opens a floating management window:

```
┌─ 🛑 Kill Terminals (Multi-Select) ──────────────────────────┐
│  Keys: <Space>/<Tab>: toggle | <a>: all | <h>: hidden | <CR>: kill marked | <q>: exit
│ ───────────────────────────────────────────────────────────
│  [ ] 🟢 Terminal: default (Visible in Win #1000, Buf #3) [ACTIVE TARGET]
│  [✔] ⚪ Terminal: worker_1 (Background, Buf #6)
│  [✔] ⚪ Terminal: worker_2 (Background, Buf #7)
│  [ ] ⚪ Terminal: worker_3 (Background, Buf #8)
│ ───────────────────────────────────────────────────────────
│  ➤ 2 of 4 terminal(s) marked for termination
└───────────────────────────────────────────────────────────┘
```

* **`<Space>` / `<Tab>`**: Toggle selection on current line.
* **`h`**: Mark all hidden/background terminals at once.
* **`a`**: Mark/unmark all.
* **`v`**: Invert selection.
* **`<CR>` / `d` / `x`**: Terminate all marked terminals.

#### 🔹 Instant Background Clean (`<leader>tX` / `:TermClean`)
One keystroke kills and purges all hidden/background terminals while keeping visible terminal windows intact.

---

### 4. Universal Window Quick-Close

Unlike standard Neovim terminals where closing split windows requires awkward window commands, `terminal-enhancement.nvim` provides uniform single-key closing:

* **`q`** in Normal Mode (after `<Esc><Esc>`) hides any terminal window (float, horizontal split, or vertical split).
* **`<C-q>`** in Terminal Mode hides the terminal window directly without leaving insert mode.
* Toggling with **`<leader>tt`**, **`<leader>th`**, or **`<leader>tv`** opens if hidden and hides if visible.

---

### 5. Smart Link & Compiler Error Trace Resolver

Navigate compiler output and stack traces instantly:

* **`<CR>` in Normal Mode**: Pressing Enter on an error line jumps directly to the file and line number in your editor.
* **`gf` / `<C-LeftMouse>` Click**: Resolves:
  * Compiler formats (`src/main.rs:42:10`, `index.ts(28,5)`)
  * Python / Go stack traces (`File "/path/to/app.py", line 85`)
  * Markdown links (`[text](file:///path#L10-L20)`)
  * Web URLs (`https://...` opens in system browser)

---

### 6. Dedicated Tool Launchers

Pre-configured floating windows with dedicated styling and sizing:

* **`<leader>tg`**: LazyGit GUI
* **`<leader>top`**: `htop` interactive process monitor
* **`:TermTool agy`**: Google Antigravity AI CLI
* **`:TermTool python`**: Interactive Python REPL
* **`:TermTool node`**: Interactive Node.js REPL

---

## ⚙️ Full Configuration Options

Default configuration table:

```lua
require("terminal_enhancement").setup({
  -- Default window layout: "float", "horizontal", or "vertical"
  direction = "float",

  -- Floating window geometry
  float_opts = {
    width = 0.85,          -- 85% of editor width
    height = 0.80,         -- 80% of editor height
    border = "rounded",    -- "rounded", "single", "double", "solid", "shadow"
    title = " Terminal ",
    title_pos = "center",
  },

  -- Split window dimensions
  split_size = {
    horizontal = 15,       -- Height in lines
    vertical = 60,         -- Width in columns
  },

  -- Behavior
  auto_insert = true,          -- Automatically enter insert mode when opening terminal
  clean_buffer = true,         -- Strip line numbers, signcolumn, foldcolumn
  smart_navigation = true,     -- Enable <Esc><Esc> and <C-h/j/k/l> window jumps
  smart_link_resolver = true,  -- Enable smart gf, <CR>, and click resolver
  bracketed_paste = true,      -- Wrap multi-line commands in \e[200~ ... \e[201~
  auto_dedent = true,          -- Remove leading indent from multi-line code blocks
  shell_continuation = "auto", -- "auto" (detects bash vs pwsh), "bash" (\), "powershell" (`)

  -- Tool specifications
  tools = {
    lazygit = { cmd = "lazygit", direction = "float", desc = "LazyGit GUI" },
    htop = { cmd = "htop", direction = "float", desc = "Process Monitor (htop)" },
    agy = { cmd = "agy", direction = "float", desc = "Antigravity AI Agent CLI" },
    python = { cmd = "python3", direction = "horizontal", desc = "Python Interactive REPL" },
    node = { cmd = "node", direction = "horizontal", desc = "Node.js Interactive REPL" },
  },
})
```

---

## 📄 License

MIT © [Pradhyumna Shrestha](https://github.com/pkshrestha)
