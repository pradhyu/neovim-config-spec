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
---@field mode "project"|"state"|"both" "project" (writes to project root .smart-highlighter.json) or "state" (stdpath state cache)
---@field file string Filename for project-local storage (default: ".smart-highlighter.json")
---@field auto_persist boolean Automatically save highlights & bookmarks on changes and buffer write/leave
---@field auto_load boolean Automatically discover and load project-local or cached session on startup / dir change
---@field relative_paths boolean Store relative paths in project session file so bookmarks work across clones/machines

---@class SmartHighlightOptions
---@field max_slots integer
---@field whole_word boolean
---@field case_sensitive boolean
---@field treesitter_scope boolean
---@field buffer_scope "all"|"current" Default scope: "all" for all open buffers, "current" for active buffer only
---@field current_buffer_search "bottom_pane"|"picker" How to display current buffer search: "bottom_pane" (bottom window) or "picker" (telescope)
---@field persistence SmartPersistenceConfig|boolean
---@field default_keymaps boolean
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
    mode = "project", -- "project" writes .smart-highlighter.json in repo root
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
    toggle_bookmark = "<leader>hk",
    quick_bookmark = "<leader>hK",
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
