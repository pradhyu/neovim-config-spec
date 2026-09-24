local terminal = require("terminal_enhancement.core.terminal")
local process = require("terminal_enhancement.core.process")

local M = {}

---Open the interactive Live-Filter Terminal Switcher
---@param opts? { use_snacks?: boolean }
function M.open(opts)
  -- 1. If snacks.nvim is requested and available, use Snacks.picker
  if (opts and opts.use_snacks) or (opts == nil and _G.Snacks and Snacks.picker) then
    local ok = pcall(M.open_snacks)
    if ok then
      return
    end
  end

  -- 2. Native zero-dependency dual-float Live-Filter Modal
  M.open_native()
end

---Open native interactive floating search and filter terminal switcher
function M.open_native()
  local all_terminals = terminal.get_active_terminals()
  if #all_terminals == 0 then
    vim.notify("[TermEnhance] 🚀 No active terminals found. Opening a new terminal...", vim.log.levels.INFO)
    terminal.toggle("default")
    return
  end

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local width = math.min(math.max(math.floor(total_w * 0.75), 75), total_w - 4)
  local max_results = 10
  local results_h = math.min(math.max(#all_terminals, 3), max_results) + 2
  local total_height = results_h + 4 -- input (1) + border/margin + results

  local row = math.floor((total_h - total_height) / 2)
  local col = math.floor((total_w - width) / 2)

  -- Create Prompt Buffer & Window (Top)
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = prompt_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })

  local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🔍 Switch Terminal (Type to Filter) ",
    title_pos = "center",
  })

  -- Create Results Buffer & Window (Bottom)
  local results_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = results_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = results_buf })
  vim.api.nvim_set_option_value("filetype", "terminal_switcher", { buf = results_buf })

  local results_win = vim.api.nvim_open_win(results_buf, false, {
    relative = "editor",
    width = width,
    height = results_h,
    row = row + 3,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 💻 Active Terminals ",
    title_pos = "left",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = results_win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual",
    { win = results_win }
  )

  local ns_id = vim.api.nvim_create_namespace("terminal_picker_filter")
  local filtered = {}
  local selected_idx = 1

  local function close_all()
    if vim.api.nvim_win_is_valid(prompt_win) then
      pcall(vim.api.nvim_win_close, prompt_win, true)
    end
    if vim.api.nvim_win_is_valid(results_win) then
      pcall(vim.api.nvim_win_close, results_win, true)
    end
  end

  local function render_results()
    if not vim.api.nvim_buf_is_valid(results_buf) then
      return
    end

    local lines = {}
    if #filtered == 0 then
      table.insert(lines, "  ❌ No terminals match search query")
    else
      for idx, item in ipairs(filtered) do
        local state_icon = item.is_open and "🟢" or "⚪"
        local shell_badge = string.format("[%s]", item.shell_type or "bash")
        local pid_str = item.pid and string.format("(PID %d)", item.pid) or ""

        local proc_str = ""
        if item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
          proc_str = string.format(" ➔ %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid)
        end

        local port_str = ""
        if item.ports and #item.ports > 0 then
          local p_list = {}
          for _, p in ipairs(item.ports) do
            table.insert(p_list, ":" .. p.port)
          end
          port_str = string.format(" 🎧 %s", table.concat(p_list, ","))
        end

        local def_badge = item.is_default and " ⭐ TARGET" or ""
        local pointer = (idx == selected_idx) and "➤" or " "

        local line = string.format(" %s %s %s %s %s%s%s (Buf #%d)%s",
          pointer, state_icon, shell_badge, item.title, pid_str, proc_str, port_str, item.buf, def_badge)
        table.insert(lines, line)
      end
    end

    table.insert(lines, string.rep("─", width - 2))
    table.insert(lines, "  <CR>: Switch | <C-s>: Set Target | <C-k>: Kill | <C-p>: Kill Port | <Esc>: Exit")

    vim.api.nvim_set_option_value("modifiable", true, { buf = results_buf })
    vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = results_buf })

    -- Apply highlights
    vim.api.nvim_buf_clear_namespace(results_buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(results_buf, ns_id, "FloatBorder", #lines - 2, 0, -1)
    vim.api.nvim_buf_add_highlight(results_buf, ns_id, "Comment", #lines - 1, 0, -1)

    for idx, item in ipairs(filtered) do
      if idx == selected_idx then
        vim.api.nvim_buf_add_highlight(results_buf, ns_id, "Title", idx - 1, 0, 3)
      end
      if item.is_default then
        vim.api.nvim_buf_add_highlight(results_buf, ns_id, "DiagnosticWarn", idx - 1, 0, -1)
      end
    end

    if vim.api.nvim_win_is_valid(results_win) and #filtered > 0 then
      pcall(vim.api.nvim_win_set_cursor, results_win, { math.min(selected_idx, #filtered), 0 })
    end
  end

  local function filter_terminals(query)
    query = (query or ""):lower():gsub("%s+", "")
    filtered = {}

    for _, item in ipairs(all_terminals) do
      if query == "" then
        table.insert(filtered, item)
      else
        local haystack = string.format("%s %s %s %s %s",
          item.id or "",
          item.title or "",
          item.shell_type or "",
          item.pid and tostring(item.pid) or "",
          item.fg_proc and item.fg_proc.comm or ""
        ):lower()

        if item.ports then
          for _, p in ipairs(item.ports) do
            haystack = haystack .. " " .. tostring(p.port)
          end
        end

        if haystack:find(query, 1, true) then
          table.insert(filtered, item)
        end
      end
    end

    if selected_idx > #filtered then
      selected_idx = math.max(1, #filtered)
    end

    render_results()
  end

  local function move_selection(delta)
    if #filtered == 0 then
      return
    end
    selected_idx = selected_idx + delta
    if selected_idx < 1 then
      selected_idx = #filtered
    elseif selected_idx > #filtered then
      selected_idx = 1
    end
    render_results()
  end

  local function switch_to_selected()
    local target = filtered[selected_idx]
    close_all()
    if target then
      terminal.focus(target.id)
    end
  end

  local function set_target_selected()
    local target = filtered[selected_idx]
    if target then
      terminal.set_default_target(target.id)
      all_terminals = terminal.get_active_terminals()
      filter_terminals(vim.fn.prompt_getprompt(prompt_buf))
    end
  end

  local function kill_selected()
    local target = filtered[selected_idx]
    if target then
      terminal.kill(target.id)
      vim.notify(string.format("[TermEnhance] 🧹 Terminated terminal '%s'", target.id), vim.log.levels.INFO)
      all_terminals = terminal.get_active_terminals()
      if #all_terminals == 0 then
        close_all()
        return
      end
      filter_terminals(vim.fn.prompt_getprompt(prompt_buf))
    end
  end

  local function kill_port_selected()
    local target = filtered[selected_idx]
    if target then
      local prefill = (target.ports and #target.ports > 0) and tostring(target.ports[1].port) or ""
      close_all()
      vim.ui.input({ prompt = "Kill port for " .. target.id .. ": ", default = prefill }, function(input)
        if input and input ~= "" then
          local p = tonumber(input)
          if p then
            local ok, msg = terminal.kill_port(p, 15, target.id)
            if ok then
              vim.notify("[TermEnhance] 🛑 " .. msg, vim.log.levels.INFO)
            end
          end
        end
      end)
    end
  end

  -- Setup prompt callback & live filtering
  vim.fn.prompt_setprompt(prompt_buf, "  🔎 ")
  vim.fn.prompt_setcallback(prompt_buf, function(text)
    switch_to_selected()
  end)

  vim.fn.prompt_setinterrupt(prompt_buf, function()
    close_all()
  end)

  -- Autocommand for real-time text input updates
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = prompt_buf,
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local query = line:gsub("^%s*🔎%s*", "")
      filter_terminals(query)
    end,
  })

  -- Keybindings inside prompt window
  local function map_both(key, fn)
    vim.keymap.set("i", key, fn, { buffer = prompt_buf, silent = true, noremap = true })
    vim.keymap.set("n", key, fn, { buffer = prompt_buf, silent = true, noremap = true })
  end

  map_both("<Down>", function() move_selection(1) end)
  map_both("<C-j>", function() move_selection(1) end)
  map_both("<C-n>", function() move_selection(1) end)
  map_both("<Tab>", function() move_selection(1) end)

  map_both("<Up>", function() move_selection(-1) end)
  map_both("<C-k>", function() move_selection(-1) end)
  map_both("<C-p>", function() move_selection(-1) end)
  map_both("<S-Tab>", function() move_selection(-1) end)

  map_both("<CR>", switch_to_selected)
  map_both("<C-s>", set_target_selected)
  map_both("<C-d>", kill_selected)
  map_both("<C-x>", kill_selected)
  map_both("<C-q>", close_all)
  map_both("<Esc>", close_all)

  -- Alt + 1..9 to jump directly to terminal index
  for i = 1, 9 do
    map_both(string.format("<M-%d>", i), function()
      if #filtered >= i then
        selected_idx = i
        switch_to_selected()
      end
    end)
  end

  -- Initial render and start insert
  filter_terminals("")
  vim.cmd("startinsert!")
end

---Open Snacks.picker terminal switcher (if folke/snacks.nvim is installed)
function M.open_snacks()
  if not _G.Snacks or not Snacks.picker then
    error("Snacks.picker not available")
  end

  local all_terminals = terminal.get_active_terminals()
  if #all_terminals == 0 then
    vim.notify("[TermEnhance] No active terminals found.", vim.log.levels.INFO)
    return
  end

  local items = {}
  for idx, item in ipairs(all_terminals) do
    local shell_badge = string.format("[%s]", item.shell_type or "bash")
    local pid_str = item.pid and string.format("(PID %d)", item.pid) or ""
    local proc_str = ""
    if item.fg_proc and item.fg_proc.comm and item.fg_proc.pid ~= item.pid then
      proc_str = string.format(" ➔ %s (PID %d)", item.fg_proc.comm, item.fg_proc.pid)
    end
    local port_str = ""
    if item.ports and #item.ports > 0 then
      local p_list = {}
      for _, p in ipairs(item.ports) do
        table.insert(p_list, ":" .. p.port)
      end
      port_str = string.format(" 🎧 %s", table.concat(p_list, ","))
    end
    local def_badge = item.is_default and " ⭐ TARGET" or ""
    local state_icon = item.is_open and "🟢" or "⚪"

    local label = string.format("%s %s %s %s%s%s (Buf #%d)%s",
      state_icon, shell_badge, item.title, pid_str, proc_str, port_str, item.buf, def_badge)

    table.insert(items, {
      idx = idx,
      score = idx,
      text = string.format("%s %s %s %s", item.id, item.title, shell_badge, proc_str),
      label = label,
      terminal = item,
    })
  end

  Snacks.picker({
    title = " 💻 Switch Terminal ",
    items = items,
    format = function(item)
      return { { item.label } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.terminal then
        terminal.focus(item.terminal.id)
      end
    end,
  })
end

return M
