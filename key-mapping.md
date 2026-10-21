# Neovim Keymapping Specification & Portable Guide

A centralized reference and portable keymapping guide for this workspace and any external Neovim environment.

---

## 1. Terminal Mode (`t` Mode) — Core & Portable Keymaps

In default Neovim, exiting terminal input mode back to Normal mode requires typing `<C-\><C-n>`, which is awkward and slow.

These mappings make the terminal mode intuitive, fast, and seamless to navigate across windows.

### Keybinding Summary

| Keybinding | Mode | Action | Target / Behavior |
| :--- | :---: | :--- | :--- |
| **`<Esc><Esc>`** | `t` | **Exit Terminal Mode** | Replaces `<C-\><C-n>` to switch directly to Normal mode |
| **`<C-h>`** | `t` | **Window Left** | Switches to the window on the left without exiting first |
| **`<C-j>`** | `t` | **Window Down** | Switches to the window below |
| **`<C-k>`** | `t` | **Window Up** | Switches to the window above |
| **`<C-l>`** | `t` | **Window Right** | Switches to the window on the right |
| **`<Esc><Esc><Esc>`** | `t`, `n` | **Quick Close/Hide** | Hides/closes the current terminal split or float |
| **`<C-q>`** | `t` | **Quick Close** | Quick-closes the current terminal buffer |

> [!TIP]
> **Why `<Esc><Esc>` instead of single `<Esc>`?**
> A single `<Esc>` is intercepted by interactive CLI applications running inside your terminal (e.g., `fzf`, `lazygit`, `htop`, shell vi-mode, or an embedded `vim`/`nano`). Using `<Esc><Esc>` guarantees that a single `<Esc>` passes through to CLI programs cleanly, while double-tapping instantly drops you back into Neovim's Normal mode.

---

### Copy-Paste Snippets for Any Neovim Setup

#### Option A: Modern Neovim (Lua: `init.lua` or `lua/keymaps.lua`)

```lua
-- =============================================================================
-- Terminal Mode Mappings (Portable)
-- =============================================================================

-- Double <Esc> to exit terminal mode to normal mode (replaces <C-\><C-n>)
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Seamless window navigation directly from terminal mode
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Go to left window" })
vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Go to lower window" })
vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Go to upper window" })
vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Go to right window" })

-- Auto enter insert mode when switching into a terminal buffer
vim.api.nvim_create_autocmd({ "BufEnter", "TermOpen" }, {
  pattern = "term://*",
  callback = function()
    vim.cmd("startinsert")
  end,
})
```

#### Option B: Classic Neovim / Vimscript (`init.vim` or `.vimrc`)

```vim
" =============================================================================
" Terminal Mode Mappings (Portable Vimscript)
" =============================================================================

" Double <Esc> to exit terminal mode to normal mode
tnoremap <Esc><Esc> <C-\><C-n>

" Seamless window navigation directly from terminal mode
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" Auto enter insert mode when switching to terminal
autocmd BufEnter,TermOpen term://* startinsert
```

---

## 2. Core Editor & Link Resolver Keymaps (`lua/config/keymaps.lua`)

| Keybinding | Mode | Action | Description |
| :--- | :---: | :--- | :--- |
| **`gf`** | `n`, `v` | **Smart Open** | Resolves markdown links, URLs, `file://` URIs, and path:line:col references |
| **`<C-LeftMouse>`** | `n` | **Smart Click** | Follows link / file under cursor on mouse click |
| **`<CR>`** | `n` (md/term) | **Follow Link** | Follows links and stacktraces directly in Markdown and Terminal buffers |
| **`<leader>*`** | `n` | **Project Grep** | Ripgreps the word under the cursor across the entire workspace |

---

## 3. Spec Plugins Keymap Matrix

### A. Terminal Enhancement (`terminal-enhancement.nvim`)

| Keybinding | Mode | Command | Action |
| :--- | :---: | :--- | :--- |
| **`<leader>tt`** | `n` | `:TermToggle` | Toggle default terminal instance |
| **`<leader>tl`** / **`<leader>ts`** | `n` | `:TermPicker` | Interactive terminal switcher and fuzzy finder |
| **`<A-t>`** | `n`, `t` | Interactive Switcher | Direct popup switcher accessible from anywhere |
| **`<leader>tf`** | `n` | `:TermFloat` | Toggle floating terminal |
| **`<leader>th`** | `n` | `:TermSplit horizontal` | Toggle horizontal bottom split |
| **`<leader>tv`** | `n` | `:TermSplit vertical` | Toggle vertical right split |
| **`<leader>ti`** | `n` | `:TermPrompt` | Terminal prompt with fish-style ghost text autocomplete |
| **`<leader>tz`** / **`<leader>tZ`** | `n` | `:TermHide` / `:TermHideAll` | Hide active / Hide all terminal windows |
| **`<leader>tu`** / **`<leader>tU`** | `n` | `:TermUnhide` / `:TermUnhideAll` | Interactive unhide picker / Unhide all |
| **`<leader>tss`** | `n` | `:TermSend line` | Send current line to terminal |
| **`<leader>tsb`** | `n` | `:TermSend block` | Send enclosed code block |
| **`<leader>tsn`** | `n` | `:TermSend step` | Send line and advance cursor |
| **`<leader>tsf`** | `n` | `:TermSend file` | Send entire buffer |
| **`<leader>ts`** | `n`, `v` | `:TermSend` | Send current visual selection |
| **`<leader>tsh`** | `n` | `:TermHistory` | View command execution history modal |
| **`<leader>tso`** | `n` | `:TermOutcome` | View last command outcome modal |
| **`<leader>tsy`** | `n` | `:TermCopyOutput` | Copy last outcome to system clipboard |
| **`<leader>tr`** | `n` | `:TermRename` | Rename terminal session |
| **`<leader>tk`** | `n` | `:TermKill` | Interactive multi-select terminal killer |
| **`<leader>tX`** | `n` | `:TermClean` | Terminate all hidden/background terminals |
| **`<leader>tg`** | `n` | `tool("lazygit")` | Dedicated LazyGit floating terminal |
| **`<leader>top`** | `n` | `tool("htop")` | Dedicated `htop` monitor floating terminal |

### B. Smart Highlighter & Bookmarks (`smart-highlighter.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>hh`** | `n`, `v` | Toggle highlight slot under cursor or selection |
| **`<leader>hb`** | `n` | Toggle highlight strictly in current buffer |
| **`<leader>hB`** | `n` | Toggle scope (Current buffer ↔ All open buffers) |
| **`<leader>hH`** | `n` | Highlight custom regex pattern |
| **`<leader>hm`** | `n` | Open floating Highlighter HUD Manager |
| **`<leader>hs`** | `n` | Scope highlight to enclosing Treesitter block |
| **`<leader>hp`** | `n` | Select highlight preset (DevOps, Logs, HTTP, SQL, JSON) |
| **`<leader>hq`** | `n` | Export all active highlights to Quickfix list |
| **`<leader>hc`** | `n` | Clear all highlight slots |
| **`]h`** / **`[h`** | `n` | Jump to next / previous match of current slot |
| **`]H`** / **`[H`** | `n` | Jump to next / previous match across all slots |
| **`<leader>hk`** | `n` | Toggle bookmark with prompt note |
| **`<leader>hK`** | `n` | Quick bookmark toggle without prompt |
| **`<leader>hl`** | `n` | Fuzzy search / list bookmarks |
| **`<leader>hL`** | `n` | Open bookmarks bottom drawer pane |
| **`]k`** / **`[k`** | `n` | Jump to next / previous bookmark |

### C. Buffer Buddy (`buffer-buddy.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>B`** / **`<leader>BB`** | `n` | Open Buffer Buddy Dashboard & Inspector |
| **`<leader>Bb`** | `n` | Toggle Buffer Breadcrumbs Winbar on/off |
| **`<leader>Bn`** | `n` | Rename Workspace Tab |
| **`<leader>BN`** | `n` | Create New Workspace Tab |
| **`<leader>Bm`** | `n` | Move Buffer to Workspace Tab |
| **`<leader>Bx`** | `n` | Safely close tab and sweep exclusive buffers |
| **`<leader>Bp`** | `n` | Toggle local pin protection (protects from tab sweeps) |
| **`<leader>BP`** | `n` | Toggle global pin protection 🌐 (visible in all tabs) |
| **`<leader>bc`** / **`<leader>Bc`** | `n` | Safely close current buffer (preserves split layout) |
| **`<leader>bC`** / **`<leader>BC`** | `n` | Sweep all unmodified / clean buffers |
| **`<leader>bh`** / **`<leader>Bh`** | `n` | Sweep all hidden buffers |
| **`<leader>bo`** / **`<leader>Bo`** | `n` | Sweep all other buffers except current |
| **`<leader>bj`** / **`<leader>Bj`** | `n`, `v` | Prettify / format JSON selection or buffer |
| **`<leader>bt`** / **`<leader>Bt`** | `n` | Trim trailing whitespace across buffer |
| **`<leader>bs`** / **`<leader>Bs`** | `n` | Open scratchpad buffer selector |
| **`<leader>bS`** / **`<leader>BS`** | `n` | Create named snapshot checkpoint |
| **`<leader>bR`** / **`<leader>BR`** | `n` | Revert buffer to previous snapshot checkpoint |
| **`<leader>Bd`** | `n` | Diff active buffer against saved disk file |
| **`<leader>BD`** | `n` | Diff active buffer against system clipboard |

### D. Command Cockpit (`cmd-cockpit.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>k`** / **`<leader>kk`** / **`<leader>kc`** | `n` | Open Command Cockpit Hub |
| **`<leader>kf`** | `n` | Open Frequent Commands launcher |
| **`<leader>km`** | `n` | Open Interactive Keymap Matrix Browser |
| **`<leader>kr`** | `n` | Open Interactive Keymap Remapper |
| **`<leader>ks`** | `n` | View command usage analytics |
| **`<leader>ke`** | `n` | Export keymap overrides to Lua configuration |

### E. Performance Lens (`perf-lens.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>up`** | `n` | Performance Dashboard |
| **`<leader>uP`** | `n` | Plugin Manager & Toggler |
| **`<leader>ua`** | `n` | Optimization Advisor |
| **`<leader>uw`** | `n` | Startup Waterfall Timeline |
| **`<leader>um`** | `n` | Lua Memory & GC Inspector |

### F. REST Master (`rest-master.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>rr`** | `n` (`.http`) | Execute REST request under cursor |
| **`<leader>re`** | `n` | Select active REST environment (dev, staging, prod) |
| **`<leader>rh`** | `n` | View REST request history |
| **`<leader>rH`** | `n` | Manage environment headers and tokens |

### G. Nepali Calendar (`nepali-calendar.nvim`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>nc`** | `n` | Toggle Nepali Calendar popup (पात्रो) |
| **`<leader>nt`** | `n` | Show today's Bikram Sambat (BS) date |
| **`<leader>nu`** | `n` | Fetch and update festivals & holidays |
| **`<leader>ns`** | `n` | Search upcoming festivals |
| **`<leader>nd`** | `n` | Open Date Converter tool (BS ↔ AD) |

### H. JSON Visualizer (`neovim-json-visualizer`)

| Keybinding | Mode | Action |
| :--- | :---: | :--- |
| **`<leader>jp`** | `n` | Render JSON Gantt plot / timeline diagram |
| **`<leader>jP`** | `n` | Reload JSON plot plugin module |
