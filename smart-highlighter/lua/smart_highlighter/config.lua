local M = {}

---@class SmartHighlightPresetConfig
---@field enabled boolean
---@field auto_by_filetype boolean
---@field filetype_map table<string, string>

---@class SmartBookmarkConfig
---@field enabled boolean
---@field sign_text string
---@field virt_text boolean
---@field line_highlight boolean
---@field default_scope "all"|"current"

---@class SmartPersistenceConfig
---@field enabled boolean
---@field mode "git"|"project"|"state" "git" (writes to .git/smart-highlighter/<branch>.json, 100% private to local clone), "project" (.smart-highlighter.json), or "state" (stdpath state cache)
---@field branch_scoped boolean Isolate bookmarks per git branch so switching branches loads that branch's bookmarks
---@field reconcile_lines boolean Fuzzy re-anchor bookmarks if lines shifted between branches
---@field watch_head boolean Reactively watch .git/HEAD with libuv fs_event for zero-overhead branch switching
---@field file string Filename for project-local storage (when mode is "project")
---@field auto_persist boolean Automatically save highlights & bookmarks on changes and buffer write/leave
---@field auto_load boolean Automatically discover and load session on startup / branch switch / dir change
---@field relative_paths boolean Store relative paths in session file

---@class SmartHighlightOptions
---@field max_slots integer
---@field whole_word boolean
---@field case_sensitive boolean
---@field treesitter_scope boolean
---@field buffer_scope "all"|"current" Default scope: "all" for all open buffers, "current" for active buffer only
---@field current_buffer_search "bottom_pane"|"picker" How to display current buffer search: "bottom_pane" (bottom window) or "picker" (telescope)
---@field persistence SmartPersistenceConfig|boolean
---@field default_keymaps boolean
---@field alt_keymaps boolean
---@field keymaps table<string, string|boolean>
---@field debounce_ms integer
---@field palette string "modern"|"neon"|"pastel"|"solarized"
---@field presets SmartHighlightPresetConfig
---@field bookmarks SmartBookmarkConfig

---@type SmartHighlightOptions
M.defaults = {
  max_slots = 16,
  whole_word = true,
  case_sensitive = false,
  treesitter_scope = false,
  buffer_scope = "all", -- "all" (highlight all open buffers) or "current" (highlight only active buffer)
  current_buffer_search = "bottom_pane", -- "bottom_pane" (bottom window) or "picker" (telescope)
  persistence = {
    enabled = true,
    mode = "git", -- "git" writes to .git/smart-highlighter/<branch>.json (100% local, never dirty, zero git checkout conflicts)
    branch_scoped = true, -- Auto-isolate bookmarks per git branch
    reconcile_lines = true, -- Content-anchored fuzzy re-anchoring when lines shift
    watch_head = true, -- Libuv fs_event reactive .git/HEAD watcher (zero CPU polling)
    file = ".smart-highlighter.json",
    auto_persist = true, -- Auto-persist bookmarks and highlights on changes
    auto_load = true,    -- Auto-load on enter/dir change
    relative_paths = true,
  },
  default_keymaps = true,
  alt_keymaps = true, -- Enable Option/Alt key shortcuts (<M-b>, <M-B>, <M-h>, <M-m>)
  keymaps = {
    -- Highlighting
    toggle = "<leader>hh",
    toggle_buffer = "<leader>hb",
    toggle_scope_mode = "<leader>hB",
    add_regex = "<leader>hH",
    clear_all = "<leader>hc",
    open_hud = "<leader>hm",
    select_preset = "<leader>hp",
    toggle_treesitter = "<leader>hs",
    export_quickfix = "<leader>hq",
    search_matches = "<leader>hf",
    search_matches_buffer = "<leader>hF",

    -- Bookmarks
    add_bookmark = "<leader>hk",
    quick_add_bookmark = "<leader>hK",
    toggle_global_bookmarks = "<leader>hx",
    delete_bookmark = "<leader>hd",
    clear_bookmarks = "<leader>hD",
    search_bookmarks = "<leader>hl",
    bottom_bookmarks = "<leader>hL",
    filter_bookmarks = "<leader>ht",

    -- Persistence & Options
    toggle_auto_persist = "<leader>hP",
    export_session = "<leader>he",
    import_session = "<leader>hE",
    save_session = "<leader>hS",
    load_session = "<leader>hR",

    -- Navigation
    jump_next = "]h",
    jump_prev = "[h",
    jump_any_next = "]H",
    jump_any_prev = "[H",
    jump_bookmark_next = "]k",
    jump_bookmark_prev = "[k",

    -- Option / Alt Key Fast Shortcuts
    alt_toggle_bookmark = "<M-b>",
    alt_quick_bookmark = "<M-B>",
    alt_toggle_highlight = "<M-h>",
    alt_open_hud = "<M-m>",
  },
  debounce_ms = 80,
  palette = "modern",
  bookmarks = {
    enabled = true,
    sign_text = "🔖",
    virt_text = true,
    line_highlight = true,
    default_scope = "all",
  },
  presets = {
    enabled = true,
    auto_by_filetype = true,
    filetype_map = {
      log = "logs",
      text = "logs",
      http = "http",
      rest = "http",
      sql = "sql",
      mysql = "sql",
      psql = "sql",
      json = "json",
    },
  },
}

---@type SmartHighlightOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options with defaults
---@param user_opts? table
function M.setup(user_opts)
  local opts = user_opts or {}
  if type(opts.persistence) == "boolean" then
    opts.persistence = { enabled = opts.persistence }
  end
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  if type(M.options.persistence) == "boolean" then
    M.options.persistence = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults.persistence), { enabled = M.options.persistence })
  end
  return M.options
end

return M
