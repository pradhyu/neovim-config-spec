# 🎨 `smart-highlighter.nvim`

Ultra-fast, multi-keyword, pattern, and Treesitter scope-aware visual highlighter for Neovim.

---

## ✨ Features

- **⚡ Blazing Fast Performance**: Zero-latency highlighting using native compiled C `vim.regex` and asynchronous debounced extmark rendering.
- **🎨 16 High-Contrast Palette Slots**: Auto-adapting light/dark color slots with rich luminescence matching modern themes (Catppuccin, TokyoNight, Gruvbox, etc.).
- **🌳 Treesitter Scope Awareness**: Confine highlight matches strictly to the current function, method, or lexical scope (`<leader>hs`).
- **📋 Ready-to-Use Presets**: One-touch diagnostic and log analysis presets (`logs`, `http`, `sql`, `json`, `devops`).
- **🕹️ Floating HUD Manager**: Interactive dashboard to view live occurrences, toggle slots, delete, and add regexes (`<leader>hm`).
- **🧭 Bidirectional Navigation**: Jump between matches for a specific slot (`]h`/`[h`) or across all active slots (`]H`/`[H`).
- **🔖 Code Bookmarks with Notes**: Highlight a line and attach a custom annotation note (`<leader>hk`), or quick-bookmark directly using highlighted text (`<leader>hK`). Displays sign icons, line highlights, and end-of-line virtual text notes.
- **🔍 Quickfix & Telescope Export**: Instantly export all highlighted occurrences to the Quickfix list or live search via Telescope (`<leader>hq`, `<leader>hf`).
- **💾 Session Persistence**: Automatically preserves active highlights and bookmarks per project workspace across restarts.

---

## 📦 Installation & Setup

Using **`lazy.nvim`**:

```lua
{
  "pradhyu/smart-highlighter.nvim",
  dir = "~/git/neovim-config-spec/smart-highlighter", -- Local development
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    max_slots = 16,
    whole_word = true,
    case_sensitive = false,
    buffer_scope = "all", -- "all" (highlight all open buffers) or "current" (highlight only active buffer)
    current_buffer_search = "bottom_pane", -- "bottom_pane" or "picker"
    bookmarks = {
      enabled = true,
      sign_text = "🔖",
      virt_text = true,
      line_highlight = true,
    },
    persistence = true,
    presets = {
      enabled = true,
      auto_by_filetype = true,
    },
  },
}
```

---

## ⌨️ Keybindings

### 🎨 Highlighting
| Keybinding | Action |
|---|---|
| `<leader>hh` | Toggle highlight on word under cursor (respects default `buffer_scope`) |
| `<leader>hb` | Toggle highlight strictly for **CURRENT buffer only** |
| `<leader>hB` | Toggle default buffer scope mode (**All Open Buffers** ⟷ **Current Buffer Only**) |
| `<leader>hH` | Add custom regex pattern |
| `<leader>hm` | Open interactive Floating HUD Manager (Tabs: Highlights & Bookmarks) |
| `<leader>hs` | Toggle Treesitter function scope-bounded highlight |
| `<leader>hp` | Select and load preset (`logs`, `http`, `sql`, etc.) |
| `<leader>hq` | Export all active matches to Quickfix list (All Buffers) |
| `<leader>hf` | Search all matches across **All Open Buffers** via Telescope / Snacks (`<C-b>` to toggle) |
| `<leader>hF` | Search matches in **Current Buffer Only** in the bottom buffer pane |
| `<leader>hc` | Clear all active highlights |
| `]h` / `[h` | Jump to next / previous match of current slot |
| `]H` / `[H` | Jump to next / previous match across ALL active slots |

### 🔖 Bookmarks & Tag Categorization
| Keybinding | Action |
|---|---|
| `<leader>hk` | Toggle bookmark on line with note prompt (empty note uses highlighted text) |
| `<leader>hK` | Quick bookmark toggle (no prompt, immediately uses highlighted line/selection) |
| `<leader>hl` | List & search bookmarks across all files (Telescope / Snacks / Bottom Pane) |
| `<leader>hL` | Open bottom buffer window listing all bookmarks (`t` to filter by tag) |
| `<leader>ht` | Filter bookmarks by tag (`TODO`, `FIXME`, `WARN`, `NOTE`, `HACK`) with count picker |
| `]k` / `[k` | Jump to next / previous bookmark |

#### 🏷️ Tag Prefixes & Custom Highlights
Bookmarks automatically detect tag prefixes from your note or comment text (case-insensitive, supporting `TODO:`, `[TODO]`, `FIXME:`, `BUG:`, etc.):

| Tag Prefix | Icon | Theme Color | Sign & Line Style |
|---|---|---|---|
| `FIXME`, `BUG`, `ISSUE` | 🔥 | Crimson Red | `SmartBookmarkSign_FIXME`, Red tinted line bg, `[FIXME]` badge |
| `TODO`, `TASK` | 📌 | Sky Blue / Cyan | `SmartBookmarkSign_TODO`, Blue tinted line bg, `[TODO]` badge |
| `WARN`, `WARNING`, `CAUTION` | ⚠️ | Amber Orange | `SmartBookmarkSign_WARN`, Amber tinted line bg, `[WARN]` badge |
| `NOTE`, `INFO`, `TIP` | 📝 | Mint Green | `SmartBookmarkSign_NOTE`, Green tinted line bg, `[NOTE]` badge |
| `HACK`, `PERF`, `OPTIMIZE` | ⚡ | Lavender / Purple | `SmartBookmarkSign_HACK`, Purple tinted line bg, `[HACK]` badge |
| General (no prefix) | 🔖 | Warm Gold | `SmartBookmarkSign`, Neutral grey tinted line bg |

---

## 🕹️ Floating HUD Keybindings

Inside the HUD window (`<leader>hm`):

| Key | Action |
|---|---|
| `m` / `<Tab>` | Switch between **Highlights** and **Bookmarks** tab |
| `t` | Filter bookmarks by tag (`TODO`, `FIXME`, etc.) in Bookmarks tab |
| `A` | Reset filter to show all bookmarks in Bookmarks tab |
| `<CR>` | Jump to selected bookmark (in Bookmarks tab) |
| `<Space>` | Toggle enable/disable on selected highlight slot |
| `b` | Toggle selected slot scope between **All Buffers** and **Current Buffer** |
| `B` | Toggle global default scope (**All Buffers** ⟷ **Current Buffer**) |
| `e` | Edit bookmark note (in Bookmarks tab) |
| `d` / `x` | Delete selected slot or bookmark |
| `a` / `+` | Add new pattern or bookmark |
| `p` | Open presets selector |
| `c` | Clear all slots or bookmarks |
| `Q` | Export to Quickfix / Bottom Pane |
| `q` / `<Esc>` | Close HUD |

---

## ⚡ User Commands

### Highlighting
- `:SmartHighlightToggle [all|current]` - Toggle highlight (optionally forcing all or current buffer)
- `:SmartHighlightBuffer [word]` - Highlight word in current buffer only
- `:SmartHighlightGlobal [word]` - Highlight word across all open buffers
- `:SmartHighlightBufferScope [all|current|toggle]` - Switch or toggle default buffer scope mode
- `:SmartHighlightBottom [all|current]` - Open bottom buffer window showing matches
- `:SmartHighlightRegex <pattern>` - Add custom regex pattern
- `:SmartHighlightClear [slot_id]` - Clear highlights
- `:SmartHighlightHUD` - Open Floating HUD Manager
- `:SmartHighlightPreset <logs|http|sql|json|devops>` - Load preset
- `:SmartHighlightScope` - Toggle Treesitter scope highlight
- `:SmartHighlightQuickfix [all|current]` - Export matches to Quickfix (default: all open buffers)
- `:SmartHighlightSearch [all|current]` - Search matches via Telescope / Snacks (default: all open buffers, `<C-b>` toggles scope)
### Bookmarks & Tags
- `:SmartBookmarkToggle [note]` - Toggle bookmark on current line with note prompt
- `:SmartBookmarkQuick` - Quick toggle bookmark without prompt
- `:SmartBookmarkNext [tag]` / `:SmartBookmarkPrev [tag]` - Jump to next/prev bookmark (optionally filtered by tag)
- `:SmartBookmarkSearch [tag|all|current]` - Search bookmarks via Telescope / Snacks (supports `<C-t>` to switch tags)
- `:SmartBookmarkBottom [tag|all|current]` - Open bottom buffer window for bookmarks (press `t` to filter tags)
- `:SmartBookmarkFilter [tag]` - Filter bookmarks by tag with interactive count selector
- `:SmartBookmarkClear` - Clear all bookmarks
- `:SmartBookmarkHUD` - Open HUD directly on Bookmarks tab

### 💾 Repo-Local Persistence, Import/Export & Auto-Persist
Highlights and bookmarks are automatically saved to `.smart-highlighter.json` in the root of your git repository using **relative paths**, ensuring they work across clones, machines, worktrees, and multiple workspaces.

- `:SmartHighlightSave [filepath]` - Save active highlights and bookmarks to repo `.smart-highlighter.json` (or custom path)
- `:SmartHighlightLoad [filepath]` - Load highlights and bookmarks from repo `.smart-highlighter.json` (or custom path)
- `:SmartHighlightExport [filepath]` - Export highlights & bookmarks to a JSON file
- `:SmartHighlightImport [filepath]` - Import highlights & bookmarks from a JSON file
- `:SmartBookmarkExport [filepath]` - Export bookmarks to `.smart-highlighter.json`
- `:SmartBookmarkImport [filepath]` - Import bookmarks from `.smart-highlighter.json`
- `:SmartHighlightAutoPersist [on|off|toggle]` - Toggle automatic background persistence (saves debounced on changes, buffer write, and exit)
