local engine = require("smart_highlighter.core.engine")

local M = {}

---Get session storage directory path
---@return string
local function get_storage_dir()
  local base = vim.fn.stdpath("state") .. "/smart-highlighter"
  if vim.fn.isdirectory(base) == 0 then
    vim.fn.mkdir(base, "p")
  end
  return base
end

---Get unique hash or filename for current working directory
---@return string
local function get_session_file()
  local cwd = vim.fn.getcwd()
  -- Replace slashes with underscores for safe filename
  local safe_name = cwd:gsub("[/\\]", "_") .. ".json"
  return get_storage_dir() .. "/" .. safe_name
end

---Save current active slots to session file
---@return boolean, string
function M.save_session()
  local export_data = {}
  for id, slot in pairs(engine.slots) do
    table.insert(export_data, {
      id = slot.id,
      pattern = slot.pattern,
      is_regex = slot.is_regex,
      whole_word = slot.whole_word,
      case_sensitive = slot.case_sensitive,
      enabled = slot.enabled,
      scope = slot.scope,
      name = slot.name,
      color_idx = slot.color_idx,
    })
  end

  local file_path = get_session_file()
  local encoded = vim.fn.json_encode(export_data)
  local f = io.open(file_path, "w")
  if not f then
    return false, "Failed to open session file for writing"
  end
  f:write(encoded)
  f:close()

  return true, string.format("Saved %d highlights to session", #export_data)
end

---Load slots from session file
---@return boolean, string
function M.load_session()
  local file_path = get_session_file()
  local f = io.open(file_path, "r")
  if not f then
    return false, "No saved session found for current directory"
  end
  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return false, "Empty session file"
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= "table" then
    return false, "Corrupted session file"
  end

  engine.clear_all()
  for _, item in ipairs(data) do
    engine.add_slot(item.pattern, {
      id = item.id,
      is_regex = item.is_regex,
      whole_word = item.whole_word,
      case_sensitive = item.case_sensitive,
      scope = item.scope,
      name = item.name,
    })
  end

  return true, string.format("Restored %d highlights from session", #data)
end

return M
