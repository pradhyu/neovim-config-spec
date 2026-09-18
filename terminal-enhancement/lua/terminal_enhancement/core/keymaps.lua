local config = require("terminal_enhancement.config")
local link_resolver = require("terminal_enhancement.core.link_resolver")
local runner = require("terminal_enhancement.core.runner")

local M = {}

---Attach buffer-local keymaps to a newly opened terminal buffer
---@param buf integer
---@param win integer
function M.attach_to_buffer(buf, win)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local is_float = vim.api.nvim_win_get_config(win).relative ~= ""
  local b_opts = { buffer = buf, silent = true, noremap = true }

  -- Press <CR> in normal mode on an error line / file path to jump directly to it
  vim.keymap.set("n", "<CR>", function()
    if not link_resolver.open() then
      vim.cmd("normal! <CR>")
    end
  end, b_opts)

  -- Floating terminal quick-close handlers
  if is_float then
    -- Normal mode: 'q' or '<Esc>' closes the floating window
    vim.keymap.set("n", "q", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, b_opts)

    vim.keymap.set("n", "<Esc>", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, b_opts)

    -- Terminal mode: <C-q> closes the floating window directly
    vim.keymap.set("t", "<C-q>", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, b_opts)
  end
end

---Setup global terminal navigation and smart link keybindings
function M.setup()
  local opts = config.options

  if opts.smart_navigation then
    -- Esc Esc in terminal mode exits to terminal normal mode
    vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode to normal mode" })

    -- Window navigation directly from terminal mode
    vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Navigate window left" })
    vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Navigate window down" })
    vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Navigate window up" })
    vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Navigate window right" })
  end

  if opts.smart_link_resolver then
    -- Smart gf and click handler across all buffers
    vim.keymap.set({ "n", "v" }, "gf", function()
      if not link_resolver.open() then
        vim.cmd("normal! gf")
      end
    end, { desc = "Smart Link / File / Line Resolver" })

    vim.keymap.set("n", "<C-LeftMouse>", function()
      link_resolver.open()
    end, { desc = "Smart Click Link / File Resolver" })
  end

  -- Send to terminal keymaps:
  -- Normal mode sends current line
  vim.keymap.set("n", "<leader>ts", function()
    runner.send_current_line()
  end, { desc = "Send current line to target terminal" })

  -- Visual mode sends highlighted lines
  vim.keymap.set("v", "<leader>ts", function()
    runner.send_selection()
  end, { desc = "Send visual selection to target terminal" })

  -- Change / Select default target terminal
  vim.keymap.set("n", "<leader>tc", function()
    runner.select_target()
  end, { desc = "Select / Change target terminal" })

  -- Open terminal as full regular buffer in current window
  vim.keymap.set("n", "<leader>tB", function()
    require("terminal_enhancement.core.terminal").open_as_buffer()
  end, { desc = "Open terminal as regular buffer" })
end

return M
