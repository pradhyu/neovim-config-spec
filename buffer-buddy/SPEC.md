# `buffer-buddy.nvim` Specification

Comprehensive buffer companion for Neovim: Intelligent hygiene sweeper, text transformation toolkit, buffer pinning, floating scratchpads, in-memory snapshots, disk diffing, and buffer inspection.

---

## 🎯 Architectural Goals

1. **Intelligent Buffer Hygiene & Sweeper**:
   - Safely prune buffers that clutter Neovim without losing unsaved work:
     - `close_unmodified()`: Close buffers with no unwritten changes.
     - `close_hidden()`: Close buffers not currently visible in any split or window.
     - `close_others()`: Close all buffers except the active one.
     - `close_dead()`: Clean up deleted/orphaned files.
   - **Buffer Pinning**: Pinned buffers (`<leader>bp`) are strictly immune to all automated sweepers and bulk closes.

2. **Text Transformation & Formatting Suite**:
   - Instant in-buffer and range transformations:
     - **JSON**: Format / Prettify & Minify.
     - **Encoding**: Base64 Encode/Decode, URL Encode/Decode.
     - **Cleaners**: Strip trailing whitespace, normalize line endings (`\n` vs `\r\n`), remove duplicate lines, sort lines (alphanumeric/natural/unique).
     - **Case Conversion**: snake_case, camelCase, PascalCase, kebab-case, CONSTANT_CASE.
     - **Markdown & Tables**: Auto-format and align ASCII/Markdown tables.

3. **In-Memory Snapshots & Undo Checkpoints**:
   - Create instant named buffer checkpoints before risky refactors or transformations.
   - Diff buffer against its saved snapshot or disk version.
   - Revert buffer to any checkpoint with zero disk overhead.

4. **Multi-Language Scratchpad Manager**:
   - Instant floating, horizontal, or vertical scratchpads in Markdown, Lua, SQL, JSON, or Bash (`<leader>bs`).
   - Ephemeral or persistent scratchpad caching across sessions.

5. **Diff Utilities**:
   - `diff_disk()`: View a live 2-way diff of the unsaved buffer vs the file on disk.
   - `diff_clipboard()`: Diff current buffer/selection against system clipboard.

6. **Interactive Buffer Inspector & HUD**:
   - Floating visual dashboard (`<leader>bb` or `:BufferBuddy`):
     - Displays file size, lines, words, estimated LLM tokens, encoding, fileformat, read-only flag, pinned state.
     - One-touch interactive menu for all sweepers, transforms, and scratchpads.

---

## 📐 Module Structure

```
buffer-buddy/
├── SPEC.md
├── README.md
├── plugin/
│   └── buffer_buddy.lua
└── lua/
    └── buffer_buddy/
        ├── init.lua
        ├── config.lua
        ├── core/
        │   ├── hygiene.lua         -- Sweep unmodified, hidden, others, dead
        │   ├── pin.lua             -- Pin/favorite management
        │   ├── transforms.lua      -- JSON, Base64, URL, Dedup, Trim, Case, Table
        │   ├── scratchpad.lua      -- Floating/split scratchpad creator
        │   ├── snapshot.lua        -- Buffer checkpoints & restoration
        │   ├── diff.lua            -- Diff vs disk, diff vs clipboard
        │   └── inspector.lua       -- Word/token counts, metrics & properties
        └── ui/
            ├── hud.lua             -- Interactive Buffer Buddy HUD dashboard
            ├── scratch_picker.lua  -- Scratchpad type selector
            └── statusline.lua      -- Statusline pinned & token count badge
```

---

## ⌨️ Default Keybindings

| Keybinding | Action | Description |
|---|---|---|
| `<leader>bb` | `open_hud()` | Open interactive Buffer Buddy Dashboard |
| `<leader>bp` | `toggle_pin()` | Pin / unpin current buffer (protects from sweeps) |
| `<leader>bd` | `diff_disk()` | Diff current buffer against saved disk version |
| `<leader>bD` | `diff_clipboard()`| Diff current buffer against system clipboard |
| `<leader>bs` | `open_scratch()` | Open scratchpad (Markdown, Lua, SQL, JSON, Bash) |
| `<leader>bS` | `create_snapshot()`| Create named snapshot checkpoint |
| `<leader>bR` | `restore_snapshot()`| Revert buffer to snapshot checkpoint |
| `<leader>bc` | `close_current()` | Close current buffer safely |
| `<leader>bC` | `close_unmodified()`| Sweep all unmodified buffers |
| `<leader>bo` | `close_others()` | Close all other non-pinned buffers |
| `<leader>bh` | `close_hidden()` | Close all hidden (unopened in win) buffers |
| `<leader>bt` | `trim_whitespace()`| Trim trailing whitespace from buffer |
| `<leader>bj` | `json_format()` | Format / Prettify JSON |

---

## ⚡ User Commands

- `:BufferBuddy` - Open the interactive Buffer Buddy HUD
- `:BufferPin` / `:BufferUnpin` / `:BufferTogglePin` - Manage pinned status
- `:BufferSweep [unmodified|hidden|others|dead]` - Sweep buffer clutter
- `:BufferDiffDisk` / `:BufferDiffClipboard` - Diff buffer contents
- `:BufferScratch [ft]` - Open scratchpad buffer
- `:BufferSnapshot [name]` / `:BufferRestore [name]` - Snapshot manager
- `:BufferTransform <transform_name>` - Run transformation (json, base64, url, dedup, trim, sort, table)
