# 🛡️ `buffer-buddy.nvim`

Comprehensive buffer companion for Neovim: Intelligent hygiene sweeper, text transformation toolkit, buffer pinning, floating scratchpads, in-memory snapshots, disk diffing, and buffer inspection.

---

## ✨ Features

- **🧹 Intelligent Hygiene Sweepers**: Clean unmodified, hidden, dead, or other buffers without closing pinned buffers or losing unsaved edits.
- **📌 Buffer Pinning**: Lock crucial files so automated cleaners and mass closures never close them.
- **✂️ Transformation Toolkit**: Format/minify JSON, Base64 encode/decode, URL encode/decode, deduplicate lines, sort lines, strip trailing whitespace, and align Markdown tables.
- **📸 In-Memory Undo Snapshots**: Create named checkpoints for any buffer before risky refactoring and revert instantly.
- **🔀 Live Diff Utilities**: Compare unsaved buffer changes against the saved file on disk, or diff against the system clipboard.
- **📝 Multi-Language Scratchpads**: Floating or split scratchpads in Markdown, Lua, SQL, JSON, Python, or Bash.
- **📊 Buffer Inspector HUD**: Live dashboard displaying lines, words, LLM token estimations, encoding, fileformat, and one-touch action triggers.

---

## 📦 Installation & Setup

Using **`lazy.nvim`**:

```lua
{
  "pradhyu/buffer-buddy.nvim",
  dir = "~/git/neovim-config-spec/buffer-buddy", -- Local development
  event = "VeryLazy",
  opts = {
    protect_pinned = true,
    trim_whitespace_on_save = false,
    auto_clean_on_exit = false,
    scratchpad_style = "float", -- "float" | "split" | "vsplit"
  },
}
```

---

## ⌨️ Default Keybindings

| Keybinding | Action |
|---|---|
| `<leader>bb` | Open interactive Buffer Buddy Dashboard & Inspector |
| `<leader>bp` | Toggle Pin on current buffer |
| `<leader>bd` | Diff buffer vs saved disk file |
| `<leader>bD` | Diff buffer vs system clipboard |
| `<leader>bs` | Open interactive Scratchpad selector |
| `<leader>bS` | Create named in-memory Snapshot checkpoint |
| `<leader>bR` | Revert buffer to a Snapshot checkpoint |
| `<leader>bc` | Close current buffer safely (preserving window layout) |
| `<leader>bC` | Sweep all unmodified buffers |
| `<leader>bo` | Sweep all other buffers |
| `<leader>bh` | Sweep all hidden buffers |
| `<leader>bt` | Trim trailing whitespace |
| `<leader>bj` | Format / Prettify JSON |

---

## ⚡ User Commands

- `:BufferBuddy` - Open the interactive HUD dashboard
- `:BufferPin` / `:BufferUnpin` / `:BufferTogglePin` - Manage pin states
- `:BufferSweep [unmodified|hidden|others|dead]` - Sweep buffer clutter
- `:BufferDiffDisk` / `:BufferDiffClipboard` - Diff buffer contents
- `:BufferScratch [filetype]` - Open scratchpad
- `:BufferSnapshot [name]` / `:BufferRestore` - Checkpoint management
- `:BufferTransform <trim|json|json_minify|base64_encode|base64_decode|url_encode|url_decode|dedup|sort|sort_unique|table>`
