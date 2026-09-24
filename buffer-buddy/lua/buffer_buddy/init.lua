local config = require("buffer_buddy.config")
local hygiene = require("buffer_buddy.core.hygiene")
local pin = require("buffer_buddy.core.pin")
local transforms = require("buffer_buddy.core.transforms")
local snapshot = require("buffer_buddy.core.snapshot")
local diff = require("buffer_buddy.core.diff")
local inspector = require("buffer_buddy.core.inspector")
local scratchpad = require("buffer_buddy.core.scratchpad")
local hud = require("buffer_buddy.ui.hud")
local scratch_picker = require("buffer_buddy.ui.scratch_picker")
local statusline = require("buffer_buddy.ui.statusline")

local M = {}

---Setup buffer-buddy plugin
---@param user_opts? table
function M.setup(user_opts)
  config.setup(user_opts)

  -- Optional auto-trim whitespace on save
  if config.options.trim_whitespace_on_save then
    local group = vim.api.nvim_create_augroup("BufferBuddyAutoTrim", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      callback = function(args)
        if vim.bo[args.buf].buftype == "" then
          transforms.trim_whitespace(args.buf)
        end
      end,
    })
  end

  -- Optional auto-clean unmodified buffers on VimLeavePre
  if config.options.auto_clean_on_exit then
    local group = vim.api.nvim_create_augroup("BufferBuddyAutoClean", { clear = true })
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      callback = function()
        hygiene.close_unmodified()
      end,
    })
  end
end

-- Pin APIs
M.pin = pin.pin
M.unpin = pin.unpin
M.toggle_pin = pin.toggle_pin
M.is_pinned = pin.is_pinned
M.get_pinned_buffers = pin.get_pinned_buffers

-- Hygiene APIs
M.close_unmodified = hygiene.close_unmodified
M.close_hidden = hygiene.close_hidden
M.close_others = hygiene.close_others
M.close_dead = hygiene.close_dead
M.close_current = function() hygiene.close_buffer_safely(vim.api.nvim_get_current_buf(), false) end

-- Transform APIs
M.trim_whitespace = transforms.trim_whitespace
M.json_format = transforms.json_format
M.json_minify = transforms.json_minify
M.base64_encode = transforms.base64_encode
M.base64_decode = transforms.base64_decode
M.url_encode = transforms.url_encode
M.url_decode = transforms.url_decode
M.dedup_lines = transforms.dedup_lines
M.sort_lines = transforms.sort_lines
M.format_markdown_table = transforms.format_markdown_table

-- Diff APIs
M.diff_disk = diff.diff_disk
M.diff_clipboard = diff.diff_clipboard

-- Snapshot APIs
M.create_snapshot = snapshot.create_snapshot
M.restore_snapshot = snapshot.restore_snapshot
M.select_snapshot = snapshot.select_snapshot_interactive
M.get_snapshots = snapshot.get_snapshots

-- Scratchpad APIs
M.open_scratchpad = scratchpad.open_scratchpad
M.select_scratchpad = scratch_picker.open

-- Inspector & UI
M.get_info = inspector.get_info
M.open_hud = hud.open
M.statusline = statusline.get

return M
