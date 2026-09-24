local M = {}

---@class KeymapEntry
---@field lhs string
---@field rhs string
---@field desc string
---@field mode string
---@field buffer integer?
---@field silent boolean
---@field noremap boolean
---@field is_custom boolean

---Get all keymaps for a given mode or all modes
---@param mode? string ("n"|"v"|"i"|"t"|"c"|"x"|"o"|"all")
---@param buf? integer
---@return KeymapEntry[]
function M.get_keymaps(mode, buf)
  local modes = { "n", "v", "i", "t", "x", "o", "c" }
  if mode and mode ~= "all" then
    modes = { mode }
  end

  local all_maps = {}
  local seen = {}

  for _, m in ipairs(modes) do
    -- Global keymaps
    local global_maps = vim.api.nvim_get_keymap(m)
    for _, map in ipairs(global_maps) do
      local key = string.format("%s:%s", m, map.lhs)
      if not seen[key] then
        seen[key] = true
        table.insert(all_maps, {
          lhs = map.lhs,
          rhs = map.rhs or (map.callback and "[Lua Function]" or ""),
          desc = map.desc or "",
          mode = m,
          buffer = nil,
          silent = map.silent == 1,
          noremap = map.noremap == 1,
          is_custom = false,
        })
      end
    end

    -- Buffer-local keymaps
    local target_buf = buf or vim.api.nvim_get_current_buf()
    if target_buf and target_buf > 0 and vim.api.nvim_buf_is_valid(target_buf) then
      local buf_maps = vim.api.nvim_buf_get_keymap(target_buf, m)
      for _, map in ipairs(buf_maps) do
        local key = string.format("%s:%s:buf%d", m, map.lhs, target_buf)
        if not seen[key] then
          seen[key] = true
          table.insert(all_maps, {
            lhs = map.lhs,
            rhs = map.rhs or (map.callback and "[Lua Function]" or ""),
            desc = map.desc or "",
            mode = m,
            buffer = target_buf,
            silent = map.silent == 1,
            noremap = map.noremap == 1,
            is_custom = false,
          })
        end
      end
    end
  end

  -- Sort: by mode then lhs
  table.sort(all_maps, function(a, b)
    if a.mode ~= b.mode then
      return a.mode < b.mode
    end
    return a.lhs < b.lhs
  end)

  return all_maps
end

---Search keymaps by query string (matching lhs, rhs, or desc)
---@param query string
---@param mode? string
---@return KeymapEntry[]
function M.search_keymaps(query, mode)
  local maps = M.get_keymaps(mode)
  if not query or query == "" then
    return maps
  end

  local q = query:lower()
  local results = {}
  for _, map in ipairs(maps) do
    local lhs_match = map.lhs:lower():find(q, 1, true)
    local rhs_match = map.rhs:lower():find(q, 1, true)
    local desc_match = map.desc:lower():find(q, 1, true)

    if lhs_match or rhs_match or desc_match then
      table.insert(results, map)
    end
  end

  return results
end

---Find potential collisions (different actions mapped to identical LHS in same mode)
---@return table<string, KeymapEntry[]>
function M.find_collisions()
  local maps = M.get_keymaps("all")
  local lookup = {}
  local collisions = {}

  for _, map in ipairs(maps) do
    local key = string.format("%s:%s", map.mode, map.lhs)
    lookup[key] = lookup[key] or {}
    table.insert(lookup[key], map)
  end

  for key, entries in pairs(lookup) do
    if #entries > 1 then
      collisions[key] = entries
    end
  end

  return collisions
end

return M
