# 🚀 `cmd-cockpit.nvim`

Frequent command usage tracker, global keybinding matrix inspector, and interactive runtime remapper for Neovim.

---

## ✨ Features

- **⚡ Automatic Command Tracking & Analytics**: Non-blocking tracking of executed Ex commands with frecency scoring, usage bars, and last run timestamps.
- **🗺️ Global Keymap Explorer**: Search, inspect, and filter every active keybinding across Normal, Visual, Insert, Terminal, and Command modes with collision detection.
- **🔄 Interactive Runtime Remapper**: Remap or override any keybinding on the fly with collision warnings and persistence.
- **📤 Clean Lua Overrides Export**: Export custom keymap overrides to a standalone Lua configuration file (`~/.config/nvim/lua/config/keymap_overrides.lua`).
- **🕹️ Multi-Tab Cockpit HUD**: One-touch dashboard (`<leader>k` or `:CmdCockpit`) with 1-9 instant numeric execution for top commands and tab switching.

---

## 📦 Installation & Setup

Using **`lazy.nvim`**:

```lua
{
  "pradhyu/cmd-cockpit.nvim",
  dir = "~/git/neovim-config-spec/cmd-cockpit", -- Local development
  event = "VeryLazy",
  opts = {
    track_history = true,
    auto_apply_overrides = true,
    max_history_entries = 200,
  },
}
```

---

## ⌨️ Default Keybindings

Buffer and LSP safe: mapped under `<leader>k...` (and `<leader>C`).

| Keybinding | Action | Description |
|---|---|---|
| `<leader>k` / `<leader>kk` | `open_cockpit()` | Open Main Command Cockpit Dashboard |
| `<leader>kf` | `picker_frequent()` | Open Frequent Commands launcher picker |
| `<leader>km` | `open_keymaps()` | Open Keymap Explorer Matrix |
| `<leader>kr` | `open_remap()` | Open Interactive Remapper Modal |
| `<leader>ks` | `view_stats()` | View Command Execution Analytics |
| `<leader>ke` | `export_overrides()`| Export Overrides to Lua File |

---

## 🕹️ Dashboard Keybindings

Inside the Cockpit window (`<leader>k`):

| Key | Tab 1 (Frequent Commands) | Tab 2 (Keymap Explorer) | Tab 3 (Overrides) |
|---|---|---|---|
| `<Tab>` | Switch Tab | Switch Tab | Switch Tab |
| `1` - `9` | Run command #1 - #9 | Switch to Tab 1 | Switch to Tab 1 |
| `<CR>` | Execute selected command | View / Remap | - |
| `r` | Remap keybinding | Remap selected keybinding | - |
| `p` | Toggle Pin on command | - | - |
| `/` | - | Search keybindings query | - |
| `m` | - | Cycle mode (`n`/`v`/`i`/`t`) | - |
| `d` / `x` | Delete from history | - | Delete override |
| `R` | - | - | Reset all overrides |
| `E` | - | - | Export Lua config |
| `q` / `<Esc>` | Close | Close | Close |

---

## ⚡ User Commands

- `:CmdCockpit` - Open interactive Command Cockpit & Keymap Hub
- `:CmdFrequent` - Launch frequent commands picker
- `:CmdKeymaps [mode]` - Inspect and browse keymaps
- `:CmdRemap <mode> <old_lhs> <new_lhs>` - Override a keybinding
- `:CmdResetOverrides` - Reset all overrides to plugin defaults
- `:CmdExportOverrides [path]` - Export overrides to Lua file
- `:CmdStats` - View command execution frequency analytics
