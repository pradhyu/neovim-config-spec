# `buffer-buddy.nvim` Specification

Comprehensive buffer companion for Neovim: Intelligent hygiene sweeper, tab workspace buffer scoping, text transformation toolkit, local & global buffer pinning, floating scratchpads, in-memory snapshots, disk diffing, and buffer inspection.

---

## 🎯 Architectural Goals

1. **Tab Workspaces & Buffer Isolation**:
   - Isolates buffers per tabpage, transforming Neovim tabs into true workspaces.
   - Automatically manages `buflisted` state on `TabEnter`/`TabLeave`:
     - In Tab 1, only Tab 1's buffers are listed (and shown in `bufferline.nvim`, `snacks.picker.buffers`, and `:ls`).
     - In Tab 2, Tab 1's non-global buffers are hidden, and Tab 2's buffers are active.
   - **Tab Naming & Labels**:
     - Custom human names (`:BufferTabName "Backend API"` or `:BufferTabNew "Frontend"`).
     - Auto-naming based on active file when unnamed.
   - **Buffer Transfer & Navigation**:
     - `:BufferTabMove <tab>`: Migrate buffer from current tab to target tab.
     - `:BufferTabSend <tab>`: Share buffer with target tab.
     - `[B` / `]B` (`:BufferTabPrev` / `:BufferTabNext`): Fast cycling strictly within current tab workspace.
   - **Safe Tab Closure**:
     - `:BufferTabClose` / `<leader>Bx`: Closes the tab and purges all exclusive unmodified buffers, preventing zombie buffers from polluting future sessions.

2. **Intelligent Buffer Hygiene & Sweeper**:
   - Safely prune buffers that clutter Neovim without losing unsaved work:
     - `close_tab_unmodified()`: Close unmodified buffers in current tab workspace only.
     - `close_tab_hidden()`: Close hidden buffers in current tab workspace only.
     - `close_tab_others()`: Close all buffers except active one in current tab.
     - `close_unmodified()`: Close all unmodified buffers across all tabs.
     - `close_hidden()`: Close buffers not visible in any window.
     - `close_others()`: Close all buffers except active one across all tabs.
     - `close_dead()`: Clean up deleted/orphaned files.
   - **Local & Global Pinning**:
     - **Local Pin** (`<leader>Bp` / `📌`): Protected from tab sweeps within the workspace.
     - **Global Pin** (`<leader>BP` / `🌐`): Immune to sweeps and permanently listed across ALL tabs.

3. **Text Transformation & Formatting Suite**:
   - Instant in-buffer and range transformations:
     - **JSON**: Format / Prettify & Minify.
     - **Encoding**: Base64 Encode/Decode, URL Encode/Decode.
     - **Cleaners**: Strip trailing whitespace, normalize line endings (`\n` vs `\r\n`), remove duplicate lines, sort lines (alphanumeric/natural/unique).
     - **Case Conversion**: snake_case, camelCase, PascalCase, kebab-case, CONSTANT_CASE.
     - **Markdown & Tables**: Auto-format and align ASCII/Markdown tables.

4. **In-Memory Snapshots & Undo Checkpoints**:
   - Create instant named buffer checkpoints before risky refactors or transformations.
   - Diff buffer against its saved snapshot or disk version.
   - Revert buffer to any checkpoint with zero disk overhead.

5. **Multi-Language Scratchpad Manager**:
   - Instant floating, horizontal, or vertical scratchpads in Markdown, Lua, SQL, JSON, or Bash (`<leader>bs`).
   - Ephemeral or persistent scratchpad caching across sessions.

6. **Diff Utilities**:
   - `diff_disk()`: View a live 2-way diff of the unsaved buffer vs the file on disk.
   - `diff_clipboard()`: Diff current buffer/selection against system clipboard.

7. **Interactive Buffer Inspector & HUD**:
   - Floating visual dashboard (`<leader>B` / `<leader>BB` or `:BufferBuddy`):
     - Displays file size, lines, words, estimated LLM tokens, encoding, fileformat, read-only flag, pinned state.
     - Live overview of all Tab Workspaces and their active/pinned buffers.
     - One-touch interactive hotkeys for all workspace operations, sweepers, transforms, and scratchpads.

---

## 📐 Module Structure

```
buffer-buddy/
├── SPEC.md
├── README.md
├── plugin/
│   └── buffer_buddy.lua
├── tests/
│   ├── test_tabs_spec.lua          -- Headless test suite for tab isolation
│   ├── test_breadcrumbs_spec.lua   -- Headless test suite for breadcrumbs winbar
│   └── test_commands_spec.lua      -- Headless test suite for user commands
└── lua/
    └── buffer_buddy/
        ├── init.lua
        ├── config.lua
        ├── core/
        │   ├── tabs.lua            -- Tab workspace isolation, buflisted sync, tab naming, moving
        │   ├── hygiene.lua         -- Tab-scoped & global sweepers (tab, unmodified, hidden, others, dead)
        │   ├── pin.lua             -- Local & global pin management (📌 vs 🌐)
        │   ├── transforms.lua      -- JSON, Base64, URL, Dedup, Trim, Case, Table
        │   ├── scratchpad.lua      -- Floating/split scratchpad creator
        │   ├── snapshot.lua        -- Buffer checkpoints & restoration
        │   ├── diff.lua            -- Diff vs disk, diff vs clipboard
        │   └── inspector.lua       -- Word/token counts, metrics & properties
        └── ui/
            ├── breadcrumbs.lua     -- Window breadcrumbs with file icons, directory path, pin/mod flags
            ├── hud.lua             -- Interactive Buffer Buddy HUD dashboard with Workspace overview
            ├── scratch_picker.lua  -- Scratchpad type selector
            └── statusline.lua      -- Statusline pinned badge (📌/🌐), workspace badge, & token count
```

---

## ⌨️ Default Keybindings

Buffer Buddy uses `<leader>B` as prefix to preserve all standard LazyVim / BufferLine `<leader>b*` mappings intact.

| Keybinding | Action | Description |
|---|---|---|
| `<leader>B` / `<leader>BB` | `open_hud()` | Open interactive Buffer Buddy Dashboard & Workspaces |
| `<leader>Bn` | `rename_tab_interactive()` | Name or rename current workspace tab |
| `<leader>BN` | `new_tab()` | Create a new named workspace tab |
| `<leader>Bm` | `move_buffer_interactive()` | Move current buffer to another workspace tab |
| `<leader>Bx` | `close_tab_safe()` | Safely close tab and sweep exclusive buffers |
| `<leader>Bu` / `<leader>bu` | `close_tab_unmodified()` | Sweep unmodified buffers in current tab only |
| `[B` / `]B` | `prev/next_tab_buffer()` | Cycle strictly within current tab workspace |
| `<leader>Bp` | `toggle_pin()` | Toggle local pin (protects from tab sweeps) |
| `<leader>BP` | `toggle_global_pin()` | Toggle global pin 🌐 (visible across all tabs) |
| `<leader>Bd` | `diff_disk()` | Diff current buffer against saved disk version |
| `<leader>BD` | `diff_clipboard()`| Diff current buffer against system clipboard |
| `<leader>Bs` / `<leader>bs` | `open_scratch()` | Open scratchpad (Markdown, Lua, SQL, JSON, Bash) |
| `<leader>BS` | `create_snapshot()`| Create named snapshot checkpoint |
| `<leader>BR` | `restore_snapshot()`| Revert buffer to snapshot checkpoint |
| `<leader>Bc` / `<leader>bc` | `close_current()` | Close current buffer safely |
| `<leader>BC` | `close_unmodified()`| Sweep all unmodified buffers across all tabs |
| `<leader>Bo` | `close_others()` | Close all other non-pinned buffers |
| `<leader>Bh` | `close_hidden()` | Close all hidden (unopened in win) buffers |
| `<leader>Bt` / `<leader>bt` | `trim_whitespace()`| Trim trailing whitespace from buffer |
| `<leader>Bj` / `<leader>bj` | `json_format()` | Format / Prettify JSON |

---

## ⚡ User Commands

- `:BufferBuddy` - Open the interactive Buffer Buddy HUD & Workspaces
- `:BufferTabName [name]` - Name or rename workspace tab
- `:BufferTabNew [name]` - Create a new named workspace tab
- `:BufferTabClose` - Close tab and purge exclusive buffers
- `:BufferTabMove [target_tab]` - Move buffer to target tab
- `:BufferTabSend [target_tab]` - Share buffer with target tab
- `:BufferTabNext` / `:BufferTabPrev` - Cycle within workspace tab
- `:BufferPin [local|global]` - Pin buffer locally or globally
- `:BufferUnpin [local|global]` - Unpin buffer
- `:BufferTogglePin [local|global]` - Toggle pin state
- `:BufferSweep [tab|tab_hidden|tab_others|unmodified|hidden|others|dead]` - Sweep buffer clutter
- `:BufferDiffDisk` / `:BufferDiffClipboard` - Diff buffer contents
- `:BufferScratch [ft]` - Open scratchpad buffer
- `:BufferSnapshot [name]` / `:BufferRestore [name]` - Snapshot manager
- `:BufferTransform <transform_name>` - Run transformation (json, base64, url, dedup, trim, sort, table)
