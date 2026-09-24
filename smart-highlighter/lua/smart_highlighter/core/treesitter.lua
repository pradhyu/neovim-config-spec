local M = {}

---Check if Treesitter parser is available for a buffer
---@param buf? integer
---@return boolean
function M.is_available(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, target_buf)
  return ok and parser ~= nil
end

---Get current cursor enclosing function, method, or block node range
---@param win? integer
---@param buf? integer
---@return { start_row: integer, start_col: integer, end_row: integer, end_col: integer, node_type: string }?
function M.get_enclosing_scope_range(win, buf)
  local target_win = win or vim.api.nvim_get_current_win()
  local target_buf = buf or vim.api.nvim_win_get_buf(target_win)

  if not M.is_available(target_buf) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(target_win)
  local row = cursor[1] - 1
  local col = cursor[2]

  local node = nil
  if vim.treesitter.get_node then
    node = vim.treesitter.get_node({ bufnr = target_buf, pos = { row, col } })
  end

  if not node then
    return nil
  end

  -- Target node types that represent scopes across various languages
  local scope_types = {
    function_declaration = true,
    function_definition = true,
    method_declaration = true,
    method_definition = true,
    arrow_function = true,
    function_item = true,
    class_declaration = true,
    class_definition = true,
    impl_item = true,
    block = true,
    statement_block = true,
    compound_statement = true,
  }

  local curr = node
  local best_scope = nil

  while curr do
    local n_type = curr:type()
    if scope_types[n_type] then
      best_scope = curr
      -- If it's a function or method, break early to capture the closest function boundary
      if n_type:match("function") or n_type:match("method") then
        break
      end
    end
    curr = curr:parent()
  end

  if not best_scope then
    best_scope = node:root()
  end

  if best_scope then
    local s_row, s_col, e_row, e_col = best_scope:range()
    return {
      start_row = s_row,
      start_col = s_col,
      end_row = e_row,
      end_col = e_col,
      node_type = best_scope:type(),
    }
  end

  return nil
end

return M
