local tabs = require("buffer_buddy.core.tabs")

local M = {}

---Format tab information for display in fallback selector
---@param item table
---@return string
local function format_tab_item(item)
  local active_mark = item.is_active and " ⭐ (active)" or ""
  local buf_summary = #item.buffers > 0 and table.concat(item.buffers, ", ") or "empty"
  if #buf_summary > 40 then
    buf_summary = buf_summary:sub(1, 37) .. "..."
  end
  return string.format("[%d] 󰓩 %-15s (%d bufs: %s)%s",
    item.num,
    item.name,
    #item.buffers,
    buf_summary,
    active_mark
  )
end

---Collect items for tab picker
---@return table[]
local function get_tab_items()
  local all_tabs = vim.api.nvim_list_tabpages()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local items = {}

  for _, t in ipairs(all_tabs) do
    local num = vim.api.nvim_tabpage_get_number(t)
    local name = tabs.get_tab_name(t)
    local custom_name = tabs.get_custom_tab_name(t)
    local bufs = tabs.get_tab_buffers(t)
    local is_active = (t == cur_tab)

    local buf_names = {}
    for _, b in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(b) then
        local bname = vim.api.nvim_buf_get_name(b)
        local short = bname ~= "" and vim.fn.fnamemodify(bname, ":t") or string.format("Buf #%d", b)
        table.insert(buf_names, short)
      end
    end

    local search_text = string.format("%d %s %s", num, name, table.concat(buf_names, " "))

    table.insert(items, {
      tab = t,
      num = num,
      name = name,
      custom_name = custom_name,
      buffers = buf_names,
      is_active = is_active,
      search_text = search_text,
    })
  end

  return items
end

---Switch to selected tabpage
---@param tab integer Tabpage handle
local function switch_to_tab(tab)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    vim.notify("[BufferBuddy] Selected tab is no longer valid", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_set_current_tabpage(tab)
  tabs.sync_tab_scoping()
  tabs.update_all_tab_names()
  tabs.refresh_tabline()
end

---Open tab search / picker using Snacks.picker, Telescope, or vim.ui.select
---@param opts? table
function M.open(opts)
  opts = opts or {}
  local items = get_tab_items()

  if #items == 0 then
    vim.notify("[BufferBuddy] No workspace tabs found", vim.log.levels.INFO)
    return
  end

  -- 1. Try Snacks.picker if available
  if _G.Snacks and Snacks.picker then
    local picker_items = {}
    for idx, item in ipairs(items) do
      table.insert(picker_items, {
        idx = idx,
        score = idx,
        text = item.search_text,
        item = item,
      })
    end

    Snacks.picker({
      title = " 📑 Search Workspace Tabs ",
      items = picker_items,
      format = function(entry)
        local it = entry.item
        local num_str = string.format(" %d ", it.num)
        local active_tag = it.is_active and " ⭐ CURRENT" or ""
        local buf_list = #it.buffers > 0 and table.concat(it.buffers, ", ") or "(empty)"

        local row = {
          { num_str, it.is_active and "SnacksPickerSpecial" or "SnacksPickerIdx" },
          { " 󰓩 " .. it.name, "Bold" },
          { string.format("  (%d buffers: %s)", #it.buffers, buf_list), "Comment" },
        }
        if it.is_active then
          table.insert(row, { active_tag, "DiagnosticOk" })
        end
        return row
      end,
      confirm = function(picker, entry)
        picker:close()
        if entry and entry.item then
          switch_to_tab(entry.item.tab)
        end
      end,
    })
    return
  end

  -- 2. Try Telescope if available
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if has_telescope then
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local entry_display = require("telescope.pickers.entry_display")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 6 },
        { width = 20 },
        { width = 12 },
        { remaining = true },
      },
    })

    local make_display = function(entry)
      local it = entry.value
      local active_tag = it.is_active and "⭐ (active)" or ""
      return displayer({
        { string.format("Tab %d", it.num), "Directory" },
        { "󰓩 " .. it.name, "Bold" },
        { active_tag, "DiagnosticOk" },
        { string.format("(%d: %s)", #it.buffers, table.concat(it.buffers, ", ")), "Comment" },
      })
    end

    pickers.new({}, {
      prompt_title = "Search Workspace Tabs (BufferBuddy)",
      finder = finders.new_table({
        results = items,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.search_text,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value then
            switch_to_tab(selection.value.tab)
          end
        end)
        return true
      end,
    }):find()
    return
  end

  -- 3. Fallback to vim.ui.select
  vim.ui.select(items, {
    prompt = "Select Workspace Tab:",
    format_item = format_tab_item,
  }, function(choice)
    if choice then
      switch_to_tab(choice.tab)
    end
  end)
end

return M
