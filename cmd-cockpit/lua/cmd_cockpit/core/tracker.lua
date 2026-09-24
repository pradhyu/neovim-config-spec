local stats = require("cmd_cockpit.core.stats")
local config = require("cmd_cockpit.config")

local M = {}

local tracker_ns = vim.api.nvim_create_namespace("cmd_cockpit_tracker")
local key_buffer = ""
local pending_match = nil
local pending_timer = nil
local idle_timer = nil

---Import recent command history from Neovim history table
local function import_recent_history()
  local total = vim.fn.histnr("cmd")
  if total > 0 then
    local count = math.min(total, 40)
    for i = count, 1, -1 do
      local cmd = vim.fn.histget("cmd", -i)
      if cmd and cmd ~= "" and not stats.records[cmd] then
        -- filter out noise
        if not cmd:match("^lua%s+require%('cmd_cockpit'") and not cmd:match("^CmdCockpit") then
          stats.records[cmd] = {
            id = cmd:gsub("^:", ""),
            cmd = cmd:gsub("^:", ""),
            count = 1,
            last_used = os.time() - 7200, -- historical timestamp
            pinned = false,
            kind = "cmd",
            keys = cmd:gsub("^:", ""),
          }
        end
      end
    end
  end
end

---Get all active keymaps (both global and buffer-local)
---@param mode string
---@return table<string, table>, string[]
local function get_active_mappings(mode)
  local map_lookup = {}
  local all_lhs = {}

  local function add_map(map)
    local lhs = map.lhs
    if not lhs or lhs == "" then return end
    
    map_lookup[lhs] = map
    table.insert(all_lhs, lhs)

    -- Also store leader-normalized version
    local leader = vim.g.mapleader or " "
    if leader ~= "" and lhs:sub(1, #leader) == leader then
      local norm = "<leader>" .. lhs:sub(#leader + 1)
      map_lookup[norm] = map
      table.insert(all_lhs, norm)
    end
  end

  -- 1. Global mappings
  local global_maps = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(global_maps) do
    add_map(map)
  end

  -- 2. Buffer-local mappings
  local cur_buf = vim.api.nvim_get_current_buf()
  if cur_buf and cur_buf > 0 and vim.api.nvim_buf_is_valid(cur_buf) then
    local buf_maps = vim.api.nvim_buf_get_keymap(cur_buf, mode)
    for _, map in ipairs(buf_maps) do
      add_map(map)
    end
  end

  return map_lookup, all_lhs
end

---Format display label for a keymap
---@param map table
---@return string, string
local function format_keymap_label(map)
  local leader = vim.g.mapleader or " "
  local display_lhs = map.lhs
  if leader ~= "" and display_lhs:sub(1, #leader) == leader then
    display_lhs = "<leader>" .. display_lhs:sub(#leader + 1)
  end

  local label = display_lhs
  if map.desc and map.desc ~= "" then
    label = string.format("%s (%s)", display_lhs, map.desc)
  elseif map.rhs and map.rhs ~= "" and map.rhs ~= "[Lua Function]" then
    local clean_rhs = map.rhs:gsub("<[cC][mM][dD]>", ""):gsub("<[cC][rR]>", ""):gsub("^:", "")
    label = string.format("%s (%s)", display_lhs, clean_rhs)
  end

  return label, display_lhs
end

local function fire_match(match)
  if not match then return end
  local label, raw_lhs = format_keymap_label(match)
  stats.record_command(label, "keymap", raw_lhs)
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

---Initialize command and keymap tracking
function M.setup()
  if not config.options.track_history then
    return
  end

  stats.load()
  import_recent_history()

  local group = vim.api.nvim_create_augroup("CmdCockpitTracker", { clear = true })

  -- 1. Capture Ex command on submit via CmdlineLeave
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local ev = vim.v.event
      if not ev.abort and (ev.cmdtype == ":" or ev.cmdtype == nil) then
        local cmd = vim.fn.getcmdline()
        if not cmd or cmd == "" then
          cmd = vim.fn.histget("cmd", -1)
        end
        if cmd and cmd ~= "" then
          -- Filter out internal plugin evaluation / picker commands
          if not cmd:match("^lua%s+require%('cmd_cockpit'") and not cmd:match("^CmdCockpit") then
            stats.record_command(cmd, "cmd")
          end
        end
      end
    end,
  })

  -- 2. Track keybinding shortcuts via vim.on_key with dedicated namespace
  if config.options.track_keymaps then
    vim.on_key(function(key, typed)
      if not typed or typed == "" then
        return
      end

      -- Check for escape / cancel sequences
      if typed == "\27" or typed == "\3" or typed == "\7" then
        cancel_timers()
        if pending_match then
          fire_match(pending_match)
        end
        key_buffer = ""
        return
      end

      local mode = vim.fn.mode()
      -- Only track in Normal or Visual mode
      if not mode:match("^[nvV\22]") and not mode:match("^no") then
        cancel_timers()
        key_buffer = ""
        return
      end

      local base_mode = mode:sub(1, 1)
      if base_mode ~= "n" and base_mode ~= "v" and base_mode ~= "V" then
        base_mode = "n"
      end

      local map_lookup, all_lhs = get_active_mappings(base_mode)

      -- Check if 'typed' by itself is already a full composite key sequence (e.g. from feedkeys/macro)
      if #typed > 1 and map_lookup[typed] then
        cancel_timers()
        fire_match(map_lookup[typed])
        return
      end

      local candidate = key_buffer .. typed

      -- Check if any mappings start with candidate (prefix check)
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
        -- 1. Exact leaf match: execute immediately!
        fire_match(exact_match)
      elseif exact_match and has_longer_prefix then
        -- 2. Exact match with potential longer variations (e.g. <leader>b vs <leader>bd)
        pending_match = exact_match
        key_buffer = candidate

        local timeout = (vim.o.timeoutlen > 0) and vim.o.timeoutlen or 500
        pending_timer = vim.loop.new_timer()
        pending_timer:start(timeout + 50, 0, vim.schedule_wrap(function()
          if pending_match then
            fire_match(pending_match)
          end
        end))
      elseif has_longer_prefix then
        -- 3. In the middle of typing a multi-key sequence
        key_buffer = candidate
        idle_timer = vim.loop.new_timer()
        idle_timer:start(3500, 0, vim.schedule_wrap(function()
          key_buffer = ""
          pending_match = nil
        end))
      else
        -- 4. No prefix and no match: if we had a pending match, fire it; otherwise reset
        if pending_match then
          fire_match(pending_match)
        end
        key_buffer = ""
      end
    end, tracker_ns)
  end

  -- Save history on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stats.save()
    end,
  })
end

return M
