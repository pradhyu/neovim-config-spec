local config = require("super_keychord.config")

local M = {}

---@class KeychordEntry
---@field raw_lhs string Original lhs from nvim_get_keymap
---@field display_lhs string Human-readable representation (e.g. "<leader>fe")
---@field clean_lhs string Search-friendly string (spaces, special keys normalized)
---@field rhs string Action string, command or Lua description
---@field desc string Human description from nvim keymap
---@field mode string Mode flag ("n", "v", "i", "t", "x", "o", "c")
---@field buffer integer|nil Buffer handle if buffer-local
---@field silent boolean
---@field noremap boolean
---@field nowait boolean
---@field expr boolean
---@field is_plug boolean Whether lhs starts with <Plug>
---@field callback function|nil

---Get the configured leader key string in Neovim
---@return string
local function get_leader_char()
  local l = vim.g.mapleader
  if l == nil or l == "" then
    return "\\"
  end
  return l
end

---Normalize a key string for clean presentation and partial matching
---E.g. " fe" -> "<leader>fe", "\27" -> "<Esc>"
---@param lhs string
---@return string display_lhs, string clean_lhs
function M.normalize_chord(lhs)
  if not lhs or lhs == "" then
    return "", ""
  end

  local leader_char = get_leader_char()
  local display = lhs

  -- If it starts with current mapleader (or standard space / backslash leader)
  if leader_char ~= "" and display:sub(1, #leader_char) == leader_char then
    display = "<leader>" .. display:sub(#leader_char + 1)
  elseif display:sub(1, 1) == " " or display:sub(1, 1) == "\\" then
    display = "<leader>" .. display:sub(2)
  elseif display:sub(1, 7) == "<Space>" or display:sub(1, 7) == "<space>" then
    display = "<leader>" .. display:sub(8)
  end

  -- Replace common control/escape characters with readable notations
  display = display:gsub("\27", "<Esc>")
  display = display:gsub("\r", "<CR>")
  display = display:gsub("\n", "<NL>")
  display = display:gsub("\t", "<Tab>")

  -- Clean version for searching without brackets or case sensitivity
  local clean = display:gsub("<", ""):gsub(">", ""):lower()

  return display, clean
end

---Check if a keymap should be included based on filters
---@param raw_lhs string
---@param desc string
---@return boolean
local function should_include(raw_lhs, desc)
  if not config.options.include_plug_maps then
    if raw_lhs:match("^<[pP]lug>") or raw_lhs:match("^<[sS][nN][rR]>") then
      return false
    end
  end
  return true
end

---Collect keychords across modes and buffers
---@param mode? string Mode ("all" or "n", "v", "i", "t", "x", "o", "c")
---@param buf? integer Buffer handle or nil
---@return KeychordEntry[]
function M.get_keychords(mode, buf)
  local modes = { "n", "v", "i", "t", "x", "o", "c" }
  if mode and mode ~= "all" then
    modes = { mode }
  end

  local entries = {}
  local seen = {}

  for _, m in ipairs(modes) do
    -- 1. Global keymaps
    local global_maps = vim.api.nvim_get_keymap(m)
    for _, map in ipairs(global_maps) do
      local raw_lhs = map.lhs or ""
      local desc = map.desc or ""
      if should_include(raw_lhs, desc) then
        local key = string.format("%s:%s", m, raw_lhs)
        if not seen[key] then
          seen[key] = true
          local display_lhs, clean_lhs = M.normalize_chord(raw_lhs)
          local rhs_str = map.rhs or (map.callback and "[Lua Callback]" or "")

          table.insert(entries, {
            raw_lhs = raw_lhs,
            display_lhs = display_lhs,
            clean_lhs = clean_lhs,
            rhs = rhs_str,
            desc = desc,
            mode = m,
            buffer = nil,
            silent = map.silent == 1,
            noremap = map.noremap == 1,
            nowait = map.nowait == 1,
            expr = map.expr == 1,
            is_plug = raw_lhs:match("^<[pP]lug>") ~= nil,
            callback = map.callback,
          })
        end
      end
    end

    -- 2. Buffer-local keymaps
    if config.options.include_buffer_local then
      local target_buf = buf or vim.api.nvim_get_current_buf()
      if target_buf and target_buf > 0 and vim.api.nvim_buf_is_valid(target_buf) then
        local buf_maps = vim.api.nvim_buf_get_keymap(target_buf, m)
        for _, map in ipairs(buf_maps) do
          local raw_lhs = map.lhs or ""
          local desc = map.desc or ""
          if should_include(raw_lhs, desc) then
            local key = string.format("%s:%s:buf%d", m, raw_lhs, target_buf)
            if not seen[key] then
              seen[key] = true
              local display_lhs, clean_lhs = M.normalize_chord(raw_lhs)
              local rhs_str = map.rhs or (map.callback and "[Lua Callback]" or "")

              table.insert(entries, {
                raw_lhs = raw_lhs,
                display_lhs = display_lhs,
                clean_lhs = clean_lhs,
                rhs = rhs_str,
                desc = desc,
                mode = m,
                buffer = target_buf,
                silent = map.silent == 1,
                noremap = map.noremap == 1,
                nowait = map.nowait == 1,
                expr = map.expr == 1,
                is_plug = raw_lhs:match("^<[pP]lug>") ~= nil,
                callback = map.callback,
              })
            end
          end
        end
      end
    end
  end

  -- Sort: prioritized by having a description, then mode, then display_lhs
  table.sort(entries, function(a, b)
    local a_has_desc = a.desc ~= ""
    local b_has_desc = b.desc ~= ""
    if a_has_desc ~= b_has_desc then
      return a_has_desc
    end
    if a.mode ~= b.mode then
      return a.mode < b.mode
    end
    return a.display_lhs < b.display_lhs
  end)

  return entries
end

---Execute a keychord entry in the editor
---@param entry KeychordEntry
function M.execute_keychord(entry)
  if not entry then return end

  -- If entry has a direct Lua callback, execute it directly
  if type(entry.callback) == "function" then
    local ok, err = pcall(entry.callback)
    if not ok then
      vim.notify(string.format("[SuperKeychord] Error executing keychord '%s': %s", entry.display_lhs, tostring(err)), vim.log.levels.ERROR)
    end
    return
  end

  -- If it has a rhs string that is an ex command (<Cmd>...<CR> or :...)
  if entry.rhs and entry.rhs ~= "" then
    local cmd = entry.rhs:match("^<[cC][mM][dD]>(.-)<[cC][rR]>$")
    if cmd then
      vim.cmd(cmd)
      return
    end
    if entry.rhs:sub(1, 1) == ":" and entry.rhs:sub(-4):lower() == "<cr>" then
      vim.cmd(entry.rhs:sub(2, -5))
      return
    end
  end

  -- Fallback: feedkeys using nvim_feedkeys
  local keys = vim.api.nvim_replace_termcodes(entry.raw_lhs, true, false, true)
  vim.api.nvim_feedkeys(keys, entry.mode == "n" and "n" or "m", false)
end

return M
