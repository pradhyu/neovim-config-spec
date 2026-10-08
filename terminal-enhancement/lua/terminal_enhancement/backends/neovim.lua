local terminal = require("terminal_enhancement.core.terminal")

local M = {}

function M.is_available()
  return true
end

---Send text to native terminal-enhancement instance
---@param text string
---@param opts? table
---@param lang? string
---@param on_done? fun(target_id: string, term_buf: integer|nil, start_lines: integer|nil)
---@param entry_id? integer
---@return boolean success
function M.send(text, opts, lang, on_done, entry_id)
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

  return true
end

return M
