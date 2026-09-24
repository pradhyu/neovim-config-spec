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
  * `mermaid-cli` (`mmdc`) - for compiling Mermaid diagrams into terminal images.
  * `helix` (`hx`) - secondary modal editor.

---

## 2. Plugin Inventory & Specifications

### A. Projects & Multi-Workspace Management (VSCode-like)
* **`folke/snacks.nvim` (Projects & Search Suite)**:
  * Automatically indexes repositories in `~/git`, `~/projects`, `~/workspace`, and `~/.config`.
  * Detects project roots using `.git`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`.
  * **Search & Grep Capabilities:**
    * `<leader>fb` / `<leader>,`: Search **Buffer Names & Paths** (finds buffers by file path / name).
    * `<leader>sB`: **Grep Open Buffers** (searches / greps actual text & content across all loaded buffers and active terminals).
    * `<leader>sb`: **Buffer Lines** (fuzzy search / grep text within current active buffer).
    * `<leader>/` or `<leader>sg`: **Live Grep** across entire project workspace.
    * `<leader>sw` / `<leader>sW`: **Grep Word** under cursor across workspace.
    * `<leader><space>` / `<leader>ff`: **Find Files** in workspace.
    * `<leader>fp` or `<leader>sp`: **Find & Switch Projects / Workspaces**.
  * **Commands & Fuzzy Palette:**
    * `<leader>:`: **Command History Picker** (fuzzy search previous commands with live preview).
    * `<leader>sC`: **All Commands Palette** (fuzzy search every Neovim & plugin command).
* **`folke/persistence.nvim` (Session & Workspace State)**:
  * Saves and restores full buffer lists, tab layouts, and cursor positions per project and per git branch.
  * Keymaps:
    * `<leader>qs`: Restore current workspace session
    * `<leader>qS`: Select from saved workspace sessions
    * `<leader>ql`: Restore last session
    * `<leader>qd`: Don't save current session

### B. Color Schemes & Theme Switcher
* **`zaldih/themery.nvim`**: Interactive theme switcher with instant live preview.
  * Keymaps: `<leader>uC` or `<leader>uT` $\rightarrow$ `:Themery`
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

### C. AI & Agent Integration
* **`folke/sidekick.nvim`**:
  * Tools: `antigravity` (`cmd = { "agy" }`)
  * Keymaps:
    * `<leader>aa`: Toggle Antigravity terminal split
    * `<leader>as`: Send visual selection / buffer context to Antigravity
* **`folke/snacks.nvim`**:
  * Keymap: `<leader>ag` $\rightarrow$ Floating terminal running `agy` (85% width/height, rounded border).
* **`antigravity.nvim`**: Local remote RPC helper for Antigravity skills.

### D. Markdown & Documentation
* **`lazyvim.plugins.extras.lang.markdown`**:
  * **`MeanderingProgrammer/render-markdown.nvim`**: Full in-buffer rich rendering of Markdown tables, callout blocks (`> [!NOTE]`), interactive checkboxes, styled headings, and code block badges.
  * **`iamcco/markdown-preview.nvim`**: Real-time browser preview with synchronous scrolling and interactive Mermaid graphs.
* **`folke/snacks.nvim` (Image & Mermaid Rendering)**:
  * In-buffer graphical rendering of Mermaid diagrams (`flowchart`, `sequenceDiagram`, `erDiagram`, etc.) and image attachments directly within Ghostty/Kitty-compatible terminals via `mermaid-cli` (`mmdc`).

### E. Custom / Specialized Plugins Developed
* **`harness-use-neovim`** (Repo: `pkshrestha/harness-use-neovim`, Local: `~/git/harness-use-neovim`):
  * High-performance, 100% pure Lua remote bridge for Neovim pairing with AI harnesses (Antigravity, Claude, etc.) and terminal subshells.
  * **Key Features:**
    * Full RPC execution (`eval`, `expr`, `exec`, `keys`, `call`) with structured JSON or raw text return values.
    * Complete buffer, window, tab, cursor, and visual selection manipulation.
    * In-editor UI popups, toasts (`vim.notify`), and side-by-side diffs.
    * Seamless `$EDITOR` / `GIT_EDITOR` blocking wait mode (`nvim-cli.lua edit --wait`) eliminating nested Neovim sessions inside `:terminal`.
    * Autocmd event pub/sub streaming (`BufWritePost`, `CursorMoved`, `User`, etc.).
    * Dynamic hot-reloading (`:NvimCLIReload` or `nvim-cli.lua reload`) without restarting Neovim.
  * **Commands:** `:NvimCLI info`, `:NvimCLI reload`, `:NvimCLI socket`, `:NvimCLIReload`, `:NvimCLISocket`

* **`rest-master.nvim`** (Repo: `pkshrestha/rest-master`, Local: `~/git/rest-master`):
  * Powerful, native Neovim REST API client and HTTP request runner with live response split, syntax highlighting, environment variables, and header management.
  * **Commands:** `:RestMasterRun`, `:RestMasterEnv`, `:RestMasterHistory`, `:RestMasterHeaders`

* **`neovim-send-to-terminal`** (Repo: `pkshrestha/neovim-send-to-terminal`, Local: `~/git/neovim-send-to-terminal`):
  * Smart code/command dispatcher to active Neovim terminal buffers with markdown code-block awareness, command filtering, and multi-terminal target routing.
  * **Commands:** `:SendToTerminal`, `:SendToTerminalSelect`, `:SendToTerminalBlock`

* **`nepali-calendar.nvim`** (Repo: `pkshrestha/neovim-nepali-calendar`, Local: `~/git/neovim-nepali-calendar`):
  * Bikram Sambat (BS) Nepali calendar in Neovim with upcoming festival reminders, daily tithi, and date conversion (BS $\leftrightarrow$ AD).
  * **Keymaps:**
    * `<leader>nc`: Toggle Nepali Calendar popup
    * `<leader>nt`: Show today's Bikram Sambat date
    * `<leader>nu`: Update festivals and events
    * `<leader>ns`: Search Nepali festivals
    * `<leader>nd`: Date converter (BS $\leftrightarrow$ AD)

* **`json-plot.nvim`** (Local repo: `~/git/neovim-json-visualizer`):
  * In-editor JSON visualizer and data plotter.
  * **Commands:** `:JsonPlot`, `:JsonPlotReload`

* **`nvim-perf-lens.nvim`** (Local repo: `~/git/neovim-config-spec/perf-lens`):
  * Performance profiler, frame-drop jitter detector, on-demand plugin manager, and automated optimization advisor.
  * **Commands:** `:PerfLens`, `:PerfLens plugins`, `:PerfLens advisor`, `:PerfLens waterfall`, `:PerfLens disable <plugin>`, `:PerfLens enable <plugin>`, `:PerfLens memory`, `:PerfLens export`
  * **Keymaps:**
    * `<leader>up`: Toggle Performance Lens Dashboard
    * `<leader>uP`: Interactive Plugin Manager & On-Demand Toggler
    * `<leader>ua`: Optimization Advisor Rules & Code Snippets
    * `<leader>uw`: Startup Waterfall Timeline View
    * `<leader>um`: Lua Memory and Garbage Collection

* **`terminal-enhancement.nvim`** (Local repo: `~/git/neovim-config-spec/terminal-enhancement`):
  * Multi-direction persistent terminals, atomic multi-line code runners, multi-select process termination, dynamic terminal renaming, and smart compiler/stacktrace link navigation.
  * **Key Features:**
    * **Multi-Line Continuation & Auto-Expansion:** Automatically detects `\` (Bash/Zsh) and `` ` `` (PowerShell) continuations. Selecting any single line of a multi-line command automatically captures and sends the entire command.
    * **Atomic Bracketed Paste:** Wraps multi-line code blocks in `\e[200~ ... \e[201~` with auto-dedent to prevent premature execution.
    * **Multi-Select Process Killer:** Floating UI (`<Space>`, `a`, `h`, `<CR>`) to selectively or batch terminate background terminal processes.
    * **One-Key Background Purge:** Instantly terminates hidden terminals and frees PTYs/memory (`:TermClean`).
    * **Dynamic Renaming:** Runtime terminal and buffer renaming (`term://<name>`).
    * **Universal Quick-Close:** `q` (in Normal mode) and `<C-q>` (in Terminal mode) uniformly closes/hides floats, horizontal splits, and vertical splits.
  * **Commands:** `:TermToggle`, `:TermFloat`, `:TermSplit`, `:TermTool`, `:TermRun`, `:TermSend`, `:TermSendJoined`, `:TermSelect`, `:TermTarget`, `:TermRename`, `:TermBuffer`, `:TermList`, `:TermKill`, `:TermClean`, `:TermKillHidden`, `:TermKillAll`
  * **Keymaps:**
    * `<leader>tt`: Toggle Default Floating Terminal
    * `<leader>tf`: Toggle Centered Floating Terminal
    * `<leader>th`: Toggle Horizontal Bottom Split Terminal
    * `<leader>tv`: Toggle Vertical Right Split Terminal
    * `<leader>ts`: Send current line / selection with Bracketed Paste (auto-expands multi-line commands)
    * `<leader>tS`: Send lines joined with `\` (Bash) or `` ` `` (PowerShell)
    * `<leader>tc`: Interactive prompt to select/change target terminal
    * `<leader>tr`: Rename terminal session
    * `<leader>tk`: Interactive Multi-Select Terminal Killer
    * `<leader>tX`: Clean all background/hidden terminal buffers
    * `<leader>tB`: Open terminal directly as a regular buffer in current window
    * `<leader>tg`: Open LazyGit Popup Terminal
    * `<leader>top`: Open htop Process Monitor Terminal

* **`smart-highlighter.nvim`** (Local repo: `~/git/neovim-config-spec/smart-highlighter`):
  * Ultra-fast, 16-slot multi-keyword, pattern, regex, and Treesitter scope-aware visual highlighter with floating HUD and match navigation.
  * **Key Features:**
    * **16-Slot Dynamic Palette:** Theme-adaptive light/dark color slots with high contrast and luminescence.
    * **Treesitter Scope Bounded Highlighting:** Confines highlight matches strictly to enclosing function/method/block AST scope (`<leader>hs`).
    * **Presets Suite:** Instant activation for Log Analysis (`ERROR`, `WARN`, `INFO`, UUIDs, IPs), HTTP/REST APIs, SQL queries, JSON, and DevOps statuses (`<leader>hp`).
    * **Floating HUD Dashboard:** Visual manager with live occurrence counters, toggle switches, regex additions, and slot purges (`<leader>hm`).
    * **Bidirectional Match Navigation:** Jump between matches for current slot (`]h`/`[h`) or across all active slots (`]H`/`[H`).
    * **Quickfix & Telescope Export:** Push all matches with file locations to Quickfix or live search via Telescope (`<leader>hq`, `<leader>hf`).
    * **Persistence:** Auto-saves and restores active patterns across sessions per workspace directory.
  * **Commands:** `:SmartHighlightToggle`, `:SmartHighlightRegex`, `:SmartHighlightClear`, `:SmartHighlightHUD`, `:SmartHighlightPreset`, `:SmartHighlightScope`, `:SmartHighlightQuickfix`, `:SmartHighlightSearch`, `:SmartHighlightSave`, `:SmartHighlightLoad`
  * **Keymaps:**
    * `<leader>hh`: Toggle highlight on word under cursor or visual selection
    * `<leader>hH`: Prompt for custom regex pattern to highlight
    * `<leader>hm`: Open interactive Floating HUD Manager
    * `<leader>hs`: Toggle Treesitter scope-bounded highlight
    * `<leader>hp`: Select & load preset (Logs, HTTP, SQL, JSON, DevOps)
    * `<leader>hq`: Export all active matches to Quickfix list
    * `<leader>hf`: Fuzzy search matches via Telescope
    * `<leader>hc`: Clear all highlights
    * `]h` / `[h`: Jump to next / previous match of current slot
    * `]H` / `[H`: Jump to next / previous match across ALL active slots

* **`buffer-buddy.nvim`** (Local repo: `~/git/neovim-config-spec/buffer-buddy`):
  * Comprehensive buffer companion: Intelligent hygiene sweeper, text transformation toolkit, buffer pinning, floating scratchpads, in-memory snapshots, disk diffing, and buffer inspection.
  * **Key Features:**
    * **Intelligent Hygiene Sweepers:** Closes unmodified, hidden, dead, or other buffers while strictly protecting pinned buffers (`<leader>bC`, `<leader>bh`, `<leader>bo`).
    * **Buffer Pinning:** Lock crucial files so automated cleaners and mass closures never close them (`<leader>bp`).
    * **Transformation Toolkit:** Format/minify JSON, Base64 encode/decode, URL encode/decode, deduplicate lines, sort lines, strip trailing whitespace, and align Markdown tables (`<leader>bj`, `<leader>bt`).
    * **In-Memory Undo Snapshots:** Create named checkpoints for any buffer before risky refactoring and revert instantly (`<leader>bS`, `<leader>bR`).
    * **Live Diff Utilities:** Compare unsaved buffer changes against the saved file on disk, or diff against the system clipboard (`<leader>bd`, `<leader>bD`).
    * **Multi-Language Scratchpads:** Floating or split scratchpads in Markdown, Lua, SQL, JSON, Python, or Bash (`<leader>bs`).
    * **Buffer Inspector HUD:** Live dashboard displaying lines, words, LLM token estimations, encoding, fileformat, and one-touch action triggers (`<leader>bb`).
  * **Commands:** `:BufferBuddy`, `:BufferPin`, `:BufferUnpin`, `:BufferTogglePin`, `:BufferSweep`, `:BufferDiffDisk`, `:BufferDiffClipboard`, `:BufferScratch`, `:BufferSnapshot`, `:BufferRestore`, `:BufferTransform`, `:BufferJSON`
  * **Keymaps:**
    * `<leader>bj` / `<leader>Bj`: Format / Prettify JSON buffer or selection
    * `<leader>bt` / `<leader>Bt`: Trim trailing whitespace
    * `<leader>bs` / `<leader>Bs`: Open interactive Scratchpad selector
    * `<leader>bS` / `<leader>BS`: Create named in-memory Snapshot checkpoint
    * `<leader>bR` / `<leader>BR`: Revert buffer to a Snapshot checkpoint
    * `<leader>bc` / `<leader>Bc`: Close current buffer safely (preserving window layout)
    * `<leader>bC` / `<leader>BC`: Sweep all unmodified buffers
    * `<leader>bh` / `<leader>Bh`: Sweep all hidden buffers
    * `<leader>B` / `<leader>BB`: Open interactive Buffer Buddy Dashboard & Inspector
    * `<leader>Bp`: Toggle Pin on current buffer
    * `<leader>Bd`: Diff buffer vs saved disk file
    * `<leader>BD`: Diff buffer vs system clipboard
    * `<leader>Bo`: Sweep all other buffers

* **`cmd-cockpit.nvim`** (Local repo: `~/git/neovim-config-spec/cmd-cockpit`):
  * Command frequency tracker, global keybinding matrix inspector, and interactive runtime remapper.
  * **Key Features:**
    * **Command Tracker & Frecency Engine:** Tracks executed Ex commands with usage counts, timestamps, and Frecency ranking (`<leader>kf`).
    * **Global Keymap Matrix:** Inspects and searches all active keymaps across Normal, Visual, Insert, Terminal, and Commandline modes with collision detection (`<leader>km`).
    * **Runtime Remapper & Overrides:** Interactive remapping dialogue with instant validation and collision warnings (`<leader>kr`).
    * **Lua Overrides Export:** Cleanly exports all custom overrides to `~/.config/nvim/lua/config/keymap_overrides.lua` (`<leader>ke`).
    * **Interactive Cockpit HUD:** 3-tab dashboard with 1-9 instant execution keys and mode cycling (`<leader>k`, `<leader>kk`, `<leader>kc`).
  * **Commands:** `:CmdCockpit`, `:CmdFrequent`, `:CmdKeymaps`, `:CmdRemap`, `:CmdResetOverrides`, `:CmdExportOverrides`, `:CmdStats`
  * **Keymaps:**
    * `<leader>k` / `<leader>kk` / `<leader>kc`: Open Command Cockpit Hub
    * `<leader>kf`: Open Frequent Commands launcher
    * `<leader>km`: Open Keymap Browser Matrix
    * `<leader>kr`: Open Interactive Remapper
    * `<leader>ks`: View Command Usage Analytics
    * `<leader>ke`: Export Overrides to Lua File

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
* `<Esc><Esc><Esc>` in Terminal mode (`t`) / Normal mode (`n`): Quick-closes/hides the active terminal window (just like `q`).
* `<leader>*` in Normal mode: Ripgrep word under cursor across project using Telescope.
* `grepprg`: Set to `rg --vimgrep --smart-case`.

---

## 4. Instructions for LLM Agent Configuring a New Machine

When asked to setup Neovim on another machine using this spec:
1. Ensure Neovim `>= 0.10` and `git` are installed.
2. If `~/.config/nvim` does not exist, clone the standard LazyVim starter.
3. Write `~/.config/nvim/lua/plugins/projects.lua` with the project picker and branch session persistence.
4. Write `~/.config/nvim/lua/plugins/colorschemes.lua` with the theme list and `themery.nvim`.
5. Write `~/.config/nvim/lua/plugins/antigravity.lua` with `sidekick.nvim` and `snacks.nvim` configs.
6. Write `~/.config/nvim/lua/config/keymaps.lua` containing the smart `gf` resolver and navigation keymaps.
 . Launch Neovim in headless mode or execute `nvim --headless "+Lazk! sync" +qa` to pull all plugins automatically.
