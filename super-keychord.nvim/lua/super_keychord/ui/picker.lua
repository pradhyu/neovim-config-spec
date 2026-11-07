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
    return displayer({
      { string.format("[%s]", e.mode:upper()), "Directory" },
      { e.display_lhs, "Bold" },
      { "➔", "Comment" },
      { desc, e.desc ~= "" and "Normal" or "Comment" },
    })
  end

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
