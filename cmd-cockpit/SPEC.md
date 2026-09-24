# `cmd-cockpit.nvim` Specification

Comprehensive command frequency tracker, global keybinding inspector, and interactive runtime remapper for Neovim.

---

## 🎯 Architectural Goals

1. **Intelligent Command Tracking & Frecency Engine**:
   - Automatically tracks executed Ex commands without impacting editor latency.
   - Scores commands using Frecency (Frequency $\times$ Recency decay) to surface truly useful workflows.
   - Supports pinning favorite commands and fast numeric execution (`1-9`).
   - Persists usage stats across sessions per workspace in `~/.local/state/nvim/cmd-cockpit/`.

2. **Full Neovim Keybinding Matrix**:
   - Inspects all active keymaps across modes (`n`, `v`, `i`, `t`, `c`, `x`, `o`).
   - Captures LHS, RHS, description, mode, buffer-local vs global, and script origin.
   - Detects keymap collisions and shadowed shortcuts.

3. **Interactive Runtime Remapper & Override Engine**:
   - Remap or override any keybinding at runtime through a clean floating UI.
   - Instant validation with collision detection.
   - Persists overrides across sessions and allows exporting clean Lua code to `~/.config/nvim/lua/config/keymap_overrides.lua`.
   - One-click restore to plugin default.

4. **Multi-View Cockpit Dashboard**:
   - **Frequent Commands View**: Hotlist of most used commands with execution counters and instant triggers.
   - **Keymap Browser View**: Filterable, searchable keybinding explorer with mode tabs and collision indicators.
   - **Remap Studio**: Direct key override modal.

---

## 📐 Module Hierarchy

```
cmd-cockpit/
├── SPEC.md
├── README.md
├── plugin/
│   └── cmd_cockpit.lua
└── lua/
    └── cmd_cockpit/
        ├── init.lua
        ├── config.lua
        ├── core/
        │   ├── tracker.lua         -- Cmdline hooks & command execution logger
        │   ├── stats.lua           -- Frecency calculations & persistence
        │   ├── keymaps.lua         -- Keybinding discovery & collision analysis
        │   └── overrides.lua       -- Runtime remapping, storage & Lua export
        └── ui/
            ├── hud.lua             -- Dual-tab Cockpit Dashboard
            ├── remap_modal.lua     -- Interactive remapping dialogue
            ├── picker.lua          -- Telescope / vim.ui.select picker integration
            └── statusline.lua      -- Statusline helper
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| `<leader>cc` | `open_cockpit()` | Open Main Command & Keymap Cockpit |
| `<leader>cf` | `open_frequent()`| Open Frequent Commands Launcher |
| `<leader>ck` | `open_keymaps()` | Open Keybinding Browser & Inspector |
| `<leader>cr` | `open_remap()` | Open Interactive Keymap Remapper |
| `<leader>cS` | `view_stats()` | View Command Usage Statistics |
| `<leader>ce` | `export_overrides()` | Export overrides to config Lua file |

---

## ⚡ User Commands

- `:CmdCockpit` - Open the main Cockpit Dashboard
- `:CmdFrequent` - Launch top frequent commands
- `:CmdKeymaps [mode]` - Browse keybindings by mode
- `:CmdRemap <mode> <old_lhs> <new_lhs>` - Remap a keybinding
- `:CmdResetOverrides` - Reset all custom keymap overrides
- `:CmdExportOverrides [path]` - Export overrides to Lua file
- `:CmdStats` - Print command execution analytics
