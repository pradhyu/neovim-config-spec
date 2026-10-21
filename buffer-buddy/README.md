# 🛡️ `buffer-buddy.nvim`

Comprehensive buffer & workspace companion for Neovim: Tab workspace buffer scoping, intelligent hygiene sweepers, text transformation toolkit, local & global buffer pinning, floating scratchpads, in-memory snapshots, disk diffing, and buffer inspection.

---

## ✨ Features

- **📑 Tab Workspaces & Buffer Scoping**:
  - Turns Neovim tabpages into true project/task workspaces.
  - Automatically isolates buffers: Tab 1's buffers stay in Tab 1, Tab 2's stay in Tab 2.
  - Keeps top bufferlines (`bufferline.nvim`) and pickers (`folke/snacks.nvim`, `telescope`, `fzf-lua`) clean and uncluttered.
  - Workspace naming (`:BufferTabName "API"`, `:BufferTabNew "Frontend"`).
  - Move/send buffers between workspaces with `:BufferTabMove` / `:BufferTabSend` or `<leader>Bm`.
  - Safe tab closure (`:BufferTabClose` / `<leader>Bx`) cleans up exclusive buffers without leaving zombies.
- **🧹 Intelligent Hygiene Sweepers**: Clean unmodified, hidden, dead, or other buffers—either tab-scoped or globally.
- **📌 Dual Buffer Pinning**:
  - **Local Pin** (`<leader>Bp` / `📌`): Protects buffer from sweeps in the current workspace.
  - **Global Pin** (`<leader>BP` / `🌐`): Keeps critical reference files or scratchpads permanently listed and accessible across **all** tabs.
- **✂️ Transformation Toolkit**: Format/minify JSON, Base64 encode/decode, URL encode/decode, deduplicate lines, sort lines, strip trailing whitespace, and align Markdown tables.
- **📸 In-Memory Undo Snapshots**: Create named checkpoints for any buffer before risky refactoring and revert instantly.
- **🔀 Live Diff Utilities**: Compare unsaved buffer changes against the saved file on disk, or diff against the system clipboard.
- **📝 Multi-Language Scratchpads**: Floating or split scratchpads in Markdown, Lua, SQL, JSON, Python, or Bash.
- **📊 Buffer Inspector & Workspace HUD**: Live dashboard (`<leader>B` / `<leader>BB`) displaying buffer metrics, token counts, and an interactive overview of all tab workspaces.

---

## 📦 Installation & Setup

Using **`lazy.nvim`**:

```lua
{
  "pradhyu/buffer-buddy.nvim",
  dir = "~/git/neovim-config-spec/buffer-buddy", -- Local development
  event = "VeryLazy",
  opts = {
    tab_scoping = true,         -- Enable tab workspace buffer isolation
    tab_auto_name = true,       -- Auto-generate workspace labels from active files
    tab_clean_on_close = true,  -- Purge exclusive buffers on tab close
    protect_pinned = true,      -- Protect pinned buffers from automated sweeps
    trim_whitespace_on_save = false,
    auto_clean_on_exit = false,
    scratchpad_style = "float", -- "float" | "split" | "vsplit"
  },
}
```

---

## ⌨️ Default Keybindings

Buffer Buddy uses the `<leader>B` prefix so all standard LazyVim / BufferLine `<leader>b*` mappings (`<leader>bb`, `<leader>bd`, `<leader>bD`, `<leader>bo`, `<leader>bp`, `<leader>be`, `<leader>bi`) remain 100% intact.

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
| `<leader>Bd` | `diff_disk()` | Diff buffer vs saved disk file |
| `<leader>BD` | `diff_clipboard()`| Diff buffer vs system clipboard |
| `<leader>Bs` / `<leader>bs` | `open_scratch()` | Open interactive Scratchpad selector |
| `<leader>BS` | `create_snapshot()`| Create named in-memory Snapshot checkpoint |
| `<leader>BR` | `restore_snapshot()`| Revert buffer to a Snapshot checkpoint |
| `<leader>Bc` / `<leader>bc` | `close_current()` | Close current buffer safely (preserving window layout) |
| `<leader>BC` | `close_unmodified()`| Sweep all unmodified buffers across all tabs |
| `<leader>Bo` | `close_others()` | Sweep all other buffers |
| `<leader>Bh` | `close_hidden()` | Sweep all hidden buffers |
| `<leader>Bt` / `<leader>bt` | `trim_whitespace()`| Trim trailing whitespace |
| `<leader>Bj` / `<leader>bj` | `json_format()` | Format / Prettify JSON |

---

## ⚡ User Commands

- `:BufferBuddy` - Open interactive HUD & Workspace dashboard
- `:BufferTabName [name]` - Name or rename workspace tab
- `:BufferTabNew [name]` - Create new named workspace tab
- `:BufferTabClose` - Close tab and sweep exclusive buffers
- `:BufferTabMove [target_tab]` - Move buffer to target tab workspace
- `:BufferTabSend [target_tab]` - Share buffer with target tab
- `:BufferTabNext` / `:BufferTabPrev` - Cycle within workspace tab
- `:BufferPin [local|global]` - Pin buffer locally or globally
- `:BufferUnpin [local|global]` - Unpin buffer
- `:BufferTogglePin [local|global]` - Toggle pin state
- `:BufferSweep [tab|tab_hidden|tab_others|unmodified|hidden|others|dead]` - Sweep buffer clutter
- `:BufferDiffDisk` / `:BufferDiffClipboard` - Diff buffer contents
- `:BufferScratch [filetype]` - Open scratchpad
- `:BufferSnapshot [name]` / `:BufferRestore` - Checkpoint management
- `:BufferTransform <transform_name>` - Run text transformation
