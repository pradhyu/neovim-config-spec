local stats = require("cmd_cockpit.core.stats")
local keymaps = require("cmd_cockpit.core.keymaps")
local overrides = require("cmd_cockpit.core.overrides")
local remap_modal = require("cmd_cockpit.ui.remap_modal")

local M = {}

---Open the main Command & Keymap Cockpit Hub
---@param initial_tab? integer (1 = Frequent Commands, 2 = Keymaps, 3 = Overrides)
function M.open(initial_tab)
  local active_tab = initial_tab or 1
  local mode_filter = "n"
  local search_query = ""

  local width = 84
  local height = 24
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui and ui.width or 90
  local win_height = ui and ui.height or 30
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "cmdcockpit_hud"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 🚀 Neovim Command Cockpit & Keymap Hub ",
    title_pos = "center",
  })

  local current_items = {}

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    current_items = {}

    local tab1_badge = (active_tab == 1) and "▶ ⚡ Frequent Commands ◀" or "  ⚡ Frequent Commands  "
    local tab2_badge = (active_tab == 2) and "▶ 🗺️ Keymap Explorer ◀"  or "  🗺️ Keymap Explorer  "
    local tab3_badge = (active_tab == 3) and "▶ ⚙️ Overrides ◀"        or "  ⚙️ Overrides  "

    local lines = {}
    table.insert(lines, string.format(" %s | %s | %s", tab1_badge, tab2_badge, tab3_badge))
    table.insert(lines, " " .. string.rep("─", width - 4))

    if active_tab == 1 then
      -- TAB 1: Frequent Commands
      local top_cmds = stats.get_top_commands(20)
      current_items = top_cmds

      if #top_cmds == 0 then
        table.insert(lines, "")
        table.insert(lines, "   [ No commands tracked yet. Execute ':' commands in Neovim to populate ]")
        table.insert(lines, "")
      else
        table.insert(lines, "   KEY  PIN  USES  COMMAND                                  LAST RUN")
        table.insert(lines, "   " .. string.rep("─", width - 6))

        for idx, rec in ipairs(top_cmds) do
          local pin_icon = rec.pinned and "📌" or "  "
          local num_badge = (idx <= 9) and string.format("[%d]", idx) or string.format("#%-2d", idx)
          local cmd_str = rec.cmd
          if #cmd_str > 40 then
            cmd_str = cmd_str:sub(1, 37) .. "..."
          end

          local delta_min = math.floor((os.time() - rec.last_used) / 60)
          local time_str = (delta_min < 60) and (delta_min .. "m ago") or (math.floor(delta_min / 60) .. "h ago")

          local line = string.format("  %-4s %s  %-5d %-40s %s", num_badge, pin_icon, rec.count, cmd_str, time_str)
          table.insert(lines, line)
        end
      end

      table.insert(lines, " " .. string.rep("─", width - 4))
      table.insert(lines, "  1-9 Run Fast | <CR> Run | p Pin | d Delete | <Tab>/H/L Switch Tab | q Close")

    elseif active_tab == 2 then
      -- TAB 2: Keymap Explorer
      local all_maps = keymaps.search_keymaps(search_query, mode_filter ~= "all" and mode_filter or nil)
      current_items = all_maps

      local filter_info = string.format("Mode: [%s] | Search: '%s' (%d found)", mode_filter:upper(), search_query ~= "" and search_query or "all", #all_maps)
      table.insert(lines, "  " .. filter_info)
      table.insert(lines, "  MODE  LHS                 RHS / ACTION                    DESCRIPTION")
      table.insert(lines, "  " .. string.rep("─", width - 6))

      local display_count = math.min(#all_maps, 16)
      if display_count == 0 then
        table.insert(lines, "")
        table.insert(lines, "   [ No matching keymaps found for current filter ]")
        table.insert(lines, "")
      else
        for i = 1, display_count do
          local map = all_maps[i]
          local lhs = map.lhs:gsub("<leader>", "<L>")
          if #lhs > 18 then lhs = lhs:sub(1, 15) .. "..." end

          local rhs = map.rhs ~= "" and map.rhs or "[Callback]"
          if #rhs > 30 then rhs = rhs:sub(1, 27) .. "..." end

          local desc = map.desc ~= "" and map.desc or ""
          if #desc > 20 then desc = desc:sub(1, 17) .. "..." end

          local line = string.format("  [%s]   %-19s %-31s %s", map.mode, lhs, rhs, desc)
          table.insert(lines, line)
        end
      end

      table.insert(lines, " " .. string.rep("─", width - 4))
      table.insert(lines, "  r Remap | m Mode | / Search | Tab Switch | E Export Lua | q Close")

    else
      -- TAB 3: Active Overrides
      local ov_list = {}
      for _, ov in pairs(overrides.overrides) do
        table.insert(ov_list, ov)
      end
      current_items = ov_list

      table.insert(lines, "   ACTIVE RUNTIME KEYMAP OVERRIDES:")
      table.insert(lines, "   " .. string.rep("─", width - 6))

      if #ov_list == 0 then
        table.insert(lines, "")
        table.insert(lines, "   [ No custom keymap overrides set yet. Press 'r' in Tab 2 to create one ]")
        table.insert(lines, "")
      else
        for _, ov in ipairs(ov_list) do
          local line = string.format("   [%s] '%s' ➔ '%s'  (%s)", ov.mode, ov.old_lhs, ov.new_lhs, ov.desc ~= "" and ov.desc or ov.rhs)
          table.insert(lines, line)
        end
      end

      table.insert(lines, " " .. string.rep("─", width - 4))
      table.insert(lines, "  d Delete Override | R Reset All | E Export Lua File | Tab Switch | q Close")
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Syntax highlights
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1)
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function execute_current()
    if active_tab == 1 then
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx = cursor[1] - 3
      if idx >= 1 and idx <= #current_items then
        local target = current_items[idx]
        close()
        vim.notify("[CmdCockpit] ⚡ Executing: :" .. target.cmd, vim.log.levels.INFO)
        vim.cmd(target.cmd)
      end
    end
  end

  local function run_number(n)
    if active_tab == 1 and current_items[n] then
      local target = current_items[n]
      close()
      vim.notify("[CmdCockpit] ⚡ Executing: :" .. target.cmd, vim.log.levels.INFO)
      vim.cmd(target.cmd)
    end
  end

  local function remap_action()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local idx = cursor[1] - 3
    local entry = (active_tab == 2 and current_items[idx]) or nil
    remap_modal.open(entry, function()
      render()
    end)
  end

  render()
  vim.api.nvim_win_set_cursor(win, { 4, 2 })

  local k_opts = { buffer = buf, silent = true, noremap = true }

  -- Tab switching (<Tab>, <S-Tab>, H, L, [, ])
  vim.keymap.set("n", "<Tab>", function() active_tab = (active_tab % 3) + 1; render() end, k_opts)
  vim.keymap.set("n", "<S-Tab>", function() active_tab = (active_tab == 1) and 3 or (active_tab - 1); render() end, k_opts)
  vim.keymap.set("n", "H", function() active_tab = (active_tab == 1) and 3 or (active_tab - 1); render() end, k_opts)
  vim.keymap.set("n", "L", function() active_tab = (active_tab % 3) + 1; render() end, k_opts)
  vim.keymap.set("n", "[", function() active_tab = (active_tab == 1) and 3 or (active_tab - 1); render() end, k_opts)
  vim.keymap.set("n", "]", function() active_tab = (active_tab % 3) + 1; render() end, k_opts)

  -- Fast numeric command execution (1..9) in Tab 1
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      if active_tab == 1 then
        run_number(i)
      end
    end, k_opts)
  end

  -- Execution / Actions
  vim.keymap.set("n", "<CR>", execute_current, k_opts)
  vim.keymap.set("n", "<Space>", execute_current, k_opts)
  vim.keymap.set("n", "r", remap_action, k_opts)
  vim.keymap.set("n", "p", function()
    if active_tab == 1 then
      local cursor = vim.api.nvim_win_get_cursor(win)
      local idx = cursor[1] - 3
      if current_items[idx] then
        stats.toggle_pin(current_items[idx].cmd)
        render()
      end
    end
  end, k_opts)

  vim.keymap.set("n", "m", function()
    if active_tab == 2 then
      local modes = { "n", "v", "i", "t", "all" }
      local next_idx = 1
      for i, m in ipairs(modes) do
        if m == mode_filter then next_idx = (i % #modes) + 1 break end
      end
      mode_filter = modes[next_idx]
      render()
    end
  end, k_opts)

  vim.keymap.set("n", "/", function()
    vim.ui.input({ prompt = "Search Keymaps: " }, function(input)
      search_query = input or ""
      active_tab = 2
      render()
    end)
  end, k_opts)

  vim.keymap.set("n", "E", function()
    local ok, msg = overrides.export_lua()
    vim.notify("[CmdCockpit] " .. msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
  end, k_opts)

  vim.keymap.set("n", "R", function()
    overrides.reset_all()
    render()
    vim.notify("[CmdCockpit] 🔄 Reset all keymap overrides to defaults", vim.log.levels.INFO)
  end, k_opts)

  vim.keymap.set("n", "d", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local idx = cursor[1] - 3
    if active_tab == 1 and current_items[idx] then
      stats.records[current_items[idx].cmd] = nil
      stats.save()
      render()
    elseif active_tab == 3 and current_items[idx] then
      overrides.remove_override(current_items[idx].mode, current_items[idx].new_lhs)
      render()
    end
  end, k_opts)

  vim.keymap.set("n", "q", close, k_opts)
  vim.keymap.set("n", "<Esc>", close, k_opts)
end

return M
