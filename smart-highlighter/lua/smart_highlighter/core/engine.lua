local palette = require("smart_highlighter.core.palette")
local config = require("smart_highlighter.config")
local treesitter = require("smart_highlighter.core.treesitter")

local M = {}

---@class HighlightSlot
---@field id integer
---@field pattern string
---@field is_regex boolean
---@field whole_word boolean
---@field case_sensitive boolean
---@field enabled boolean
---@field scope "global"|"buffer"|"treesitter"
---@field scope_range? { start_row: integer, start_col: integer, end_row: integer, end_col: integer }
---@field target_buf? integer
---@field name string
---@field color_idx integer
---@field vim_regex? userdata

---@type table<integer, HighlightSlot>
M.slots = {}

---@type integer
M.ns_id = vim.api.nvim_create_namespace("smart_highlighter_ns")

---Initialize engine
function M.init()
  palette.setup_highlights()
end

---Find next available slot ID (1..max_slots)
---@return integer?
function M.get_next_available_slot_id()
  local max_slots = config.options.max_slots or 16
  for i = 1, max_slots do
    if not M.slots[i] then
      return i
    end
  end
  -- If all occupied, reuse the first one
  return 1
end

---Find slot by exact pattern string
---@param pattern string
---@return integer?, HighlightSlot?
function M.find_slot_by_pattern(pattern)
  for id, slot in pairs(M.slots) do
    if slot.pattern == pattern then
      return id, slot
    end
  end
  return nil, nil
end

---Build a compiled vim.regex object from pattern settings
---@param pattern string
---@param is_regex boolean
---@param whole_word boolean
---@param case_sensitive boolean
---@return userdata?
local function compile_regex(pattern, is_regex, whole_word, case_sensitive)
  local vim_pat = pattern
  if not is_regex then
    -- Escape special characters for literal search
    vim_pat = vim.fn.escape(pattern, "\\/~.*$^~[]\\")
    if whole_word then
      vim_pat = [[\<]] .. vim_pat .. [[\>]]
    end
  end

  if case_sensitive then
    vim_pat = [[\C]] .. vim_pat
  else
    vim_pat = [[\c]] .. vim_pat
  end

  local ok, compiled = pcall(vim.regex, vim_pat)
  if ok and compiled then
    return compiled
  end
  return nil
end

---Add or update a highlight slot
---@param pattern string
---@param opts? { id?: integer, is_regex?: boolean, whole_word?: boolean, case_sensitive?: boolean, scope?: "global"|"buffer"|"treesitter", scope_range?: table, target_buf?: integer, name?: string }
---@return integer slot_id
function M.add_slot(pattern, opts)
  opts = opts or {}
  local id = opts.id or M.get_next_available_slot_id() or 1
  local is_regex = opts.is_regex or false
  local whole_word = (opts.whole_word ~= nil) and opts.whole_word or config.options.whole_word
  local case_sensitive = (opts.case_sensitive ~= nil) and opts.case_sensitive or config.options.case_sensitive

  local default_scope = "global"
  if config.options.treesitter_scope then
    default_scope = "treesitter"
  elseif config.options.buffer_scope == "current" or config.options.buffer_scope == "buffer" then
    default_scope = "buffer"
  end

  local scope = opts.scope or default_scope
  local name = opts.name or pattern
  local target_buf = opts.target_buf or vim.api.nvim_get_current_buf()

  local compiled = compile_regex(pattern, is_regex, whole_word, case_sensitive)

  local slot = {
    id = id,
    pattern = pattern,
    is_regex = is_regex,
    whole_word = whole_word,
    case_sensitive = case_sensitive,
    enabled = true,
    scope = scope,
    scope_range = opts.scope_range,
    target_buf = target_buf,
    name = name,
    color_idx = id,
    vim_regex = compiled,
  }

  M.slots[id] = slot
  M.render_all_buffers()
  local session = package.loaded["smart_highlighter.core.session"]
  if session then
    session.request_auto_save()
  end
  return id
end

---Remove a highlight slot
---@param id integer
---@return boolean
function M.remove_slot(id)
  if M.slots[id] then
    M.slots[id] = nil
    M.render_all_buffers()
    local session = package.loaded["smart_highlighter.core.session"]
    if session then
      session.request_auto_save()
    end
    return true
  end
  return false
end

---Toggle enable/disable status of a slot
---@param id integer
---@return boolean? new_state
function M.toggle_slot(id)
  if M.slots[id] then
    M.slots[id].enabled = not M.slots[id].enabled
    M.render_all_buffers()
    local session = package.loaded["smart_highlighter.core.session"]
    if session then
      session.request_auto_save()
    end
    return M.slots[id].enabled
  end
  return nil
end

---Clear all highlight slots
function M.clear_all()
  M.slots = {}
  -- Clear all extmarks across all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns_id, 0, -1)
    end
  end
  local session = package.loaded["smart_highlighter.core.session"]
  if session then
    session.request_auto_save()
  end
end

---Toggle highlight for word under cursor or visual selection
---@param custom_text? string
---@param use_scope? boolean|string -- boolean (true for treesitter) or "all"|"current"|"treesitter"|"global"|"buffer"
---@param buffer_scope? "all"|"current"|"global"|"buffer"
---@return integer? slot_id, string? action ("added"|"removed")
function M.toggle_word(custom_text, use_scope, buffer_scope)
  local text = custom_text
  if not text or text == "" then
    -- Get word under cursor or visual selection
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      -- Visual selection
      local _, csrow, cscol, _ = unpack(vim.fn.getpos("'<"))
      local _, cerow, cecol, _ = unpack(vim.fn.getpos("'>"))
      if csrow == cerow then
        local line = vim.api.nvim_buf_get_lines(0, csrow - 1, csrow, false)[1] or ""
        text = string.sub(line, cscol, cecol)
      end
    end
    if not text or text == "" then
      text = vim.fn.expand("<cword>")
    end
  end

  if not text or text == "" then
    return nil, nil
  end

  -- Check if already highlighted
  local existing_id, _ = M.find_slot_by_pattern(text)
  if existing_id then
    M.remove_slot(existing_id)
    return existing_id, "removed"
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local scope_range = nil
  local scope_type = "global"

  local is_ts = (use_scope == true) or (use_scope == "treesitter") or config.options.treesitter_scope
  local b_scope = buffer_scope
  if type(use_scope) == "string" and (use_scope == "current" or use_scope == "buffer" or use_scope == "all" or use_scope == "global") then
    b_scope = use_scope
  end

  if is_ts then
    scope_range = treesitter.get_enclosing_scope_range()
    if scope_range then
      scope_type = "treesitter"
    end
  elseif b_scope == "current" or b_scope == "buffer" then
    scope_type = "buffer"
  elseif b_scope == "all" or b_scope == "global" then
    scope_type = "global"
  elseif config.options.buffer_scope == "current" or config.options.buffer_scope == "buffer" then
    scope_type = "buffer"
  else
    scope_type = "global"
  end

  local id = M.add_slot(text, {
    whole_word = true,
    is_regex = false,
    scope = scope_type,
    scope_range = scope_range,
    target_buf = cur_buf,
  })

  return id, "added"
end

---Render highlights in a single buffer
---@param buf integer
function M.render_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end

  -- Clear existing highlights in this namespace
  pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns_id, 0, -1)

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 0 then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)

  for id, slot in pairs(M.slots) do
    if slot.enabled and slot.vim_regex then
      -- Check scope bounds
      local start_line = 0
      local end_line = line_count - 1

      if slot.scope == "treesitter" and slot.scope_range then
        if slot.target_buf and slot.target_buf ~= buf then
          goto continue_slot
        end
        start_line = math.max(0, slot.scope_range.start_row)
        end_line = math.min(line_count - 1, slot.scope_range.end_row)
      elseif (slot.scope == "buffer" or slot.scope == "current") and slot.target_buf and slot.target_buf ~= buf then
        -- Skip other buffers
        goto continue_slot
      end

      local hl_group = string.format("SmartHighlightSlot%d", slot.color_idx or id)

      for l_idx = start_line, end_line do
        local line = lines[l_idx + 1]
        if line and line ~= "" then
          local col_offset = 0
          while col_offset < #line do
            local sub_str = string.sub(line, col_offset + 1)
            local s_match, e_match = slot.vim_regex:match_str(sub_str)
            if s_match and e_match and s_match < e_match then
              local match_start_col = col_offset + s_match
              local match_end_col = col_offset + e_match

              pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, l_idx, match_start_col, {
                end_col = match_end_col,
                hl_group = hl_group,
                priority = 200,
              })

              col_offset = match_end_col
            else
              break
            end
          end
        end
      end
    end
    ::continue_slot::
  end
end

---Render highlights in all loaded buffers
function M.render_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      M.render_buffer(buf)
    end
  end
end

---Get list of all match positions for a slot in a buffer
---@param slot_id integer
---@param buf? integer
---@return { row: integer, col: integer, end_col: integer, text: string }[]
function M.get_matches(slot_id, buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local slot = M.slots[slot_id]
  if not slot or not slot.vim_regex or not vim.api.nvim_buf_is_valid(target_buf) then
    return {}
  end

  local line_count = vim.api.nvim_buf_line_count(target_buf)
  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, line_count, false)
  local matches = {}

  local start_line = 0
  local end_line = line_count - 1

  if slot.scope == "treesitter" and slot.scope_range then
    if slot.target_buf and slot.target_buf ~= target_buf then
      return {}
    end
    start_line = math.max(0, slot.scope_range.start_row)
    end_line = math.min(line_count - 1, slot.scope_range.end_row)
  elseif (slot.scope == "buffer" or slot.scope == "current") and slot.target_buf and slot.target_buf ~= target_buf then
    return {}
  end

  for l_idx = start_line, end_line do
    local line = lines[l_idx + 1]
    if line and line ~= "" then
      local col_offset = 0
      while col_offset < #line do
        local sub_str = string.sub(line, col_offset + 1)
        local s_match, e_match = slot.vim_regex:match_str(sub_str)
        if s_match and e_match and s_match < e_match then
          local match_start_col = col_offset + s_match
          local match_end_col = col_offset + e_match
          local match_text = string.sub(line, match_start_col + 1, match_end_col)

          table.insert(matches, {
            row = l_idx + 1, -- 1-indexed for user navigation
            col = match_start_col,
            end_col = match_end_col,
            text = match_text,
          })

          col_offset = match_end_col
        else
          break
        end
      end
    end
  end

  return matches
end

---Toggle scope for a slot between "global" (all buffers) and "buffer" (current buffer)
---@param id integer
---@param target_scope? "global"|"buffer"|"all"|"current"
---@return string? new_scope
function M.toggle_slot_scope(id, target_scope)
  local slot = M.slots[id]
  if not slot then
    return nil
  end

  if target_scope then
    if target_scope == "all" or target_scope == "global" then
      slot.scope = "global"
    else
      slot.scope = "buffer"
      slot.target_buf = vim.api.nvim_get_current_buf()
    end
  else
    if slot.scope == "global" then
      slot.scope = "buffer"
      slot.target_buf = vim.api.nvim_get_current_buf()
    else
      slot.scope = "global"
    end
  end

  M.render_all_buffers()
  return slot.scope
end

---Toggle or set default buffer scope across all new highlights
---@param scope? "all"|"current"|"toggle"
---@return string new_scope ("all"|"current")
function M.set_default_scope(scope)
  if scope == "all" or scope == "global" then
    config.options.buffer_scope = "all"
  elseif scope == "current" or scope == "buffer" then
    config.options.buffer_scope = "current"
  else
    if config.options.buffer_scope == "current" then
      config.options.buffer_scope = "all"
    else
      config.options.buffer_scope = "current"
    end
  end
  return config.options.buffer_scope
end

---Get occurrence count for a slot
---@param slot_id integer
---@param buf? integer
---@return integer
function M.count_matches(slot_id, buf)
  local matches = M.get_matches(slot_id, buf)
  return #matches
end

---Get all active slots with their match counts
---@param buf? integer
---@return table[]
function M.get_slot_summaries(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local list = {}
  for id = 1, (config.options.max_slots or 16) do
    local slot = M.slots[id]
    if slot then
      local count = M.count_matches(id, target_buf)
      local color = palette.get_slot_color(slot.color_idx or id)
      table.insert(list, {
        id = id,
        pattern = slot.pattern,
        name = slot.name,
        enabled = slot.enabled,
        scope = slot.scope,
        target_buf = slot.target_buf,
        is_regex = slot.is_regex,
        count = count,
        color = color,
      })
    end
  end
  return list
end

return M
