local engine = require("smart_highlighter.core.engine")
local config = require("smart_highlighter.config")

local M = {}

---Get target buffers based on scope ("all" open buffers vs "current" active buffer)
---@param scope? "all"|"current"|"buffer"|"global"
---@return integer[]
local function get_target_buffers(scope)
  local bufs = {}
  if scope == "current" or scope == "buffer" then
    table.insert(bufs, vim.api.nvim_get_current_buf())
  else
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        local bt = vim.bo[buf].buftype
        local name = vim.api.nvim_buf_get_name(buf)
        -- Exclude scratch, terminal, and tool buffers
        if (bt == "" or bt == "acwrite") and name ~= "" then
          table.insert(bufs, buf)
        end
      end
    end
    -- Fallback: if no valid named file buffers found, include current buffer
    if #bufs == 0 then
      table.insert(bufs, vim.api.nvim_get_current_buf())
    end
  end
  return bufs
end

---Open bottom buffer window (Quickfix pane) displaying highlighted matches
---@param scope_or_buf? integer|string "current"|"all" or specific bufnr
function M.open_bottom_pane(scope_or_buf)
  local target_bufs = {}
  local is_all = true

  if type(scope_or_buf) == "number" then
    table.insert(target_bufs, scope_or_buf)
    is_all = false
  elseif scope_or_buf == "current" or scope_or_buf == "buffer" then
    table.insert(target_bufs, vim.api.nvim_get_current_buf())
    is_all = false
  else
    target_bufs = get_target_buffers("all")
  end

  local qf_list = {}
  for _, buf in ipairs(target_bufs) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local short_name = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":~:.") or string.format("[Buf #%d]", buf)
      local line_count = vim.api.nvim_buf_line_count(buf)
      local lines = line_count > 0 and vim.api.nvim_buf_get_lines(buf, 0, line_count, false) or {}

      for id, slot in pairs(engine.slots) do
        if slot.enabled then
          local matches = engine.get_matches(id, buf)
          for _, m in ipairs(matches) do
            local line_text = lines[m.row] or ""
            local prefix = is_all
              and string.format("[#%d %s] %s ", id, slot.name or slot.pattern, short_name)
              or string.format("[#%d %s] ", id, slot.name or slot.pattern)

            table.insert(qf_list, {
              bufnr = buf,
              filename = buf_name,
              lnum = m.row,
              col = m.col + 1,
              text = prefix .. line_text,
            })
          end
        end
      end
    end
  end

  if #qf_list == 0 then
    local scope_desc = is_all and "all open buffers" or "current buffer"
    vim.notify(string.format("[SmartHighlight] No highlighted occurrences found in %s", scope_desc), vim.log.levels.WARN)
    return
  end

  -- Sort by bufnr, line number, and column
  table.sort(qf_list, function(a, b)
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  vim.fn.setqflist(qf_list, "r")
  local title = is_all and "Smart Highlights [All Open Buffers]" or "Smart Highlights [Current Buffer]"
  vim.fn.setqflist({}, "a", { title = title })

  -- Open cleanly at the bottom across full screen width
  local height = math.min(10, math.max(4, #qf_list))
  vim.cmd(string.format("botright copen %d", height))

  -- Add comfortable close keymaps inside the bottom quickfix buffer
  local qf_win = vim.api.nvim_get_current_win()
  local qf_buf = vim.api.nvim_win_get_buf(qf_win)
  vim.keymap.set("n", "q", "<cmd>cclose<cr>", { buffer = qf_buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>cclose<cr>", { buffer = qf_buf, silent = true, nowait = true })

  vim.notify(string.format("[SmartHighlight] Opened %d matches (%s) in bottom buffer pane", #qf_list, is_all and "All Open Buffers" or "Current Buffer"), vim.log.levels.INFO)
end

---Export matches to Neovim Quickfix list (alias for open_bottom_pane)
M.export_to_quickfix = M.open_bottom_pane

---Open Telescope (or Snacks / Bottom pane) picker
---@param opts? { scope?: "all"|"current", target_buf?: integer }
function M.telescope_picker(opts)
  opts = opts or {}
  local scope = opts.scope or "all"

  -- If current buffer is requested and current_buffer_search is "bottom_pane", open bottom buffer window!
  if (scope == "current" or scope == "buffer") and config.options.current_buffer_search == "bottom_pane" then
    M.open_bottom_pane("current")
    return
  end

  local target_bufs = get_target_buffers(scope)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  local _, finders = pcall(require, "telescope.finders")
  local _, conf = pcall(require, "telescope.config")
  local _, entry_display = pcall(require, "telescope.pickers.entry_display")

  -- Collect matches across target buffers
  local results = {}
  for _, buf in ipairs(target_bufs) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local short_name = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":~:.") or string.format("[Buffer #%d]", buf)
      local line_count = vim.api.nvim_buf_line_count(buf)
      local lines = line_count > 0 and vim.api.nvim_buf_get_lines(buf, 0, line_count, false) or {}

      for id, slot in pairs(engine.slots) do
        if slot.enabled then
          local matches = engine.get_matches(id, buf)
          for _, m in ipairs(matches) do
            local line_text = lines[m.row] or ""
            table.insert(results, {
              bufnr = buf,
              filename = buf_name,
              short_name = short_name,
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
    end
  end

  if #results == 0 then
    local scope_desc = scope == "all" and "all open buffers" or "current buffer"
    vim.notify(string.format("[SmartHighlight] No active highlighted matches found in %s", scope_desc), vim.log.levels.WARN)
    return
  end

  -- 1. Telescope Picker (showing all open buffers)
  if has_telescope then
    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 6 },
        { width = 28 },
        { remaining = true },
      },
    })

    local make_display = function(entry)
      local loc = string.format("%s:%d", entry.value.short_name, entry.value.row)
      if #loc > 28 then
        loc = "..." .. loc:sub(#loc - 24)
      end
      return displayer({
        { string.format("#%d", entry.value.slot_id), string.format("SmartHighlightSlot%d", entry.value.slot_id) },
        { loc, "Directory" },
        { entry.value.text },
      })
    end

    local title_scope = scope == "all" and "All Open Buffers" or "Current Buffer"

    pickers.new({}, {
      prompt_title = string.format("Smart Highlight Matches [%s] (Ctrl+B: current buffer bottom pane)", title_scope),
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = string.format("%s %s %s %s", entry.short_name, entry.slot_name, entry.match_text, entry.text),
            filename = entry.filename,
            bufnr = entry.bufnr,
            lnum = entry.row,
            col = entry.col + 1,
          }
        end,
      }),
      previewer = conf.values.grep_previewer({}),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        map({ "i", "n" }, "<C-b>", function()
          local actions = require("telescope.actions")
          actions.close(prompt_bufnr)
          M.open_bottom_pane("current")
        end)
        return true
      end,
    }):find()
    return
  end

  -- 2. Snacks Picker Fallback (for LazyVim)
  if _G.Snacks and _G.Snacks.picker then
    local items = {}
    for _, r in ipairs(results) do
      table.insert(items, {
        file = r.filename,
        buf = r.bufnr,
        pos = { r.row, r.col },
        line = r.text,
        text = string.format("[#%d] %s", r.slot_id, r.text),
        item = r,
      })
    end
    local title_scope = scope == "all" and "All Open Buffers" or "Current Buffer"
    _G.Snacks.picker.pick({
      title = string.format("Smart Highlight Matches [%s]", title_scope),
      items = items,
      format = "file",
    })
    return
  end

  -- 3. Fallback to bottom buffer pane
  M.open_bottom_pane(scope)
end

return M
