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

### 🔖 Bookmarks
| Keybinding | Action |
|---|---|
| `<leader>hk` | Toggle bookmark on line with note prompt (empty note uses highlighted text) |
| `<leader>hK` | Quick bookmark toggle (no prompt, immediately uses highlighted line/selection) |
| `<leader>hl` | List & search bookmarks across all files (Telescope / Snacks / Bottom Pane) |
| `<leader>hL` | Open bottom buffer window listing all bookmarks |
| `]k` / `[k` | Jump to next / previous bookmark |

---

## 🕹️ Floating HUD Keybindings

Inside the HUD window (`<leader>hm`):

| Key | Action |
|---|---|
| `m` / `<Tab>` | Switch between **Highlights** and **Bookmarks** tab |
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
- `:SmartHighlightSave` / `:SmartHighlightLoad` - Save or restore session highlights

### Bookmarks
- `:SmartBookmarkToggle [note]` - Toggle bookmark on line (prompts for note; empty uses highlighted text)
- `:SmartBookmarkQuick` - Quick bookmark without prompting
- `:SmartBookmarkNext` / `:SmartBookmarkPrev` - Jump to next / previous bookmark
- `:SmartBookmarkSearch [all|current]` - Search bookmarks via Telescope / Snacks
- `:SmartBookmarkBottom [all|current]` - Open bottom buffer window for bookmarks
- `:SmartBookmarkClear` - Clear all bookmarks
- `:SmartBookmarkHUD` - Open HUD directly on Bookmarks tab
