local stats = require("cmd_cockpit.core.stats")
local config = require("cmd_cockpit.config")

local M = {}

local active_cmd_buffer = ""
local key_buffer = ""
local key_timer = nil

---Import recent command history from Neovim history table
local function import_recent_history()
  local total = vim.fn.histnr("cmd")
  if total > 0 then
    local count = math.min(total, 40)
    for i = count, 1, -1 do
      local cmd = vim.fn.histget("cmd", -i)
      if cmd and cmd ~= "" and not stats.records[cmd] then
        stats.records[cmd] = {
          cmd = cmd,
          count = 1,
          last_used = os.time() - 7200, -- historical timestamp (2 hours ago)
          pinned = false,
          kind = "cmd",
        }
      end
    end
  end
end

---Build lookup table of all active keymaps (filtering out single basic motion keys)
local function get_keymap_lookup()
  local lookup = {}
  local modes = { "n", "v" }
  for _, m in ipairs(modes) do
    local maps = vim.api.nvim_get_keymap(m)
    for _, map in ipairs(maps) do
      local lhs = map.lhs
      -- Only track leader mappings (starts with Space) or custom multi-key combinations
      if lhs:sub(1, 1) == " " or lhs:match("^<[lL]eader>") or lhs:match("^<[cC]%-") or #lhs >= 2 then
        lookup[lhs] = map
      end
    end
  end
  return lookup
end

---Initialize command and keymap tracking
function M.setup()
  if not config.options.track_history then
    return
  end

  stats.load()
  import_recent_history()

  local group = vim.api.nvim_create_augroup("CmdCockpitTracker", { clear = true })

  -- 1. Track live typing in Command Line
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = group,
    callback = function()
      local line = vim.fn.getcmdline()
      if line and line ~= "" then
        active_cmd_buffer = line
      end
    end,
  })

  -- 2. Capture Ex command on submit
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      local ev = vim.v.event
      if not ev.abort then
        local cmd = active_cmd_buffer ~= "" and active_cmd_buffer or vim.fn.histget("cmd", -1)
        if cmd and cmd ~= "" then
          stats.record_command(cmd, "cmd")
        end
      end
      active_cmd_buffer = ""
    end,
  })

  -- 3. Track keybinding shortcuts via vim.on_key
  if config.options.track_keymaps then
    local map_lookup = get_keymap_lookup()

    -- Refresh lookup on buffer switch
    vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
      group = group,
      callback = function()
        map_lookup = get_keymap_lookup()
      end,
    })

    vim.on_key(function(key, typed)
      if not typed or typed == "" then
        return
      end

      local mode = vim.fn.mode()
      if mode ~= "n" and mode ~= "v" and mode ~= "V" then
        key_buffer = ""
        return
      end

      -- Reset timer
      if key_timer then
        key_timer:stop()
        key_timer:close()
        key_timer = nil
      end

      key_timer = vim.loop.new_timer()
      key_timer:start(1500, 0, vim.schedule_wrap(function()
        key_buffer = ""
      end))

      -- Check for match in lookup (handles both full sequence in typed and accumulated key_buffer)
      local match = map_lookup[typed] or map_lookup[key_buffer .. typed] or map_lookup[key_buffer]
      if match then
        local display_lhs = match.lhs
        if display_lhs:sub(1, 1) == " " then
          display_lhs = "<leader>" .. display_lhs:sub(2)
        end

        local label = display_lhs
        if match.desc and match.desc ~= "" then
          label = string.format("%s (%s)", display_lhs, match.desc)
        elseif match.rhs and match.rhs ~= "" and match.rhs ~= "[Lua Function]" then
          local clean_rhs = match.rhs:gsub("<[cC][mM][dD]>", ""):gsub("<[cC][rR]>", ""):gsub("^:", "")
          label = string.format("%s (%s)", display_lhs, clean_rhs)
        end

        local raw_k = display_lhs
        key_buffer = ""
        stats.record_command(label, "keymap", raw_k)
      else
        key_buffer = key_buffer .. typed
        if #key_buffer > 8 then
          key_buffer = ""
        end
      end
    end)
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
