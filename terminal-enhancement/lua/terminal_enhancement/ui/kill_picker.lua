local terminal = require("terminal_enhancement.core.terminal")

local M = {}

---Open an interactive multi-select floating window to select and kill multiple terminals
function M.open()
  local active = terminal.get_active_terminals()
  if #active == 0 then
    vim.notify("[TermEnhance] No running terminals to kill.", vim.log.levels.INFO)
    return
  end

  -- Selection state: map from terminal id -> boolean
  local selected = {}

  -- Create scratch unlisted buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal_kill_picker", { buf = buf })

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local width = math.min(math.max(math.floor(total_w * 0.65), 60), total_w - 4)
  local height = math.min(#active + 5, math.floor(total_h * 0.6))
  local row = math.floor((total_h - height) / 2)
  local col = math.floor((total_w - width) / 2)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🛑 Kill Terminals (Multi-Select) ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title,CursorLine:Visual",
    { win = win }
  )

  -- Namespace for extmarks/highlights
  local ns_id = vim.api.nvim_create_namespace("terminal_kill_picker")

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local lines = {}
    table.insert(lines, "  Keys: <Space>/<Tab>: toggle | <a>: all | <h>: hidden | <CR>: kill marked | <q>: exit")
    table.insert(lines, string.rep("─", width - 2))

    local marked_count = 0
    for _, item in ipairs(active) do
      local is_marked = selected[item.id] == true
      if is_marked then
        marked_count = marked_count + 1
      end
      local check = is_marked and "[✔]" or "[ ]"
      local state_icon = item.is_open and "🟢" or "⚪"
      local state_desc = item.is_open and "Visible" or "Background"
      local def_badge = item.is_default and " [ACTIVE TARGET]" or ""
      local line = string.format(" %s %s %s (%s, Buf #%d)%s", check, state_icon, item.title, state_desc, item.buf, def_badge)
      table.insert(lines, line)
    end

    table.insert(lines, string.rep("─", width - 2))
    table.insert(lines, string.format("  ➤ %d of %d terminal(s) marked for termination", marked_count, #active))

    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    -- Apply highlights
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    -- Header & Separator highlights
    vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "FloatBorder", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "FloatBorder", #lines - 2, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, marked_count > 0 and "DiagnosticWarn" or "Comment", #lines - 1, 0, -1)

    -- Row highlights
    for idx, item in ipairs(active) do
      local row_idx = idx + 1
      local is_marked = selected[item.id] == true
      if is_marked then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "DiagnosticError", row_idx, 1, 4) -- [✔]
      else
        vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", row_idx, 1, 4) -- [ ]
      end
      if item.is_default then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "DiagnosticWarn", row_idx, 0, -1)
      end
    end
  end

  local function get_item_at_cursor()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line_idx = cursor[1] - 2 -- 1-based index into active array
    if line_idx >= 1 and line_idx <= #active then
      return active[line_idx], line_idx
    end
    return nil, nil
  end

  local function toggle_cursor()
    local item, _ = get_item_at_cursor()
    if item then
      selected[item.id] = not selected[item.id]
      render()
      local curr = vim.api.nvim_win_get_cursor(win)
      if curr[1] < #active + 2 then
        vim.api.nvim_win_set_cursor(win, { curr[1] + 1, curr[2] })
      end
    end
  end

  local function toggle_all()
    local all_marked = true
    for _, item in ipairs(active) do
      if not selected[item.id] then
        all_marked = false
        break
      end
    end

    for _, item in ipairs(active) do
      selected[item.id] = not all_marked
    end
    render()
  end

  local function toggle_hidden()
    for _, item in ipairs(active) do
      if not item.is_open then
        selected[item.id] = true
      end
    end
    render()
  end

  local function invert_selection()
    for _, item in ipairs(active) do
      selected[item.id] = not selected[item.id]
    end
    render()
  end

  local function execute_kill()
    local targets = {}
    for _, item in ipairs(active) do
      if selected[item.id] then
        table.insert(targets, item.id)
      end
    end

    -- If no items explicitly checked, kill the item under cursor
    if #targets == 0 then
      local item, _ = get_item_at_cursor()
      if item then
        table.insert(targets, item.id)
      end
    end

    if #targets == 0 then
      vim.notify("[TermEnhance] No terminals selected to kill.", vim.log.levels.WARN)
      return
    end

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end

    local killed = 0
    for _, id in ipairs(targets) do
      local ok, _ = terminal.kill(id)
      if ok then
        killed = killed + 1
      end
    end

    vim.notify(string.format("[TermEnhance] 🧹 Terminated %d selected terminal(s).", killed), vim.log.levels.INFO)
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Initial render and position cursor on first terminal line
  render()
  vim.api.nvim_win_set_cursor(win, { 3, 2 })

  -- Keybindings inside the picker
  local opts = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<Space>", toggle_cursor, opts)
  vim.keymap.set("n", "<Tab>", toggle_cursor, opts)
  vim.keymap.set("n", "a", toggle_all, opts)
  vim.keymap.set("n", "h", toggle_hidden, opts)
  vim.keymap.set("n", "v", invert_selection, opts)
  vim.keymap.set("n", "<CR>", execute_kill, opts)
  vim.keymap.set("n", "d", execute_kill, opts)
  vim.keymap.set("n", "x", execute_kill, opts)
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
end

return M
