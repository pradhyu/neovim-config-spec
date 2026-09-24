local M = {}

---Get target lines from buffer or visual range
---@param buf? integer
---@param range? { start_line: integer, end_line: integer }
---@return string[], integer, integer
local function get_lines(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local start_line = 0
  local end_line = -1

  if range then
    start_line = range.start_line - 1
    end_line = range.end_line
  end

  local lines = vim.api.nvim_buf_get_lines(target_buf, start_line, end_line, false)
  return lines, start_line, end_line
end

---Set modified lines back into buffer
---@param buf integer
---@param start_line integer
---@param end_line integer
---@param new_lines string[]
local function set_lines(buf, start_line, end_line, new_lines)
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, new_lines)
end

---Trim trailing whitespace across buffer or selection
---@param buf? integer
---@param range? table
---@return integer trimmed_lines_count
function M.trim_whitespace(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local modified = 0
  local new_lines = {}

  for _, line in ipairs(lines) do
    local trimmed = line:gsub("%s+$", "")
    if trimmed ~= line then
      modified = modified + 1
    end
    table.insert(new_lines, trimmed)
  end

  if modified > 0 then
    set_lines(target_buf, s_line, e_line, new_lines)
  end
  vim.notify(string.format("[BufferBuddy] ✂️ Trimmed trailing whitespace on %d line(s)", modified), vim.log.levels.INFO)
  return modified
end

---Format / Prettify JSON buffer or selection
---@param buf? integer
---@param range? table
---@param indent? integer
---@return boolean, string
function M.json_format(buf, range, indent)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = table.concat(lines, "\n")

  if vim.trim(text) == "" then
    return false, "Buffer is empty"
  end

  local ok, decoded = pcall(vim.fn.json_decode, text)
  if not ok or decoded == nil then
    return false, "Invalid JSON: unable to parse"
  end

  -- Pretty print JSON using jq if available, otherwise native vim.json
  if vim.fn.executable("jq") == 1 then
    local jq_out = vim.fn.system({ "jq", string.format(". --indent %d", indent or 2) }, text)
    if vim.v.shell_error == 0 and jq_out and jq_out ~= "" then
      local formatted_lines = vim.split(vim.trim(jq_out), "\n")
      set_lines(target_buf, s_line, e_line, formatted_lines)
      vim.notify("[BufferBuddy] ✨ Formatted JSON with jq", vim.log.levels.INFO)
      return true, "Formatted JSON"
    end
  end

  local encoded = vim.fn.json_encode(decoded)
  local formatted_lines = vim.split(encoded, "\n")
  set_lines(target_buf, s_line, e_line, formatted_lines)
  vim.notify("[BufferBuddy] ✨ Formatted JSON", vim.log.levels.INFO)
  return true, "Formatted JSON"
end

---Minify JSON
---@param buf? integer
---@param range? table
---@return boolean, string
function M.json_minify(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = table.concat(lines, "\n")

  local ok, decoded = pcall(vim.fn.json_decode, text)
  if not ok or decoded == nil then
    return false, "Invalid JSON: unable to parse"
  end

  local minified = vim.fn.json_encode(decoded)
  set_lines(target_buf, s_line, e_line, { minified })
  vim.notify("[BufferBuddy] 🗜️ Minified JSON", vim.log.levels.INFO)
  return true, "Minified JSON"
end

---Base64 Encode
---@param buf? integer
---@param range? table
function M.base64_encode(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = table.concat(lines, "\n")
  local encoded = vim.base64.encode(text)
  set_lines(target_buf, s_line, e_line, { encoded })
  vim.notify("[BufferBuddy] 🔒 Base64 Encoded", vim.log.levels.INFO)
end

---Base64 Decode
---@param buf? integer
---@param range? table
function M.base64_decode(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = vim.trim(table.concat(lines, "\n"))
  local ok, decoded = pcall(vim.base64.decode, text)
  if not ok then
    vim.notify("[BufferBuddy] ❌ Invalid Base64 string", vim.log.levels.WARN)
    return
  end
  local new_lines = vim.split(decoded, "\n")
  set_lines(target_buf, s_line, e_line, new_lines)
  vim.notify("[BufferBuddy] 🔓 Base64 Decoded", vim.log.levels.INFO)
end

---URL Encode
---@param buf? integer
---@param range? table
function M.url_encode(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = table.concat(lines, "\n")
  local encoded = text:gsub("\n", "\r\n"):gsub("([^%w %-%_%.%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+")
  set_lines(target_buf, s_line, e_line, { encoded })
  vim.notify("[BufferBuddy] 🌐 URL Encoded", vim.log.levels.INFO)
end

---URL Decode
---@param buf? integer
---@param range? table
function M.url_decode(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local text = table.concat(lines, "\n")
  local decoded = text:gsub("%+", " "):gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  local new_lines = vim.split(decoded, "\n")
  set_lines(target_buf, s_line, e_line, new_lines)
  vim.notify("[BufferBuddy] 🌐 URL Decoded", vim.log.levels.INFO)
end

---Deduplicate lines in buffer
---@param buf? integer
---@param range? table
---@return integer removed_count
function M.dedup_lines(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)
  local seen = {}
  local unique_lines = {}
  local removed = 0

  for _, line in ipairs(lines) do
    if not seen[line] then
      seen[line] = true
      table.insert(unique_lines, line)
    else
      removed = removed + 1
    end
  end

  if removed > 0 then
    set_lines(target_buf, s_line, e_line, unique_lines)
  end
  vim.notify(string.format("[BufferBuddy] 🧼 Removed %d duplicate line(s)", removed), vim.log.levels.INFO)
  return removed
end

---Sort lines alphabetically or naturally
---@param buf? integer
---@param range? table
---@param unique? boolean
function M.sort_lines(buf, range, unique)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)

  table.sort(lines, function(a, b)
    return a:lower() < b:lower()
  end)

  if unique then
    local seen = {}
    local filtered = {}
    for _, l in ipairs(lines) do
      if not seen[l] then
        seen[l] = true
        table.insert(filtered, l)
      end
    end
    lines = filtered
  end

  set_lines(target_buf, s_line, e_line, lines)
  vim.notify(string.format("[BufferBuddy] 🔤 Sorted %d line(s)", #lines), vim.log.levels.INFO)
end

---Format and align Markdown / ASCII tables
---@param buf? integer
---@param range? table
function M.format_markdown_table(buf, range)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines, s_line, e_line = get_lines(target_buf, range)

  local table_lines = {}
  for _, line in ipairs(lines) do
    if line:match("|") then
      table.insert(table_lines, line)
    end
  end

  if #table_lines == 0 then
    vim.notify("[BufferBuddy] No markdown table syntax '|' found", vim.log.levels.WARN)
    return
  end

  local rows = {}
  local max_cols = 0
  local col_widths = {}

  for _, line in ipairs(table_lines) do
    local cells = {}
    -- Strip leading and trailing pipes
    local stripped = line:gsub("^%s*|", ""):gsub("|%s*$", "")
    for cell in stripped:gmatch("([^|]+)") do
      local trimmed = vim.trim(cell)
      table.insert(cells, trimmed)
    end
    max_cols = math.max(max_cols, #cells)
    table.insert(rows, cells)
  end

  for i = 1, max_cols do
    col_widths[i] = 3 -- Minimum width
    for _, row in ipairs(rows) do
      local cell = row[i] or ""
      if not cell:match("^:%-+:$") and not cell:match("^-+$") then
        col_widths[i] = math.max(col_widths[i], #cell)
      end
    end
  end

  local formatted = {}
  for r_idx, row in ipairs(rows) do
    local line_cells = {}
    for c_idx = 1, max_cols do
      local cell = row[c_idx] or ""
      local width = col_widths[c_idx]
      if cell:match("^-+$") or cell:match("^:%-+:$") then
        table.insert(line_cells, string.rep("-", width))
      else
        table.insert(line_cells, string.format("%-" .. width .. "s", cell))
      end
    end
    table.insert(formatted, "| " .. table.concat(line_cells, " | ") .. " |")
  end

  set_lines(target_buf, s_line, e_line, formatted)
  vim.notify("[BufferBuddy] 📊 Aligned Markdown Table", vim.log.levels.INFO)
end

return M
