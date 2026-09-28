local terminal = require("terminal_enhancement.core.terminal")
local autocomplete = require("terminal_enhancement.core.autocomplete")
local history = require("terminal_enhancement.core.history")
local config = require("terminal_enhancement.config")

local M = {}

---Create or get custom dimmed ghost text highlight group
local function setup_highlights()
  vim.api.nvim_set_hl(0, "TermEnhanceGhostText", {
    fg = "#6c7086",
    italic = true,
    default = true,
  })
end

---Open interactive terminal command prompt with live Fish-like autocomplete & dimmed ghost text
---@param opts? { target?: string, initial_text?: string }
function M.open(opts)
  opts = opts or {}
  setup_highlights()

  local target_id = opts.target or terminal.get_default_target() or "default"
  local inst = terminal.get_or_create(target_id)
  local initial_cmd = opts.initial_text or ""

  -- Scratch buffer for single-line interactive input
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal_prompt", { buf = buf })

  local total_w = vim.o.columns
  local total_h = vim.o.lines

  local width = math.min(math.max(math.floor(total_w * 0.65), 65), total_w - 6)
  local height = 1
  local row = math.floor((total_h - height) / 2) - 4
  local col = math.floor((total_w - width) / 2)

  local title_str = string.format(" ⚡ Run in [%s] (Fish Ghost Text: <Right>/<Tab> to accept) ", target_id)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title_str,
    title_pos = "center",
    footer = " <CR>: Run | <Right>/<Tab>: Accept Ghost | <Up>/<Down>: History | <C-t>: Target | <Esc>: Cancel ",
    footer_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title,FloatFooter:Comment",
    { win = win }
  )

  local ns_id = vim.api.nvim_create_namespace("terminal_prompt_ghost")

  -- State
  local current_ghost_suffix = nil
  local current_matches = {}
  local match_index = 0
  local original_typed_text = initial_cmd

  if initial_cmd ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_cmd })
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  end

  local function clear_ghost()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end
    current_ghost_suffix = nil
  end

  local function update_ghost_text()
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
      return
    end

    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local cursor = vim.api.nvim_win_get_cursor(win)
    local cursor_col = cursor[2]

    clear_ghost()

    if line == "" then
      current_matches = {}
      match_index = 0
      return
    end

    local res = autocomplete.get_suggestion(line)
    current_matches = res.matches
    current_ghost_suffix = res.ghost_suffix

    -- Only show ghost text if cursor is at the end of the input line
    if current_ghost_suffix and current_ghost_suffix ~= "" and cursor_col >= #line then
      vim.api.nvim_buf_set_extmark(buf, ns_id, 0, #line, {
        virt_text = { { current_ghost_suffix, "TermEnhanceGhostText" } },
        virt_text_pos = "inline",
        hl_mode = "combine",
      })
    end
  end

  -- Autocommands for interactive typing
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "CursorMovedI" }, {
    buffer = buf,
    callback = update_ghost_text,
  })

  local function accept_full_ghost()
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    if current_ghost_suffix and current_ghost_suffix ~= "" then
      local completed = line .. current_ghost_suffix
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { completed })
      pcall(vim.api.nvim_win_set_cursor, win, { 1, #completed })
      clear_ghost()
      update_ghost_text()
      return true
    end
    return false
  end

  local function accept_word_ghost()
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    if current_ghost_suffix and current_ghost_suffix ~= "" then
      local chunk = autocomplete.get_next_word_chunk(line, current_ghost_suffix)
      if chunk ~= "" then
        local completed = line .. chunk
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { completed })
        pcall(vim.api.nvim_win_set_cursor, win, { 1, #completed })
        clear_ghost()
        update_ghost_text()
        return true
      end
    end
    return false
  end

  local function cycle_history(direction)
    if #current_matches == 0 then
      return
    end

    if match_index == 0 then
      original_typed_text = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    end

    match_index = match_index + direction
    if match_index > #current_matches then
      match_index = 0
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { original_typed_text })
      pcall(vim.api.nvim_win_set_cursor, win, { 1, #original_typed_text })
      clear_ghost()
      return
    elseif match_index < 0 then
      match_index = #current_matches
    end

    local candidate = current_matches[match_index]
    if candidate then
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { candidate })
      pcall(vim.api.nvim_win_set_cursor, win, { 1, #candidate })
      clear_ghost()
    end
  end

  local function execute_prompt()
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    line = vim.trim(line)

    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end

    if line == "" then
      return
    end

    -- Send command to terminal
    terminal.send(target_id, line)

    -- Register in history
    history.add_entry({
      command = line,
      file = "[terminal_prompt]",
      line_start = 1,
      line_end = 1,
      lang = "sh",
      status = "running",
    })

    autocomplete.refresh_cache()
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  -- Keybindings for prompt buffer
  local k_opts = { buffer = buf, silent = true, nowait = true }

  -- Ghost text completion keybindings
  vim.keymap.set("i", "<Right>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    if cursor[2] >= #line and current_ghost_suffix then
      accept_full_ghost()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, false, true), "n", false)
    end
  end, k_opts)

  vim.keymap.set("i", "<Tab>", function()
    if not accept_full_ghost() then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
    end
  end, k_opts)

  vim.keymap.set("i", "<C-e>", accept_full_ghost, k_opts)
  vim.keymap.set("i", "<C-f>", accept_full_ghost, k_opts)
  vim.keymap.set("i", "<C-y>", accept_full_ghost, k_opts)

  -- Word by word completion
  vim.keymap.set("i", "<M-Right>", accept_word_ghost, k_opts)
  vim.keymap.set("i", "<A-Right>", accept_word_ghost, k_opts)
  vim.keymap.set("i", "<M-f>", accept_word_ghost, k_opts)

  -- History cycling
  vim.keymap.set("i", "<Up>", function() cycle_history(1) end, k_opts)
  vim.keymap.set("i", "<Down>", function() cycle_history(-1) end, k_opts)
  vim.keymap.set("i", "<C-p>", function() cycle_history(1) end, k_opts)
  vim.keymap.set("i", "<C-n>", function() cycle_history(-1) end, k_opts)

  -- Execution & Close
  vim.keymap.set({ "i", "n" }, "<CR>", execute_prompt, k_opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", close, k_opts)
  vim.keymap.set({ "i", "n" }, "<C-c>", close, k_opts)

  -- Target Switcher
  vim.keymap.set("i", "<C-t>", function()
    local cur_text = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    close()
    terminal.select_target_terminal(function(new_id)
      M.open({ target = new_id, initial_text = cur_text })
    end)
  end, k_opts)

  -- Focus and start insert mode
  pcall(vim.api.nvim_win_set_cursor, win, { 1, #initial_cmd })
  vim.cmd("startinsert!")
  update_ghost_text()
end

return M
