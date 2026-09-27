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

---Save current active slots and bookmarks to session file
---@return boolean, string
function M.save_session()
  local export_slots = {}
  for id, slot in pairs(engine.slots) do
    table.insert(export_slots, {
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

  local ok_bm, bookmarks_mod = pcall(require, "smart_highlighter.core.bookmarks")
  local export_bm = {}
  if ok_bm and bookmarks_mod and bookmarks_mod.bookmarks then
    for _, bm in ipairs(bookmarks_mod.bookmarks) do
      table.insert(export_bm, {
        file = bm.file,
        line = bm.line,
        col = bm.col,
        text = bm.text,
        note = bm.note,
      })
    end
  end

  local session_payload = {
    version = 2,
    slots = export_slots,
    bookmarks = export_bm,
  }

  local file_path = get_session_file()
  local encoded = vim.fn.json_encode(session_payload)
  local f = io.open(file_path, "w")
  if not f then
    return false, "Failed to open session file for writing"
  end
  f:write(encoded)
  f:close()

  return true, string.format("Saved %d highlights & %d bookmarks to session", #export_slots, #export_bm)
end

---Load slots and bookmarks from session file
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

  local slots_data = data
  local bm_data = {}
  if data.version and data.slots then
    slots_data = data.slots
    bm_data = data.bookmarks or {}
  end

  for _, item in ipairs(slots_data) do
    if item.pattern then
      engine.add_slot(item.pattern, {
        id = item.id,
        is_regex = item.is_regex,
        whole_word = item.whole_word,
        case_sensitive = item.case_sensitive,
        scope = item.scope,
        name = item.name,
      })
    end
  end

  local ok_bm, bookmarks_mod = pcall(require, "smart_highlighter.core.bookmarks")
  if ok_bm and bookmarks_mod then
    bookmarks_mod.clear_all()
    for _, item in ipairs(bm_data) do
      if item.file and item.line then
        bookmarks_mod.set_bookmark(item.file, item.line, item.col or 0, item.text or "", item.note or item.text)
      end
    end
  end

  return true, string.format("Restored %d highlights & %d bookmarks from session", #slots_data, #bm_data)
end

return M
