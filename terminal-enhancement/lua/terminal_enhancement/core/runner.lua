local terminal = require("terminal_enhancement.core.terminal")
local config = require("terminal_enhancement.config")
local extractor = require("terminal_enhancement.core.extractor")
local sanitizer = require("terminal_enhancement.core.sanitizer")
local highlighter = require("terminal_enhancement.core.highlighter")
local history = require("terminal_enhancement.core.history")
local shell_helper = require("terminal_enhancement.core.shell_helper")
local utils = require("terminal_enhancement.core.utils")

local M = {}

local backends = require("terminal_enhancement.backends")

---Internal helper to dispatch text to resolved or chosen target terminal
---@param text string
---@param opts? table
---@param lang? string
---@param on_done? fun(target_id: string, term_buf: integer, start_lines: integer)
---@param entry_id? integer
local function dispatch_to_terminal(text, opts, lang, on_done, entry_id)
  return backends.send(text, opts, lang, on_done, entry_id)
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

  local done_called = false
  local function done_wrapper(target_id, term_buf, start_lines)
    if not done_called then
      done_called = true
      if entry and term_buf and vim.api.nvim_buf_is_valid(term_buf) then
        history.capture_terminal_output(term_buf, start_lines, entry.id, opts)
      end
      if on_done then on_done(true) end
    end
  end

  local ok = dispatch_to_terminal(payload, opts, result.lang, done_wrapper, entry and entry.id or nil)
  if ok and not done_called then
    done_wrapper("dispatched", nil, 0)
  end

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

  dispatch_to_terminal(payload, config.options, filetype, function(_, term_buf, start_lines)
    if entry and term_buf and vim.api.nvim_buf_is_valid(term_buf) then
      history.capture_terminal_output(term_buf, start_lines, entry.id, config.options)
    end
  end, entry and entry.id or nil)
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

---Operatorfunc callback for motion execution (`g@`)
---@param motion_type string
function M.opfunc(motion_type)
  local bufnr = vim.api.nvim_get_current_buf()
  local s_pos = vim.fn.getpos("'[")
  local e_pos = vim.fn.getpos("']")

  local s_line = s_pos[2]
  local s_col = s_pos[3]
  local e_line = e_pos[2]
  local e_col = e_pos[3]

  if s_line == 0 or e_line == 0 then
    return
  end

  local lines = utils.get_buf_lines(bufnr, s_line, e_line)
  local lang = utils.get_filetype(bufnr)
  local is_char = (motion_type == "char")

  if is_char then
    if #lines == 1 then
      lines[1] = lines[1]:sub(s_col, e_col)
    else
      lines[1] = lines[1]:sub(s_col)
      lines[#lines] = lines[#lines]:sub(1, e_col)
    end
  end

  local opts = config.options
  local sanitized = sanitizer.sanitize_lines(lines, lang, opts)
  local res = {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = lang,
    is_inline = is_char and (#lines == 1),
    range = {
      bufnr = bufnr,
      start_row = s_line - 1,
      start_col = is_char and (s_col - 1) or 0,
      end_row = e_line - 1,
      end_col = is_char and e_col or -1,
      start_line = s_line,
      end_line = e_line,
    },
  }

  execute_result(res, opts)
end

---Interactive prompt to select or switch the default target terminal
function M.select_target()
  terminal.select_target_terminal()
end

---Trigger operator motion
function M.send_motion()
  vim.go.operatorfunc = "v:lua.require'terminal_enhancement'.opfunc"
  vim.api.nvim_feedkeys("g@", "n", false)
end

return M
