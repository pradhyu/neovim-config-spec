 # Neovim Configuration Specification (`LAZY-SPEC.md`)

> **Note for AI Agents & LLMs:**
> This document is a standalone declarative specification for reproducing this Neovim environment on any machine. When instructed to configure a fresh machine or Neovim instance, read this spec and generate the corresponding Lua configuration files in `~/.config/nvim/`.

---

## 1. Base Setup & Foundation
* **Framework:** [LazyVim](https://www.lazyvim.org/) starter template.
* **Neovim Version:** `>= 0.10.0`
* **External CLI Dependencies:**
  * `ripgrep` (`rg`) - for fast project search.
  * `fd` - for fast file search.
  * `agy` (Antigravity CLI) - for AI pair programming.
  * `helix` (`hx`) - installed as secondary editor.

---

## 2. Plugin Inventory & Specifications

### A. Color Schemes & Theme Switcher
* **`zaldih/themery.nvim`**: Interactive theme switcher with instant live preview.
  * Keymaps: `<leader>th` and `<leader>uC` $\rightarrow$ `:Themery`
  * Preloaded theme list: `tokyonight-night`, `tokyonight-storm`, `tokyonight-moon`, `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte`, `kanagawa-wave`, `kanagawa-dragon`, `kanagawa-lotus`, `rose-pine-main`, `rose-pine-moon`, `rose-pine-dawn`, `cyberdream`, `gruvbox`, `everforest`, `solarized-osaka`, `onedark`, `nightfox`, `duskfox`, `nordfox`, `carbonfox`, `terafox`.
* **Themes Installed:**
  1. `catppuccin/nvim` (`mocha`, `macchiato`, `frappe`, `latte`)
  2. `rebelot/kanagawa.nvim` (`wave`, `dragon`, `lotus`)
  3. `rose-pine/neovim` (`main`, `moon`, `dawn`)
  4. `EdenEast/nightfox.nvim` (`nightfox`, `duskfox`, `nordfox`, `carbonfox`, `terafox`)
  5. `scottmckendry/cyberdream.nvim` (Neon cyberpunk high contrast)
  6. `ellisonleao/gruvbox.nvim` (Hard/medium contrast)
  7. `neanias/everforest-nvim` (Earthy green tones)
  8. `craftzdog/solarized-osaka.nvim` (Modern solarized)
  9. `navarasu/onedark.nvim` (Deep / dark atom style)
  10. `folke/tokyonight.nvim` (Default LazyVim dark blue)

### B. AI & Agent Integration
* **`folke/sidekick.nvim`**:
  * Tools: `antigravity` (`cmd = { "agy" }`)
  * Keymaps:
    * `<leader>aa`: Toggle Antigravity terminal split
    * `<leader>as`: Send visual selection / buffer context to Antigravity
* **`folke/snacks.nvim`**:
  * Keymap: `<leader>ag` $\rightarrow$ Floating terminal running `agy` (85% width/height, rounded border).
* **`antigravity.nvim`**: Local remote RPC helper for Antigravity skills.

### C. Custom / Specialized Plugins
* **`nepali-calendar.nvim`** (Local repo: `~/git/neovim-nepali-calendar`):
  * Keymaps:
    * `<leader>nc`: Toggle Nepali Calendar popup
    * `<leader>nt`: Show today's Bikram Sambat date
    * `<leader>nu`: Update festivals and events
    * `<leader>ns`: Search Nepali festivals
    * `<leader>nd`: Date converter (BS $\leftrightarrow$ AD)
* **`json-plot.nvim`** (Local repo: `~/git/neovim-json-visualizer`):
  * Commands: `:JsonPlot`, `:JsonPlotReload`

---

## 3. Core Keymaps & Custom Logic (`lua/config/keymaps.lua`)

### A. Smart `gf` & Link/File Resolver
Replaces standard `gf`, `<CR>` (in markdown/terminal), and `<C-LeftMouse>` with an intelligent multi-strategy resolver:
1. **Markdown Links:** Automatically extracts target from `[title](path_or_url)`.
2. **`file://` URIs & Line Ranges:** Strips `file://` and parses `#L17-L80`, `#L17-80`, `:17-100`, `:15:3`, `(15)`.
3. **Fuzzy & Hierarchical Search:**
   * Checks current working directory (`cwd`).
   * Searches parent folders up to `$HOME` (`vim.fs.find(..., { upward = true })`).
   * Checks `~/.config/nvim/` and `~/.config/nvim/lua/`.
   * Searches by basename across project root.
4. **Web URLs:** Opens `https?://` URLs via `vim.ui.open` (`gx`).
5. **Terminal Window Preservation:** When invoked from inside a terminal or sidekick split, switches focus to the main editor window before opening the target file.

### B. Additional Keybindings
* `<Esc><Esc>` in Terminal mode (`t`): `<C-\><C-n>` (Exit to terminal normal mode).
* `<leader>*` in Normal mode: Ripgrep word under cursor across project using Telescope.
* `grepprg`: Set to `rg --vimgrep --smart-case`.

---

## 4. Instructions for LLM Agent Configuring a New Machine

When asked to setup Neovim on another machine using this spec:
1. Ensure Neovim `>= 0.10` and `git` are installed.
2. If `~/.config/nvim` does not exist, clone the standard LazyVim starter.
3. Write `~/.config/nvim/lua/plugins/colorschemes.lua` with the theme list and `themery.nvim`.
4. Write `~/.config/nvim/lua/plugins/antigravity.lua` with `sidekick.nvim` and `snacks.nvim` configs.
5. Write `~/.config/nvim/lua/config/keymaps.lua` containing the smart `gf` resolver and navigation keymaps.
6. Launch Neovim in headless mode or execute `nvim --headless "+Lazy! sync" +qa` to pull all plugins automatically.
