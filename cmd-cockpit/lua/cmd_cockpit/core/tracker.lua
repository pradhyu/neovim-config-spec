local stats = require("cmd_cockpit.core.stats")
local config = require("cmd_cockpit.config")
local keymaps = require("cmd_cockpit.core.keymaps")

local M = {}

local active_cmd_buffer = ""
local key_buffer = ""
local key_timer = nil

---Import recent command history from Neovim history table
local function import_recent_history()
  local total = vim.fn.histnr("cmd")
  if total > 0 then
    local count = math.min(total, 60)
    for i = count, 1, -1 do
      local cmd = vim.fn.histget("cmd", -i)
      if cmd and cmd ~= "" then
        stats.record_command(cmd, "cmd")
      end
    end
  end
end

---Build lookup table of leader keymaps
local function get_leader_keymaps()
  local maps = keymaps.get_keymaps("n")
  local lookup = {}
  for _, m in ipairs(maps) do
    local lhs = m.lhs
    if lhs:match("^%s*<[Ll]eader>") or lhs:match("^ ") then
      -- Normalize space to <leader>
      local norm = lhs:gsub("^ ", "<leader>")
      lookup[norm] = m
      lookup[lhs] = m
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

  -- 3. Track <leader> keybinding shortcuts via vim.on_key
  if config.options.track_keymaps then
    local leader_maps = get_leader_keymaps()

    -- Refresh leader lookup periodically on keymap change
    vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
      group = group,
      callback = function()
        leader_maps = get_leader_keymaps()
      end,
    })

    vim.on_key(function(key, typed)
      if not typed or typed == "" then
        return
      end

      local mode = vim.fn.mode()
      -- Only track in Normal / Visual mode
      if mode ~= "n" and mode ~= "v" and mode ~= "V" then
        key_buffer = ""
        return
      end

      -- If buffer is empty and typed key is Space (standard leader) or leader char
      if key_buffer == "" then
        if typed == " " or typed == "\\" then
          key_buffer = "<leader>"
          if key_timer then key_timer:stop(); key_timer:close() end
          key_timer = vim.loop.new_timer()
          key_timer:start(1500, 0, vim.schedule_wrap(function()
            key_buffer = ""
          end))
        end
      else
        -- Append typed key
        key_buffer = key_buffer .. typed

        -- Check if current buffer matches a known leader keymap
        local match = leader_maps[key_buffer]
        if match then
          local label = key_buffer
          if match.desc and match.desc ~= "" then
            label = string.format("%s (%s)", key_buffer, match.desc)
          elseif match.rhs and match.rhs ~= "" and match.rhs ~= "[Lua Function]" then
            label = string.format("%s (%s)", key_buffer, match.rhs:gsub("<[cC][mM][dD]>", ""):gsub("<[cC][rR]>", ""))
          end

          local raw_k = key_buffer
          key_buffer = ""
          vim.schedule(function()
            stats.record_command(label, "keymap", raw_k)
          end)
        elseif #key_buffer > 8 then
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
