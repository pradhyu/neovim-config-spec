# `super-keychord.nvim` Specification

Interactive keychord finder, exploratory discovery engine, and instant execution palette for Neovim.

---

## 🎯 Architectural Goals

1. **Fuzzy Keychord Search**:
   - Search through all configured Neovim keybindings by **human description**, **partial keychord** (e.g. `fe`, `<leader>b`, `gs`), **mode**, or **action/command target**.
   - Normalizes raw key combinations into readable visual representations (e.g. converting `\fe` or ` fe` to `<leader>fe`, `\27` to `<Esc>`, `\r` to `<CR>`).

2. **Multi-Backend Picker Support**:
   - Integrates natively with `Snacks.picker` (with color-coded mode badges `[N]`, `[V]`, `[I]`, bold chord names, and aligned description labels).
   - Falls back automatically to `Telescope` or `vim.ui.select` when Snacks is unavailable.

3. **Direct Execution on Select**:
   - Pressing `<CR>` on any discovered keychord immediately executes the chord (calling Lua functions directly, running `<Cmd>` ex commands, or dispatching via `nvim_feedkeys`).

4. **Frecency Tracking & Persistent Top Ranking**:
   - Tracks every keychord you type directly in Neovim or execute from the search picker.
   - Calculates a frecency score (Frequency + Recency boost) and automatically ranks your most frequently used keychords at the very top.
   - Persists usage statistics cleanly to `~/.local/state/nvim/super-keychord/usage.json` across Neovim sessions.
   - Displays a `🔥 <count>x` badge next to frequently used keychords.

5. **Mode & Scope Filtering**:
   - `:SuperKeychord` or `<leader>sk` / `<leader>k?`: Search all modes across global and buffer-local keymaps.
   - `:SuperKeychord normal` or `<leader>kn`: Filter specifically to Normal mode keychords.
   - `:SuperKeychord visual` or `<leader>kv`: Filter specifically to Visual mode keychords.
   - `:SuperKeychord buffer` or `<leader>kb`: Filter specifically to keychords mapped in the active buffer.

---

## 📐 Module Structure

```
super-keychord.nvim/
├── SPEC.md
├── README.md
├── plugin/
│   └── super_keychord.lua         -- User commands (:SuperKeychord*) & default keymaps
├── tests/
│   └── test_super_keychord_spec.lua -- Headless test suite
└── lua/
    └── super_keychord/
        ├── init.lua               -- Public API & module entry
        ├── config.lua             -- Configuration options & defaults
        ├── core/
        │   ├── keychords.lua      -- Keymap introspection, leader normalization & ranking
        │   ├── tracker.lua        -- Frecency score calculation & JSON disk persistence
        │   └── listener.lua       -- Background key listener for tracking live usage
        └── ui/
            └── picker.lua         -- Snacks / Telescope / vim.ui.select picker interface
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| `<leader>sk` / `<leader>k?` | `open()` | Search all keychords across all modes |
| `<leader>kn` | `open_normal()` | Search Normal mode keychords |
| `<leader>kv` | `open_visual()` | Search Visual mode keychords |
| `<leader>kb` | `open_buffer()` | Search buffer-local keychords |

---

## ⚡ User Commands

- `:SuperKeychord [all|normal|visual|insert|terminal|buffer]` - Open keychord picker for specific mode
- `:SuperKeychordNormal` - Open picker for Normal mode
- `:SuperKeychordBuffer` - Open picker for active buffer
