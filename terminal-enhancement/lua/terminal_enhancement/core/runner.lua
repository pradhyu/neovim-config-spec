local terminal = require("terminal_enhancement.core.terminal")

local M = {}

---Expand a line range (start_line, end_line) to include all connected continuation lines (\ or `)
---@param bufnr integer
---@param start_line integer 1-indexed
---@param end_line integer 1-indexed
---@return integer expanded_start, integer expanded_end
local function expand_continuation_range(bufnr, start_line, end_line)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  local function has_continuation(line_str)
    return line_str:match("\\%s*$") ~= nil or line_str:match("`%s*$") ~= nil
  end

  -- 1. Scan backwards from start_line as long as previous line had a continuation character
  local s = start_line
  while s > 1 do
    local prev = vim.api.nvim_buf_get_lines(bufnr, s - 2, s - 1, false)[1] or ""
    if has_continuation(prev) then
      s = s - 1
    else
      break
    end
  end

  -- 2. Scan forwards from end_line as long as current line has a continuation character
  local e = end_line
  while e <= total_lines do
    local cur = vim.api.nvim_buf_get_lines(bufnr, e - 1, e, false)[1] or ""
    if has_continuation(cur) and e < total_lines then
      e = e + 1
    else
      break
    end
  end

  return s, e
end

---Internal helper to send text to resolved or chosen target terminal
---@param text string
---@param line_count integer
---@param mode? "raw"|"join_continuation"|"join_and"
local function dispatch_to_terminal(text, line_count, mode)
  local active = terminal.get_active_terminals()
  local shell_helper = require("terminal_enhancement.core.shell_helper")

  local function do_send(target_id)
    local inst = terminal.instances[target_id]
    local shell_type = shell_helper.detect_shell_type(inst)
    local formatted = shell_helper.format_multiline_command(text, mode, shell_type)

    terminal.send(target_id, formatted)

    local preview = formatted:sub(1, 40):gsub("\n", " ")
    if #formatted > 40 then
      preview = preview .. "..."
    end

    local mode_desc = ""
    if mode == "join_continuation" then
      local cont = shell_helper.get_continuation_char(shell_type)
      mode_desc = string.format(" [Joined with %s]", cont)
    elseif mode == "join_and" then
      mode_desc = " [Joined with &&]"
    end

    vim.notify(
      string.format("[TermEnhance -> %s%s] Sent %d line(s): %s", target_id, mode_desc, line_count, preview),
      vim.log.levels.INFO
    )
  end

  if #active == 0 then
    -- Case 1: No terminals exist -> create default and send
    terminal.get_or_create("default")
    terminal.set_default_target("default")
    do_send("default")
  elseif #active == 1 then
    -- Case 2: Exactly 1 terminal exists -> use it directly
    local target = active[1].id
    terminal.set_default_target(target)
    do_send(target)
  else
    -- Case 3: Multiple terminals exist -> use default target if set and valid, otherwise prompt
    if terminal.default_target and terminal.instances[terminal.default_target] then
      do_send(terminal.default_target)
    else
      -- Prompt user with choice and remember selection as default
      terminal.select_target_terminal(function(chosen_id)
        do_send(chosen_id)
      end)
    end
  end
end

---Extract text from visual selection, automatically expanding multi-line continuation blocks
---@return string? text, integer line_count
local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode:match("[vV\22]") then
    -- Exit visual mode to ensure '< and '> are updated
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  end

  local s_pos = vim.fn.getpos("'<")
  local e_pos = vim.fn.getpos("'>")
  local s_line = s_pos[2]
  local e_line = e_pos[2]

  if s_line > e_line then
    s_line, e_line = e_line, s_line
  end

  if s_line > 0 and e_line > 0 then
    -- Expand selection if any line is part of a multi-line command (\ or `)
    s_line, e_line = expand_continuation_range(0, s_line, e_line)
    local lines = vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
    if #lines > 0 then
      return table.concat(lines, "\n"), #lines
    end
  end

  return nil, 0
end

---Send visual selection or current line to the active/default terminal
---@param line1? integer
---@param line2? integer
---@param mode? "raw"|"join_continuation"|"join_and"
function M.send_selection(line1, line2, mode)
  local text = nil
  local line_count = 1

  if line1 and line2 and line1 > 0 and line2 > 0 and (line1 ~= line2 or vim.fn.mode():match("[vV\22]")) then
    local s, e = expand_continuation_range(0, line1, line2)
    local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
    if #lines > 0 then
      text = table.concat(lines, "\n")
      line_count = #lines
    end
  end

  if not text then
    text, line_count = get_visual_selection()
  end

  -- If still nil (Normal mode), check if cursor is on a multi-line command with \ or `
  if not text or text == "" then
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local s, e = expand_continuation_range(0, cur, cur)
    local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
    if #lines > 0 then
      text = table.concat(lines, "\n")
      line_count = #lines
    end
  end

  if not text or text:match("^%s*$") then
    vim.notify("[TermEnhance] Current line or selection is empty.", vim.log.levels.WARN)
    return
  end

  dispatch_to_terminal(text, line_count, mode or "raw")
end

---Send current line or multi-line command at cursor to terminal
function M.send_current_line()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local s, e = expand_continuation_range(0, cur, cur)
  local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
  local text = table.concat(lines, "\n")
  local line_count = #lines

  if not text or text:match("^%s*$") then
    vim.notify("[TermEnhance] Current line is empty.", vim.log.levels.WARN)
    return
  end

  dispatch_to_terminal(text, line_count, "raw")
end

---Send visual selection joined into a single multi-line command with \ (Bash) or ` (PowerShell)
---@param line1? integer
---@param line2? integer
---@param join_mode? "join_continuation"|"join_and"
function M.send_joined(line1, line2, join_mode)
  M.send_selection(line1, line2, join_mode or "join_continuation")
end

---Prompt user to switch or change default target terminal
function M.select_target()
  terminal.select_target_terminal(function(chosen_id)
    vim.notify(string.format("[TermEnhance] Default target terminal switched to '%s'", chosen_id), vim.log.levels.INFO)
  end)
end

---Run arbitrary shell command in a dedicated or default terminal
---@param cmd string
---@param direction? string
function M.run_command(cmd, direction)
  local safe_id = "cmd_" .. cmd:gsub("[^%w]", "_"):sub(1, 20)
  terminal.toggle(safe_id, cmd, direction or "float", string.format(" Run: %s ", cmd))
end

return M
