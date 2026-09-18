# ⚡ terminal-enhancement.nvim

> **Robust, seamless, and intelligent terminal management & smart link navigation for Neovim.**

---

## ✨ Features

* 🪟 **Multi-Direction Terminals**: Toggle floating windows, horizontal splits, or vertical splits with persistent shell sessions.
* 🛠️ **Dedicated Tool Launchers**: Pre-configured floating instances for `lazygit`, `htop`, `agy` (Antigravity AI CLI), Python REPL, and Node REPL.
* 🔗 **Smart Link & Error Trace Resolver**: Intelligent `gf`, `<CR>`, and `<C-LeftMouse>` click resolver that parses compiler errors, stack traces, `file:///path#L10-L20`, `:line:col`, `(line)`, and web URLs.
* ⌨️ **Seamless Navigation**: Exit terminal mode effortlessly with `<Esc><Esc>` and jump between terminal windows using standard `<C-h/j/k/l>`.
* 🎨 **Clean Visual Styling**: Strips clutter (no line numbers, no signcolumn, no foldcolumn) and applies themed window highlights.
* 📤 **Selection & Line Runner**: Send visual selections or lines directly to the active terminal.
* 🧹 **Process & Memory Cleanup**: One-key cleanup to kill and purge background/hidden terminals or selectively terminate processes.

---

## 📦 Installation & Setup

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    dir = "/Users/pkshrestha/git/neovim-config/terminal-enhancement",
    name = "terminal-enhancement.nvim",
    cmd = {
      "TermToggle",
      "TermFloat",
      "TermSplit",
      "TermTool",
      "TermRun",
      "TermSend",
      "TermSelect",
      "TermTarget",
      "TermBuffer",
      "TermList",
      "TermKill",
      "TermClean",
      "TermKillHidden",
      "TermKillAll",
      "TermRename",
    },
    keys = {
      { "<leader>tt", "<cmd>TermToggle<cr>", desc = "Toggle Terminal (Default)" },
      { "<leader>tf", "<cmd>TermFloat<cr>", desc = "Toggle Floating Terminal" },
      { "<leader>th", "<cmd>TermToggle horizontal<cr>", desc = "Toggle Terminal (Horizontal Split)" },
      { "<leader>tv", "<cmd>TermToggle vertical<cr>", desc = "Toggle Terminal (Vertical Split)" },
      { "<leader>tg", "<cmd>TermTool lazygit<cr>", desc = "LazyGit Terminal" },
      { "<leader>top", "<cmd>TermTool htop<cr>", desc = "htop Process Monitor" },
      { "<leader>ts", "<cmd>TermSend<cr>", mode = { "n", "v" }, desc = "Send Line / Selection to Terminal" },
      { "<leader>tc", "<cmd>TermSelect<cr>", desc = "Select / Change Target Terminal" },
      { "<leader>tr", "<cmd>TermRename<cr>", desc = "Rename Terminal" },
      { "<leader>tB", "<cmd>TermBuffer<cr>", desc = "Open Terminal as Regular Buffer" },
      { "<leader>tk", "<cmd>TermKill<cr>", desc = "Kill / Terminate Terminal (Interactive)" },
      { "<leader>tX", "<cmd>TermClean<cr>", desc = "Clean All Hidden Terminals" },
    },
    opts = {
      direction = "float",
      auto_insert = true,
      clean_buffer = true,
      smart_navigation = true,
      smart_link_resolver = true,
    },
    config = function(_, opts)
      require("terminal_enhancement").setup(opts)
    end,
  },
}
```

---

## ⌨️ User Commands

| Command | Action | Description |
| :--- | :--- | :--- |
| `:TermToggle [float\|horizontal\|vertical]` | Toggle Terminal | Toggles persistent terminal in specified direction. |
| `:TermFloat` | Floating Terminal | Opens centered floating terminal. |
| `:TermSplit [horizontal\|vertical]` | Split Terminal | Opens horizontal/vertical terminal split. |
| `:TermBuffer [id]` | Open as Buffer | Opens terminal directly into active window as a regular buffer. |
| `:TermTool <name>` | Tool Launcher | Opens dedicated tool (`lazygit`, `htop`, `agy`, `python`, `node`). |
| `:TermRun <cmd>` | Run Shell Command | Runs command in floating popup terminal. |
| `:TermSend` | Send Selection | Sends visual line selection into target terminal. |
| `:TermSelect` / `:TermTarget` | Change Target | Interactive selector to switch default target terminal. |
| `:TermRename [name]` | Rename Terminal | Renames terminal session and buffer title. |
| `:TermList` | List Terminals | Lists all active terminal instances and default target. |
| `:TermClean` / `:TermKillHidden` | Clean Hidden | Terminates all hidden/background terminal jobs and frees memory/PTYs. |
| `:TermKill [id\|buf]` | Kill Terminal | Interactively select terminal to terminate, or kill by ID/buffer number. |
| `:TermKillAll` | Kill All | Terminates all active terminal sessions and closes windows. |

---

## 📄 License

MIT
