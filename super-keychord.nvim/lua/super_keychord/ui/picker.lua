local keychords = require("super_keychord.core.keychords")
local config = require("super_keychord.config")

local M = {}

---Format a human-readable display string for vim.ui.select fallback
---@param entry KeychordEntry
---@return string
local function format_ui_select(entry)
  local mode_badge = string.format("[%s]", entry.mode:upper())
  local buf_badge = entry.buffer and string.format(" [buf %d]", entry.buffer) or ""
  local desc = entry.desc ~= "" and entry.desc or (entry.rhs ~= "" and entry.rhs or "[No Description]")
  return string.format("%-4s %-20s ➔ %s%s", mode_badge, entry.display_lhs, desc, buf_badge)
end

---Build search text combining lhs, clean lhs, description, rhs, mode
---@param entry KeychordEntry
---@return string
local function build_search_text(entry)
  return string.format("%s %s %s %s %s mode:%s",
    entry.display_lhs,
    entry.clean_lhs,
    entry.raw_lhs,
    entry.desc,
    entry.rhs,
    entry.mode
  )
end

---Snacks.picker backend for super-keychord
---@param list KeychordEntry[]
---@param opts? table
local function open_snacks_picker(list, opts)
  local items = {}
  for idx, entry in ipairs(list) do
    table.insert(items, {
      idx = idx,
      score = idx,
      text = build_search_text(entry),
      entry = entry,
    })
  end

  Snacks.picker({
    title = string.format(" 🎹 Keychords (%s mode) ", (opts and opts.mode) or "all"),
    items = items,
    format = function(item)
      local e = item.entry
      local mode_hl = ({
        n = "DiagnosticInfo",
        v = "DiagnosticWarn",
        x = "DiagnosticWarn",
        i = "DiagnosticOk",
        t = "DiagnosticError",
        c = "DiagnosticHint",
        o = "DiagnosticOk",
      })[e.mode] or "Comment"

      local mode_str = string.format(" [%s] ", e.mode:upper())
      local chord_str = string.format("%-18s", e.display_lhs)
      local desc_str = e.desc ~= "" and e.desc or e.rhs
      if #desc_str > 45 then
        desc_str = desc_str:sub(1, 42) .. "..."
      end

      local row = {
        { mode_str, mode_hl },
        { chord_str, "Bold" },
        { " ➔ ", "SnacksPickerDelim" },
        { desc_str, e.desc ~= "" and "Normal" or "Comment" },
      }

      if e.usage_count and e.usage_count > 0 then
        table.insert(row, { string.format(" 🔥 %dx", e.usage_count), "DiagnosticWarn" })
      end

      if e.buffer then
        table.insert(row, { string.format(" [buf %d]", e.buffer), "DiagnosticHint" })
      end

      return row
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.entry then
        if config.options.execute_on_select then
          vim.schedule(function()
            keychords.execute_keychord(item.entry)
          end)
        else
          vim.notify(string.format("[SuperKeychord] Chord: %s ➔ %s", item.entry.display_lhs, item.entry.desc ~= "" and item.entry.desc or item.entry.rhs), vim.log.levels.INFO)
        end
      end
    end,
  })
end

---Telescope backend for super-keychord
---@param list KeychordEntry[]
---@param opts? table
local function open_telescope_picker(list, opts)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if not has_telescope then
    return false
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 5 },
      { width = 20 },
      { width = 2 },
      { remaining = true },
    },
  })

  local make_display = function(item)
    local e = item.value
    local desc = e.desc ~= "" and e.desc or e.rhs
    local freq_badge = (e.usage_count and e.usage_count > 0) and string.format(" 🔥%d", e.usage_count) or ""
    return displayer({
      { string.format("[%s]", e.mode:upper()), "Directory" },
      { e.display_lhs .. freq_badge, "Bold" },
      { "➔", "Comment" },
      { desc, e.desc ~= "" and "Normal" or "Comment" },
    })
  end

  local previewers = require("telescope.previewers")
  local chord_previewer = previewers.new_buffer_previewer({
    title = "Keychord Details",
    define_preview = function(self, entry, status)
      local e = entry.value
      local mode_name = ({
        n = "Normal",
        v = "Visual / Select",
        x = "Visual",
        i = "Insert",
        t = "Terminal",
        c = "Command-Line",
        o = "Operator-Pending",
      })[e.mode] or string.format("Mode '%s'", e.mode)

      local scope_str = e.buffer and string.format("Buffer-Local (buf #%d)", e.buffer) or "Global"
      local desc_str = e.desc ~= "" and e.desc or "[No human description provided]"
      local action_str = e.rhs ~= "" and e.rhs or (e.callback and "[Lua Callback Function]" or "[None]")
      local usage_str = (e.usage_count and e.usage_count > 0)
        and string.format("%d times (🔥 Frecency Boost Active)", e.usage_count)
        or "0 times (Not yet tracked)"

      local lines = {
        "  🎹 KEYCHORD INSPECTOR",
        "  " .. string.rep("─", 45),
        string.format("  • Chord:       %s", e.display_lhs),
        string.format("  • Raw Key:     %s", e.raw_lhs),
        string.format("  • Mode:        %s [%s]", mode_name, e.mode:upper()),
        string.format("  • Scope:       %s", scope_str),
        string.format("  • Usage:       %s", usage_str),
        "",
        "  📖 ACTION & DESCRIPTION",
        "  " .. string.rep("─", 45),
        string.format("  • Description: %s", desc_str),
        string.format("  • Target/RHS:  %s", action_str),
        "",
        "  ⚙️ KEYMAP ATTRIBUTES",
        "  " .. string.rep("─", 45),
        string.format("  • Noremap:     %s", e.noremap and "Yes" or "No"),
        string.format("  • Silent:      %s", e.silent and "Yes" or "No"),
        string.format("  • Nowait:      %s", e.nowait and "Yes" or "No"),
        string.format("  • Expression:  %s", e.expr and "Yes" or "No"),
        "",
        "  💡 Press <CR> to execute this keychord immediately",
      }

      vim.bo[self.state.bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.bo[self.state.bufnr].modifiable = false

      vim.api.nvim_buf_clear_namespace(self.state.bufnr, -1, 0, -1)
      vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "Title", 0, 2, -1)
      vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "Title", 7, 2, -1)
      vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "Title", 12, 2, -1)
      vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "Comment", 19, 2, -1)
    end,
  })

  pickers.new({}, {
    prompt_title = string.format("Search Keychords (%s mode)", (opts and opts.mode) or "all"),
    finder = finders.new_table({
      results = list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = build_search_text(entry),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = chord_previewer,
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          if config.options.execute_on_select then
            vim.schedule(function()
              keychords.execute_keychord(selection.value)
            end)
          end
        end
      end)
      return true
    end,
  }):find()

  return true
end

---Open the super keychord search picker
---@param opts? table Options: mode ("n", "v", "i", "t", "all"), buf (integer)
function M.open(opts)
  opts = opts or {}
  local mode = opts.mode or config.options.default_mode
  local buf = opts.buf
  local list = keychords.get_keychords(mode, buf)

  if #list == 0 then
    vim.notify(string.format("[SuperKeychord] No keychords found for mode '%s'", mode), vim.log.levels.INFO)
    return
  end

  local backend = config.options.backend

  -- Snacks Picker
  if (backend == "auto" or backend == "snacks") and rawget(_G, "Snacks") and Snacks.picker then
    open_snacks_picker(list, opts)
    return
  end

  -- Telescope Picker
  if (backend == "auto" or backend == "telescope") then
    if open_telescope_picker(list, opts) then
      return
    end
  end

  -- Fallback: vim.ui.select
  vim.ui.select(list, {
    prompt = string.format("SuperKeychord (%s mode):", mode:upper()),
    format_item = format_ui_select,
  }, function(choice)
    if choice and config.options.execute_on_select then
      keychords.execute_keychord(choice)
    end
  end)
end

return M
