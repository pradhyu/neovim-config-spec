local engine = require("smart_highlighter.core.engine")

local M = {}

---Export all highlighted matches in current buffer to Neovim Quickfix list
---@param buf? integer
function M.export_to_quickfix(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local qf_list = {}
  local buf_name = vim.api.nvim_buf_get_name(target_buf)

  for id, slot in pairs(engine.slots) do
    if slot.enabled then
      local matches = engine.get_matches(id, target_buf)
      for _, m in ipairs(matches) do
        local line_text = vim.api.nvim_buf_get_lines(target_buf, m.row - 1, m.row, false)[1] or ""
        table.insert(qf_list, {
          bufnr = target_buf,
          filename = buf_name,
          lnum = m.row,
          col = m.col + 1,
          text = string.format("[Slot #%d: %s] %s", id, slot.name or slot.pattern, line_text),
        })
      end
    end
  end

  if #qf_list == 0 then
    vim.notify("[SmartHighlight] No highlighted occurrences found to export", vim.log.levels.WARN)
    return
  end

  -- Sort by line number and column
  table.sort(qf_list, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  vim.fn.setqflist(qf_list, "r")
  vim.fn.setqflist({}, "a", { title = "Smart Highlights" })
  vim.cmd("copen")
  vim.notify(string.format("[SmartHighlight] Exported %d matches to Quickfix list", #qf_list), vim.log.levels.INFO)
end

---Open Telescope picker if telescope is available, otherwise fallback to Quickfix
function M.telescope_picker()
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  local _, finders = pcall(require, "telescope.finders")
  local _, conf = pcall(require, "telescope.config")
  local _, entry_display = pcall(require, "telescope.pickers.entry_display")

  if not has_telescope then
    M.export_to_quickfix()
    return
  end

  local target_buf = vim.api.nvim_get_current_buf()
  local results = {}

  for id, slot in pairs(engine.slots) do
    if slot.enabled then
      local matches = engine.get_matches(id, target_buf)
      for _, m in ipairs(matches) do
        local line_text = vim.api.nvim_buf_get_lines(target_buf, m.row - 1, m.row, false)[1] or ""
        table.insert(results, {
          slot_id = id,
          slot_name = slot.name or slot.pattern,
          row = m.row,
          col = m.col,
          text = line_text,
          match_text = m.text,
        })
      end
    end
  end

  if #results == 0 then
    vim.notify("[SmartHighlight] No active highlighted matches in current buffer", vim.log.levels.WARN)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 8 },
      { width = 6 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    return displayer({
      { string.format("#%d", entry.value.slot_id), string.format("SmartHighlightSlot%d", entry.value.slot_id) },
      { string.format("L:%d", entry.value.row), "Comment" },
      { entry.value.text },
    })
  end

  pickers.new({}, {
    prompt_title = "Smart Highlight Matches",
    finder = finders.new_table({
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = string.format("%s %s %s", entry.slot_name, entry.match_text, entry.text),
          lnum = entry.row,
          col = entry.col + 1,
          bufnr = target_buf,
        }
      end,
    }),
    previewer = conf.values.grep_previewer({}),
    sorter = conf.values.generic_sorter({}),
  }):find()
end

return M
