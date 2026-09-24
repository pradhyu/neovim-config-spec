# `smart-highlighter.nvim` Specification

High-performance, multi-keyword, pattern, and scope-aware visual highlighter for Neovim (v0.9+ / v0.10+ / v0.13+).

---

## 🎯 Architectural Goals

1. **Ultra-Low Latency & High Performance**:
   - Sub-millisecond buffer highlighting using hybrid native extmarks (`vim.api.nvim_buf_set_extmark`) and window pattern matching (`vim.fn.matchadd`).
   - Non-blocking asynchronous match counting and debounced buffer change reconciliations.

2. **16-Slot Dynamic Color Palette**:
   - Beautiful, high-contrast, theme-adaptive color slots (compatible with Catppuccin, TokyoNight, Gruvbox, Nord, Solarized, and standard ANSI).
   - Dynamic dark / light background luminescence auto-tuning.

3. **Multi-Mode Highlighting**:
   - **Word & Selection Highlighting**: Instant toggle for word under cursor or visual block.
   - **Regex Patterns**: Highlight complex patterns like UUIDs, IP addresses, ISO-8601 timestamps, Hex codes, and JSON paths.
   - **Treesitter Scope Awareness**: Confine highlight matches strictly to the enclosing function, method, or lexical scope.
   - **Curated Presets**: One-touch presets for Log Analysis, HTTP / REST, SQL queries, and Git commits.

4. **Interactive HUD & Navigation**:
   - Floating HUD Manager for live monitoring of active highlight slots, occurrence counters, toggles, and pattern editing.
   - Bidirectional match jumping (`]h`/`[h` per slot, `]H`/`[H` global).
   - Export all occurrences to Quickfix list or Telescope.

5. **Session Persistence**:
   - Optional automatic saving and restoring of highlight patterns across Neovim sessions per workspace.

---

## 📐 Module Hierarchy

```
smart-highlighter/
├── SPEC.md
├── README.md
├── plugin/
│   └── smart_highlighter.lua       -- Auto-commands, default keymaps & User commands
└── lua/
    └── smart_highlighter/
        ├── init.lua                -- Public API entrypoint
        ├── config.lua              -- Default options & user configuration
        ├── core/
        │   ├── palette.lua         -- 16-slot theme-adaptive highlight group generator
        │   ├── engine.lua          -- Core pattern registry & buffer match application
        │   ├── navigation.lua      -- Next/prev match jumping and cursor navigation
        │   ├── presets.lua         -- Log, HTTP, SQL, and DevOps pattern presets
        │   ├── treesitter.lua      -- AST scope discovery and node-bounded matching
        │   └── session.lua         -- Workspace state persistence & restoration
        └── ui/
            ├── hud.lua             -- Interactive Floating HUD Manager
            ├── picker.lua          -- Quickfix / Telescope match exporter
            └── statusline.lua      -- Lualine / Statusline component helper
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| `<leader>hh` | `toggle()` | Toggle highlight on word under cursor or visual selection |
| `<leader>hH` | `add_regex()` | Prompt for custom regex pattern to highlight |
| `<leader>hc` | `clear_all()` | Clear all active highlight slots |
| `<leader>hC` | `clear_slot()` | Clear highlight slot under cursor |
| `<leader>hm` | `open_hud()` | Open interactive Floating HUD Manager |
| `<leader>hp` | `select_preset()` | Open preset picker (Logs, HTTP, SQL, etc.) |
| `<leader>hs` | `toggle_scope()` | Toggle Treesitter scope-bounded highlight |
| `<leader>hq` | `export_quickfix()` | Send all active matches to Quickfix list |
| `]h` / `[h` | `jump_next()` / `jump_prev()` | Jump to next / previous match of current slot |
| `]H` / `[H` | `jump_any_next()` / `jump_any_prev()` | Jump to next / previous match across all slots |

---

## ⚡ User Commands

- `:SmartHighlightToggle` - Toggle highlight on current word or selection
- `:SmartHighlightRegex <pattern>` - Add custom regex pattern highlight
- `:SmartHighlightClear [slot_id]` - Clear all highlights or specific slot
- `:SmartHighlightHUD` - Open the floating HUD manager
- `:SmartHighlightPreset <preset_name>` - Load preset (`logs`, `http`, `sql`, `json`)
- `:SmartHighlightScope` - Toggle treesitter enclosing scope highlight
- `:SmartHighlightQuickfix` - Export all matches to quickfix list
- `:SmartHighlightSave` / `:SmartHighlightLoad` - Manage session persistence
