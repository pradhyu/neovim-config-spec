local config = require("smart_highlighter.config")
local engine = require("smart_highlighter.core.engine")
local navigation = require("smart_highlighter.core.navigation")
local presets = require("smart_highlighter.core.presets")
local session = require("smart_highlighter.core.session")
local hud = require("smart_highlighter.ui.hud")
local picker = require("smart_highlighter.ui.picker")
local statusline = require("smart_highlighter.ui.statusline")

local M = {}

---Setup smart-highlighter plugin with user configuration
---@param user_opts? table
function M.setup(user_opts)
  config.setup(user_opts)
  engine.init()

  -- Auto filetype presets if enabled
  if config.options.presets.enabled and config.options.presets.auto_by_filetype then
    local group = vim.api.nvim_create_augroup("SmartHighlighterAutoPresets", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local preset_name = config.options.presets.filetype_map[ft]
        if preset_name then
          presets.load_preset(preset_name, false)
        end
      end,
    })
  end

  -- Reconcile highlights on TextChanged / BufEnter with debouncing
  local render_group = vim.api.nvim_create_augroup("SmartHighlighterRender", { clear = true })
  local timer = nil

  local function debounced_render(buf)
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.loop.new_timer()
    timer:start(config.options.debounce_ms or 80, 0, vim.schedule_wrap(function()
      if vim.api.nvim_buf_is_valid(buf) then
        engine.render_buffer(buf)
      end
    end))
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
    group = render_group,
    callback = function(args)
      debounced_render(args.buf)
    end,
  })

  -- Auto-restore session on startup if enabled
  if config.options.persistence then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = render_group,
      once = true,
      callback = function()
        session.load_session()
      end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = render_group,
      callback = function()
        session.save_session()
      end,
    })
  end
end

-- Forward Core APIs
M.toggle = engine.toggle_word
M.add_pattern = engine.add_slot
M.remove_slot = engine.remove_slot
M.toggle_slot = engine.toggle_slot
M.clear_all = engine.clear_all
M.get_slots = function() return engine.slots end

-- Forward Navigation APIs
M.jump_next = navigation.jump_next
M.jump_prev = navigation.jump_prev
M.jump_any_next = function() navigation.jump_any(true) end
M.jump_any_prev = function() navigation.jump_any(false) end

-- Forward Preset APIs
M.load_preset = presets.load_preset
M.select_preset = presets.select_preset_interactive

-- Forward Persistence APIs
M.save_session = session.save_session
M.load_session = session.load_session

-- Forward UI APIs
M.open_hud = hud.open
M.export_quickfix = picker.export_to_quickfix
M.search_matches = picker.telescope_picker
M.statusline = statusline.get

---Prompt for custom regex to highlight
function M.add_regex_interactive()
  vim.ui.input({ prompt = "SmartHighlight Regex: " }, function(input)
    if input and input ~= "" then
      local id = engine.add_slot(input, { is_regex = true, whole_word = false, name = input })
      vim.notify(string.format("[SmartHighlight] Added regex to slot #%d: '%s'", id, input), vim.log.levels.INFO)
    end
  end)
end

---Toggle treesitter enclosing scope highlight for word under cursor
function M.toggle_scope()
  local id, action = engine.toggle_word(nil, true)
  if id and action == "added" then
    vim.notify(string.format("[SmartHighlight] Highlighted symbol within Treesitter scope (Slot #%d)", id), vim.log.levels.INFO)
  elseif id and action == "removed" then
    vim.notify(string.format("[SmartHighlight] Removed scope highlight (Slot #%d)", id), vim.log.levels.INFO)
  end
end

return M
