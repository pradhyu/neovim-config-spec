local config = require("terminal_enhancement.config")

local M = {}

---Detect shell type for a given terminal instance or global shell
---@param inst? table
---@return "powershell"|"bash"
function M.detect_shell_type(inst)
  local custom_pref = config.options.shell_continuation
  if custom_pref == "bash" or custom_pref == "posix" then
    return "bash"
  elseif custom_pref == "powershell" or custom_pref == "pwsh" then
    return "powershell"
  end

  local shell_cmd = (inst and inst.cmd) or (inst and inst.buf and vim.api.nvim_buf_get_name(inst.buf)) or vim.o.shell
  shell_cmd = shell_cmd:lower()

  if shell_cmd:match("pwsh") or shell_cmd:match("powershell") or shell_cmd:match("powershell.exe") then
    return "powershell"
  end

  return "bash"
end

---Get the line continuation character for a shell type
---@param shell_type "powershell"|"bash"
---@return string
function M.get_continuation_char(shell_type)
  if shell_type == "powershell" then
    return "`"
  end
  return "\\"
end

---Dedent lines by removing common leading whitespace
---@param lines string[]
---@return string[]
function M.dedent_lines(lines)
  if #lines <= 1 then
    return lines
  end

  local min_indent = nil
  for _, line in ipairs(lines) do
    if not line:match("^%s*$") then
      local indent = line:match("^(%s*)")
      local len = indent and #indent or 0
      if min_indent == nil or len < min_indent then
        min_indent = len
      end
    end
  end

  if not min_indent or min_indent == 0 then
    return lines
  end

  local result = {}
  for _, line in ipairs(lines) do
    if line:match("^%s*$") then
      table.insert(result, "")
    else
      table.insert(result, line:sub(min_indent + 1))
    end
  end
  return result
end

---Format and join multi-line text with shell continuation characters or compound operators
---@param text string
---@param mode? "raw"|"join_continuation"|"join_and"
---@param shell_type? "powershell"|"bash"
---@return string
function M.format_multiline_command(text, mode, shell_type)
  local target_shell = shell_type or M.detect_shell_type()
  local cont_char = M.get_continuation_char(target_shell)

  local raw_lines = vim.split(text, "\n", { plain = true })
  local lines = {}
  for _, l in ipairs(raw_lines) do
    if not l:match("^%s*$") then
      table.insert(lines, l)
    end
  end

  if #lines == 0 then
    return text
  end

  if config.options.auto_dedent then
    lines = M.dedent_lines(lines)
  end

  if mode == "join_continuation" then
    local joined = {}
    for i, line in ipairs(lines) do
      -- Strip any existing trailing continuation character
      local clean_line = line:gsub("%s*[" .. vim.pesc(cont_char) .. "%s\\]+$", "")
      if i < #lines then
        table.insert(joined, clean_line .. " " .. cont_char)
      else
        table.insert(joined, clean_line)
      end
    end
    return table.concat(joined, "\n")
  elseif mode == "join_and" then
    local joined = {}
    for _, line in ipairs(lines) do
      local clean_line = line:gsub("%s*[%`\\]+$", ""):gsub("%s*&&%s*$", ""):gsub("%s*;%s*$", "")
      if clean_line ~= "" then
        table.insert(joined, clean_line)
      end
    end
    return table.concat(joined, " && ")
  end

  -- Default "raw" mode: Preserve lines as dedented
  return table.concat(lines, "\n")
end

---Wrap text in terminal Bracketed Paste escape codes for atomic multi-line execution
---@param text string
---@return string
function M.wrap_bracketed_paste(text)
  if not config.options.bracketed_paste then
    return text
  end

  -- Bracketed paste: ESC [ 200 ~ <payload> ESC [ 201 ~
  -- This instructs the shell (bash/zsh/readline/pwsh) to treat the multi-line block as a single paste
  return string.format("\x1b[200~%s\x1b[201~", text)
end

return M
