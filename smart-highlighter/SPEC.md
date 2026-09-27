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
   - **All Open Buffers vs Current Buffer Scope**: Freely highlight across all open buffers or isolate highlights strictly to the current active buffer.
   - **Regex Patterns**: Highlight complex patterns like UUIDs, IP addresses, ISO-8601 timestamps, Hex codes, and JSON paths.
   - **Treesitter Scope Awareness**: Confine highlight matches strictly to the enclosing function, method, or lexical scope.
   - **Curated Presets**: One-touch presets for Log Analysis, HTTP / REST, SQL queries, and Git commits.

4. **Interactive HUD & Navigation**:
   - Floating HUD Manager for live monitoring of active highlight slots, occurrence counters, buffer scope toggles (`b` per slot, `B` global), and pattern editing.
   - Bidirectional match jumping (`]h`/`[h` per slot, `]H`/`[H` global).
   - Export all occurrences to Quickfix list or Telescope.

5. **Session Persistence**:
   - Optional automatic saving and restoring of highlight patterns across Neovim sessions per workspace.

6. **Code Bookmarking with Notes & Visual Highlights**:
   - Highlight any line or visual selection as a persistent bookmark.
   - Interactive prompt for custom bookmark notes with automatic fallback to highlighted text or line content if left empty.
   - Distinct bookmark gutter sign (`🔖`), full-line visual background highlight, and end-of-line virtual text annotation.
   - Dedicated Bookmarks tab in HUD manager (`<leader>hm`, switch tabs with `m` or `<Tab>`), fuzzy search picker via Telescope / Snacks (`<leader>hl`), and bottom quickfix-style list buffer (`<leader>hL`).
   - Bidirectional jumping between bookmarks (`]k` / `[k`).
   - Workspace session persistence across Neovim restarts.

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
        │   ├── bookmarks.lua       -- Code bookmarking, notes, extmarks & jumping
        │   ├── navigation.lua      -- Next/prev match jumping and cursor navigation
        │   ├── presets.lua         -- Log, HTTP, SQL, and DevOps pattern presets
        │   ├── treesitter.lua      -- AST scope discovery and node-bounded matching
        │   └── session.lua         -- Workspace state persistence & restoration
        └── ui/
            ├── hud.lua             -- Interactive Floating HUD Manager (Highlights & Bookmarks tabs)
            ├── picker.lua          -- Quickfix / Telescope match exporter
            └── statusline.lua      -- Lualine / Statusline component helper
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| `<leader>hh` | `toggle()` | Toggle highlight on word under cursor (respects `buffer_scope`) |
| `<leader>hb` | `toggle_current_buffer()` | Toggle highlight strictly for **CURRENT buffer only** |
| `<leader>hB` | `toggle_buffer_scope()` | Toggle default buffer scope mode (**All Buffers** ⟷ **Current Buffer Only**) |
| `<leader>hH` | `add_regex()` | Prompt for custom regex pattern to highlight |
| `<leader>hc` | `clear_all()` | Clear all active highlight slots |
| `<leader>hC` | `clear_slot()` | Clear highlight slot under cursor |
| `<leader>hm` | `open_hud()` | Open interactive Floating HUD Manager |
| `<leader>hp` | `select_preset()` | Open preset picker (Logs, HTTP, SQL, etc.) |
| `<leader>hs` | `toggle_scope()` | Toggle Treesitter scope-bounded highlight |
| `<leader>hq` | `export_quickfix()` | Send all active matches to Quickfix list |
| `<leader>hf` | `search_matches()` | Search matches via Telescope / Snacks (All Open Buffers) |
| `<leader>hF` | `search_matches_current()` | Search matches via Telescope / Snacks (Current Buffer Only) |
| `]h` / `[h` | `jump_next()` / `jump_prev()` | Jump to next / previous match of current slot |
| `]H` / `[H` | `jump_any_next()` / `jump_any_prev()` | Jump to next / previous match across all slots |
| `<leader>hk` | `toggle_bookmark()` | Toggle bookmark on line (prompts for note, fallback to highlight) |
| `<leader>hK` | `quick_bookmark()` | Quick toggle bookmark on line without note prompt |
| `<leader>hl` | `search_bookmarks()` | Search & list all bookmarks via Telescope / Snacks |
| `<leader>hL` | `bottom_pane_bookmarks()` | Open bookmarks in dedicated bottom list buffer |
| `<leader>ht` | `filter_bookmarks()` | Filter bookmarks by tag (`TODO`, `FIXME`, `WARN`, `NOTE`, `HACK`) |
| `]k` / `[k` | `jump_bookmark_next()` / `jump_bookmark_prev()` | Jump to next / previous bookmark |

---

## ⚡ User Commands

- `:SmartHighlightToggle [all|current]` - Toggle highlight on current word or selection
- `:SmartHighlightBuffer [word]` - Highlight word in current buffer only
- `:SmartHighlightGlobal [word]` - Highlight word across all open buffers
- `:SmartHighlightBufferScope [all|current|toggle]` - Switch or toggle default buffer scope mode
- `:SmartHighlightRegex <pattern>` - Add custom regex pattern highlight
- `:SmartHighlightClear [slot_id]` - Clear all highlights or specific slot
- `:SmartHighlightHUD` - Open the floating HUD manager
- `:SmartHighlightPreset <preset_name>` - Load preset (`logs`, `http`, `sql`, `json`, `devops`)
- `:SmartHighlightScope` - Toggle treesitter enclosing scope highlight
- `:SmartHighlightQuickfix` - Export all matches to quickfix list
- `:SmartHighlightSearch` - Fuzzy search matches via Telescope / Snacks
- `:SmartHighlightSave` / `:SmartHighlightLoad` - Manage session persistence
- `:SmartBookmarkToggle [note]` - Toggle bookmark on current line with optional note
- `:SmartBookmarkQuick` - Quick toggle bookmark without note prompt
- `:SmartBookmarkNext [tag]` / `:SmartBookmarkPrev [tag]` - Jump to next / previous bookmark (optionally by tag)
- `:SmartBookmarkSearch [tag|all|current]` - Fuzzy search bookmarks with live preview (Telescope / Snacks)
- `:SmartBookmarkBottom [tag|all|current]` - Open bookmarks in dedicated bottom list pane
- `:SmartBookmarkFilter [tag]` - Filter bookmarks by tag with interactive count selector
- `:SmartBookmarkClear` - Clear all bookmarks in workspace
- `:SmartBookmarkHUD` - Open HUD focused directly on Bookmarks tab
