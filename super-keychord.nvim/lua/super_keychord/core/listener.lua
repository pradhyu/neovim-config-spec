local tracker = require("super_keychord.core.tracker")
local keychords = require("super_keychord.core.keychords")
local config = require("super_keychord.config")

local M = {}

local tracker_ns = vim.api.nvim_create_namespace("super_keychord_listener")
local key_buffer = ""
local pending_match = nil
local pending_timer = nil
local idle_timer = nil

---Get mapping lookup table for a mode
---@param mode string
---@return table<string, table>, string[]
local function get_mode_mappings(mode)
  local map_lookup = {}
  local all_lhs = {}

  local function add_map(map)
    local lhs = map.lhs
    if not lhs or lhs == "" then return end

    map_lookup[lhs] = map
    table.insert(all_lhs, lhs)

    -- Also check leader-normalized representation
    local leader = vim.g.mapleader or "\\"
    if leader ~= "" and lhs:sub(1, #leader) == leader then
      local norm = "<leader>" .. lhs:sub(#leader + 1)
      map_lookup[norm] = map
      table.insert(all_lhs, norm)
    elseif lhs:sub(1, 1) == " " then
      local norm = "<leader>" .. lhs:sub(2)
      map_lookup[norm] = map
      table.insert(all_lhs, norm)
    end
  end

  local global_maps = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(global_maps) do
    add_map(map)
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  if cur_buf and cur_buf > 0 and vim.api.nvim_buf_is_valid(cur_buf) then
    local buf_maps = vim.api.nvim_buf_get_keymap(cur_buf, mode)
    for _, map in ipairs(buf_maps) do
      add_map(map)
    end
  end

  return map_lookup, all_lhs
end

local function fire_keychord(map)
  if not map then return end
  local display_lhs = keychords.normalize_chord(map.lhs)
  tracker.record_usage(display_lhs, false)
  pending_match = nil
  key_buffer = ""
end

local function cancel_timers()
  if pending_timer then
    pcall(function()
      pending_timer:stop()
      pending_timer:close()
    end)
    pending_timer = nil
  end
  if idle_timer then
    pcall(function()
      idle_timer:stop()
      idle_timer:close()
    end)
    idle_timer = nil
  end
end

---Setup background keystroke listener to track direct usage
function M.setup()
  tracker.load()

  if not config.options.track_usage then
    return
  end

  -- Listen to live keys typed in Neovim
  vim.on_key(function(key, typed)
    if not typed or typed == "" then
      return
    end

    -- Escape / interrupt keys cancel pending sequence
    if typed == "\27" or typed == "\3" or typed == "\7" then
      cancel_timers()
      if pending_match then
        fire_keychord(pending_match)
      end
      key_buffer = ""
      return
    end

    local mode = vim.fn.mode()
    -- Only track Normal, Visual, or Operator pending modes
    if not mode:match("^[nvV\22]") and not mode:match("^no") then
      cancel_timers()
      key_buffer = ""
      return
    end

    local base_mode = mode:sub(1, 1)
    if base_mode ~= "n" and base_mode ~= "v" and base_mode ~= "V" then
      base_mode = "n"
    end

    local map_lookup, all_lhs = get_mode_mappings(base_mode)

    -- If typed key by itself is a registered full keymap (or composite keystroke)
    if #typed > 1 and map_lookup[typed] then
      cancel_timers()
      fire_keychord(map_lookup[typed])
      return
    end

    local candidate = key_buffer .. typed
    local exact_match = map_lookup[candidate]
    local has_longer_prefix = false

    for _, lhs in ipairs(all_lhs) do
      if lhs:sub(1, #candidate) == candidate and #lhs > #candidate then
        has_longer_prefix = true
        break
      end
    end

    cancel_timers()

    if exact_match and not has_longer_prefix then
      fire_keychord(exact_match)
    elseif exact_match and has_longer_prefix then
      pending_match = exact_match
      key_buffer = candidate
      local timeout = (vim.o.timeoutlen > 0) and vim.o.timeoutlen or 500
      pending_timer = vim.loop.new_timer()
      pending_timer:start(timeout + 50, 0, vim.schedule_wrap(function()
        if pending_match then
          fire_keychord(pending_match)
        end
      end))
    elseif has_longer_prefix then
      key_buffer = candidate
      idle_timer = vim.loop.new_timer()
      idle_timer:start(3000, 0, vim.schedule_wrap(function()
        key_buffer = ""
        pending_match = nil
      end))
    else
      if pending_match then
        fire_keychord(pending_match)
      end
      key_buffer = ""
    end
  end, tracker_ns)

  -- Persist on Neovim exit
  local group = vim.api.nvim_create_augroup("SuperKeychordPersistence", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      tracker.save()
    end,
  })
end

return M
