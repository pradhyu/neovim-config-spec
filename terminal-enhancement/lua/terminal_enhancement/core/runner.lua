local terminal = require("terminal_enhancement.core.terminal")
local config = require("terminal_enhancement.config")
local extractor = require("terminal_enhancement.core.extractor")
local sanitizer = require("terminal_enhancement.core.sanitizer")
local highlighter = require("terminal_enhancement.core.highlighter")
local history = require("terminal_enhancement.core.history")
local shell_helper = require("terminal_enhancement.core.shell_helper")
local utils = require("terminal_enhancement.core.utils")

local M = {}

---Internal helper to dispatch text to resolved or chosen target terminal
---@param text string
---@param lang? string
---@param on_done? fun(target_id: string, term_buf: integer, start_lines: integer)
local function dispatch_to_terminal(text, lang, on_done)
  local active = terminal.get_active_terminals()

  local function do_send(target_id)
    local inst = terminal.instances[target_id]
    if not inst then
      inst = terminal.get_or_create(target_id)
    end

    local term_buf = inst.buf
    local start_line_count = (term_buf and vim.api.nvim_buf_is_valid(term_buf)) and vim.api.nvim_buf_line_count(term_buf) or 0

    terminal.send(target_id, text)

    local preview = text:gsub("\27%[[0-9;?]*[a-zA-Z]", ""):sub(1, 40):gsub("\n", " ")
    if #text > 40 then
      preview = preview .. "..."
    end

    vim.notify(
      string.format("[TermEnhance -> %s] Dispatched: %s", target_id, preview),
      vim.log.levels.INFO
    )

    if on_done then
      on_done(target_id, term_buf, start_line_count)
    end
  end

  if #active == 0 then
    terminal.get_or_create("default")
    terminal.set_default_target("default")
    do_send("default")
  elseif #active == 1 then
    local target = active[1].id
    terminal.set_default_target(target)
    do_send(target)
  else
    if terminal.default_target and terminal.instances[terminal.default_target] then
      do_send(terminal.default_target)
    else
      terminal.select_target_terminal(function(chosen_id)
        do_send(chosen_id)
      end)
    end
  end
end

---Execute an extraction result (highlight, format, send, record history)
---@param result TermExtractionResult|nil
---@param opts? table
---@param on_done? fun(success: boolean)
---@return boolean success
local function execute_result(result, opts, on_done)
  opts = opts or config.options
  if not result or not result.text or result.text == "" then
    if on_done then on_done(false) end
    return false
  end

  -- Flash visual highlight feedback
  local range = result.range
  if range and range.bufnr and vim.api.nvim_buf_is_valid(range.bufnr) then
    highlighter.flash_range(range.bufnr, range.start_row, range.start_col, range.end_row, range.end_col, opts)
  end

  local payload = sanitizer.format_payload(result.sanitized_lines, opts, result.lang)

  -- Record execution in history
  local cur_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(cur_buf)
  local entry = history.add_entry({
    src_bufnr = cur_buf,
    file = file_path ~= "" and file_path or "[buffer]",
    line_start = range and range.start_line or 1,
    line_end = range and range.end_line or 1,
    lang = result.lang or "sh",
    command = result.text,
  })

  dispatch_to_terminal(payload, result.lang, function(target_id, term_buf, start_lines)
    if entry and term_buf and vim.api.nvim_buf_is_valid(term_buf) then
      history.capture_terminal_output(term_buf, start_lines, entry.id, opts)
    end
    if on_done then on_done(true) end
  end)

  return true
end

---Send line or inline code at cursor (supports prompt stripping and continuation expansion)
---@param opts? table
function M.send_line(opts)
  local result = extractor.extract_line(nil, nil, opts)
  if not result then
    vim.notify("[TermEnhance] No executable content on current line.", vim.log.levels.WARN)
    return
  end
  execute_result(result, opts)
end

---Send current line (alias for send_line)
function M.send_current_line(opts)
  M.send_line(opts)
end

---Send current enclosing block (Markdown code fence, Treesitter block, or paragraph)
---@param opts? table
function M.send_block(opts)
  local result = extractor.extract_block(nil, nil, opts)
  if not result then
    vim.notify("[TermEnhance] No code block found at cursor.", vim.log.levels.WARN)
    return
  end
  execute_result(result, opts)
end

---Send current line/command and advance cursor to next executable statement
---@param opts? table
function M.send_step(opts)
  local cur_buf = vim.api.nvim_get_current_buf()
  local result = extractor.extract_line(cur_buf, nil, opts)
  if not result then
    vim.notify("[TermEnhance] No executable content on current line.", vim.log.levels.WARN)
    return
  end

  local end_line = result.range.end_line
  local lang = result.lang

  execute_result(result, opts, function(success)
    if success then
      local next_line = extractor.find_next_executable_line(cur_buf, end_line, lang, opts)
      if next_line then
        pcall(vim.api.nvim_win_set_cursor, 0, { next_line, 0 })
      end
    end
  end)
end

---Send entire buffer / file
---@param opts? table
function M.send_file(opts)
  local result = extractor.extract_file(nil, opts)
  if not result then
    vim.notify("[TermEnhance] Buffer is empty.", vim.log.levels.WARN)
    return
  end
  execute_result(result, opts)
end

---Send visual selection
---@param opts? table
function M.send_visual(opts)
  local result = extractor.extract_visual(nil, opts)
  if not result then
    vim.notify("[TermEnhance] Visual selection is empty.", vim.log.levels.WARN)
    return
  end
  execute_result(result, opts)
end

---Send visual selection or range (Legacy / command range compatible)
---@param line1? integer
---@param line2? integer
---@param mode? "raw"|"join_continuation"|"join_and"
function M.send_selection(line1, line2, mode)
  local bufnr = vim.api.nvim_get_current_buf()
  local s_line = line1 or vim.fn.line("'<")
  local e_line = line2 or vim.fn.line("'>")

  if not line1 and (s_line == 0 or e_line == 0 or s_line > e_line) then
    M.send_visual()
    return
  end

  local lines = utils.get_buf_lines(bufnr, s_line, e_line)
  if #lines == 0 then
    return
  end

  local filetype = utils.get_filetype(bufnr)
  local sanitized = sanitizer.sanitize_lines(lines, filetype)
  local text = table.concat(sanitized, "\n")

  if mode == "join_continuation" or mode == "join_and" then
    local inst = terminal.instances[terminal.default_target or "default"]
    local shell_type = shell_helper.detect_shell_type(inst)
    text = shell_helper.format_multiline_command(text, mode, shell_type)
  end

  highlighter.flash_lines(bufnr, s_line, e_line)
  local payload = sanitizer.format_payload(sanitized, nil, filetype)

  local entry = history.add_entry({
    src_bufnr = bufnr,
    file = vim.api.nvim_buf_get_name(bufnr),
    line_start = s_line,
    line_end = e_line,
    lang = filetype,
    command = text,
  })

  dispatch_to_terminal(payload, filetype, function(_, term_buf, start_lines)
    if entry and term_buf and vim.api.nvim_buf_is_valid(term_buf) then
      history.capture_terminal_output(term_buf, start_lines, entry.id)
    end
  end)
end

---Send lines joined with line continuation (\ or `)
---@param line1? integer
---@param line2? integer
---@param mode? "join_continuation"|"join_and"
function M.send_joined(line1, line2, mode)
  M.send_selection(line1, line2, mode or "join_continuation")
end

---Run arbitrary command string in a floating terminal
---@param cmd string
---@param direction? string
function M.run_command(cmd, direction)
  local temp_id = "run_" .. tostring(os.time())
  terminal.toggle(temp_id, cmd, direction or "float", string.format(" Run: %s ", cmd))
end

---Interactive prompt to select or switch the default target terminal
function M.select_target()
  terminal.select_target_terminal()
end

return M
