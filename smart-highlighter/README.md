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
- **🔍 Quickfix & Telescope Export**: Instantly export all highlighted occurrences to the Quickfix list or live search via Telescope (`<leader>hq`, `<leader>hf`).
- **💾 Session Persistence**: Automatically preserves active highlights per project workspace across restarts.

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

| Keybinding | Action |
|---|---|
| `<leader>hh` | Toggle highlight on word under cursor or visual selection |
| `<leader>hH` | Add custom regex pattern |
| `<leader>hm` | Open interactive Floating HUD Manager |
| `<leader>hs` | Toggle Treesitter function scope-bounded highlight |
| `<leader>hp` | Select and load preset (`logs`, `http`, `sql`, etc.) |
| `<leader>hq` | Export all active matches to Quickfix list |
| `<leader>hf` | Search all matches via Telescope |
| `<leader>hc` | Clear all active highlights |
| `]h` / `[h` | Jump to next / previous match of current slot |
| `]H` / `[H` | Jump to next / previous match across ALL active slots |

---

## 🕹️ Floating HUD Keybindings

Inside the HUD window (`<leader>hm`):

| Key | Action |
|---|---|
| `<Space>` / `<Tab>` | Toggle enable/disable on selected slot |
| `d` / `x` | Delete selected slot |
| `a` / `+` | Add new word or regex pattern |
| `p` | Open presets selector |
| `c` | Clear all slots |
| `Q` | Export to Quickfix |
| `q` / `<Esc>` | Close HUD |

---

## ⚡ User Commands

- `:SmartHighlightToggle`
- `:SmartHighlightRegex <pattern>`
- `:SmartHighlightClear [slot_id]`
- `:SmartHighlightHUD`
- `:SmartHighlightPreset <logs|http|sql|json|devops>`
- `:SmartHighlightScope`
- `:SmartHighlightQuickfix`
- `:SmartHighlightSearch`
- `:SmartHighlightSave` / `:SmartHighlightLoad`
