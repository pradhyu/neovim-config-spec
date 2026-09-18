local M = {}

---Strip file:// prefix and extract path and line/col information
---@param text string
---@return string? path, integer? line, integer? col
local function parse_path_and_line(text)
  if not text or text == "" then
    return nil, nil, nil
  end

  local clean = text:gsub("^file://", ""):gsub("^['\"`%(%[]+", ""):gsub("['\"`%)%]]+$", "")

  -- Format: path#L15-L25 or path#L15
  local p1, l1 = clean:match("^(.-)#L(%d+)")
  if p1 and l1 then
    return p1, tonumber(l1), 1
  end

  -- Format: path:15:3 or path:15
  local p2, l2, c2 = clean:match("^(.-):(%d+):(%d+)")
  if p2 and l2 and c2 then
    return p2, tonumber(l2), tonumber(c2)
  end

  local p3, l3 = clean:match("^(.-):(%d+)")
  if p3 and l3 then
    return p3, tonumber(l3), 1
  end

  -- Format: path (15) or path(15)
  local p4, l4 = clean:match("^(.-)%((%d+)%)")
  if p4 and l4 then
    return p4, tonumber(l4), 1
  end

  return clean, nil, nil
end

---Resolve a potential relative or basename file path to an absolute path
---@param raw_path string
---@return string?
local function resolve_file(raw_path)
  if not raw_path or raw_path == "" then
    return nil
  end

  -- Expand home directory ~
  local expanded = vim.fn.expand(raw_path)
  if vim.fn.filereadable(expanded) == 1 then
    return expanded
  end

  -- Check current working directory
  local cwd = vim.fn.getcwd()
  local cwd_path = cwd .. "/" .. raw_path
  if vim.fn.filereadable(cwd_path) == 1 then
    return cwd_path
  end

  -- Check upward search
  local found = vim.fs.find(raw_path, { upward = true, path = cwd })
  if found and #found > 0 then
    return found[1]
  end

  -- Check basename search in cwd
  local basename = raw_path:match("[/\\]([^/\\]+)$") or raw_path
  local base_found = vim.fs.find(basename, { upward = true, path = cwd })
  if base_found and #base_found > 0 then
    return base_found[1]
  end

  -- Check ~/.config/nvim
  local nvim_conf = vim.fn.stdpath("config") .. "/" .. raw_path
  if vim.fn.filereadable(nvim_conf) == 1 then
    return nvim_conf
  end

  return nil
end

---Open a file or URL in the editor or browser
---@param target_str? string If nil, extracts from cursor
---@return boolean success
function M.open(target_str)
  local str = target_str

  if not str or str == "" then
    local line_str = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    -- Check for Markdown link [text](target)
    local md_target = line_str:match("%b[]%(([^)]+)%)")
    if md_target then
      str = md_target
    else
      -- Extract WORD under cursor
      local cword = vim.fn.expand("<cfile>")
      if cword and cword ~= "" then
        str = cword
      else
        str = vim.fn.expand("<cWORD>")
      end
    end
  end

  if not str or str == "" then
    return false
  end

  -- Check if Web URL
  if str:match("^https?://") or str:match("^www%.") then
    local url = str:gsub("^www%.", "https://www.")
    vim.ui.open(url)
    return true
  end

  local raw_path, line_num, col_num = parse_path_and_line(str)
  local resolved = resolve_file(raw_path)

  if not resolved then
    return false
  end

  -- If currently inside a terminal or floating window, find a suitable code window
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  local is_term = vim.bo[cur_buf].buftype == "terminal" or vim.api.nvim_win_get_config(cur_win).relative ~= ""

  local target_win = cur_win
  if is_term then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
        target_win = win
        break
      end
    end
  end

  vim.api.nvim_set_current_win(target_win)
  vim.cmd(string.format("edit %s", vim.fn.fnameescape(resolved)))

  if line_num then
    pcall(vim.api.nvim_win_set_cursor, target_win, { line_num, (col_num or 1) - 1 })
    vim.cmd("normal! zz")
  end

  return true
end

return M
