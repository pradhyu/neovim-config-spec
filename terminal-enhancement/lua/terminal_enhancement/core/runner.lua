local terminal = require("terminal_enhancement.core.terminal")

local M = {}

---Extract text from visual selection
---@return string?
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
    local lines = vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
    if #lines > 0 then
      return table.concat(lines, "\n")
    end
  end

  return nil
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

---Send visual selection or current line to the active/default terminal
---@param line1? integer
---@param line2? integer
---@param mode? "raw"|"join_continuation"|"join_and"
function M.send_selection(line1, line2, mode)
  local text = nil

  if line1 and line2 and line1 > 0 and line2 > 0 and (line1 ~= line2 or vim.fn.mode():match("[vV\22]")) then
    local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    if #lines > 0 then
      text = table.concat(lines, "\n")
    end
  end

  if not text then
    text = get_visual_selection()
  end

  -- If still nil, fall back to current line where the cursor is
  if not text or text == "" then
    text = vim.api.nvim_get_current_line()
  end

  if not text or text:match("^%s*$") then
    vim.notify("[TermEnhance] Current line or selection is empty.", vim.log.levels.WARN)
    return
  end

  local _, count = text:gsub("\n", "\n")
  local line_count = count + 1
  dispatch_to_terminal(text, line_count, mode or "raw")
end

---Send current line to terminal
function M.send_current_line()
  local line = vim.api.nvim_get_current_line()
  if not line or line:match("^%s*$") then
    vim.notify("[TermEnhance] Current line is empty.", vim.log.levels.WARN)
    return
  end

  dispatch_to_terminal(line, 1, "raw")
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
