# 🎹 super-keychord.nvim

Interactive keychord finder, exploratory discovery engine, and instant execution palette for Neovim. Search keybindings by description or partial chord using Telescope, Snacks, or `vim.ui.select`.

---

## ✨ Features

- **Description & Partial Chord Matching**: Find shortcuts by typing what you want to do (e.g. `tabs`, `terminal`, `format`) or the partial key sequence (e.g. `fe`, `<leader>b`).
- **Normalized Chords**: Automatically translates raw Neovim keymaps (`\fe`, ` fe`) into clean readable representations (`<leader>fe`, `<Esc>`, `<CR>`).
- **Direct Execution**: Pressing `<Enter>` on any keychord executes it directly.
- **Telescope & Snacks Integration**: Native visual pickers with mode badges (`[N]`, `[V]`, `[I]`, `[T]`), fallback to `vim.ui.select`.
- **Scope Filters**: Search all modes, filter by mode (`normal`, `visual`, `insert`, `terminal`), or restrict to current buffer keymaps.

---

## 📦 Installation

With `lazy.nvim`:

```lua
{
  "pradhyu/super-keychord.nvim",
  dir = "~/git/neovim-config-spec/super-keychord.nvim", -- local dev
  cmd = { "SuperKeychord", "SuperKeychordNormal", "SuperKeychordBuffer" },
  keys = {
    { "<leader>sk", "<cmd>SuperKeychord<cr>", desc = "Search Keychords" },
    { "<leader>k?", "<cmd>SuperKeychord<cr>", desc = "Search All Keychords" },
    { "<leader>kn", "<cmd>SuperKeychordNormal<cr>", desc = "Search Normal Keychords" },
    { "<leader>kb", "<cmd>SuperKeychordBuffer<cr>", desc = "Search Buffer Keychords" },
  },
  opts = {
    execute_on_select = true,
    include_plug_maps = false,
  },
}
```

---

## ⚡ User Commands

- `:SuperKeychord [mode|buffer]` - Open search picker (e.g. `:SuperKeychord normal`)
- `:SuperKeychordNormal` - Search normal mode keychords
- `:SuperKeychordBuffer` - Search buffer-local keychords
