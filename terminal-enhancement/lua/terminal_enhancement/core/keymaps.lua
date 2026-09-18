local config = require("terminal_enhancement.config")
local link_resolver = require("terminal_enhancement.core.link_resolver")
local runner = require("terminal_enhancement.core.runner")

local M = {}

---Attach buffer-local keymaps to a newly opened terminal buffer
---@param buf integer
---@param win? integer
function M.attach_to_buffer(buf, win)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local is_float = win and vim.api.nvim_win_is_valid(win) and (vim.api.nvim_win_get_config(win).relative ~= "")
  local b_opts = { buffer = buf, silent = true, noremap = true }

  -- Press <CR> in normal mode on an error line / file path to jump directly to it
  vim.keymap.set("n", "<CR>", function()
    if not link_resolver.open() then
      vim.cmd("normal! <CR>")
    end
  end, b_opts)

  -- Quick-close handler for all terminal window types (float, horizontal split, vertical split)
  local function close_terminal_win()
    local target_win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(target_win) then
      local tab_wins = vim.api.nvim_tabpage_list_wins(0)
      local cfg = vim.api.nvim_win_get_config(target_win)
      if cfg.relative ~= "" or #tab_wins > 1 then
        pcall(vim.api.nvim_win_close, target_win, true)
      else
        vim.cmd("bprevious")
      end
    end
  end

  -- Normal mode: 'q' hides/closes the terminal window (split or float)
  vim.keymap.set("n", "q", close_terminal_win, b_opts)

  -- Terminal mode: <C-q> hides/closes the terminal window directly without needing normal mode
  vim.keymap.set("t", "<C-q>", function()
    close_terminal_win()
  end, b_opts)

  -- Floating window extra handler: '<Esc>' also closes
  if is_float then
    vim.keymap.set("n", "<Esc>", close_terminal_win, b_opts)
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

  -- Rename active or chosen terminal
  vim.keymap.set("n", "<leader>tr", function()
    require("terminal_enhancement.core.terminal").rename_interactive()
  end, { desc = "Rename terminal" })

  -- Open terminal as full regular buffer in current window
  vim.keymap.set("n", "<leader>tB", function()
    require("terminal_enhancement.core.terminal").open_as_buffer()
  end, { desc = "Open terminal as regular buffer" })

  -- Kill / Terminate terminal selector
  vim.keymap.set("n", "<leader>tk", function()
    require("terminal_enhancement.core.terminal").kill_interactive()
  end, { desc = "Kill / Terminate terminal" })

  -- Clean all hidden/background terminals
  vim.keymap.set("n", "<leader>tX", function()
    require("terminal_enhancement.core.terminal").kill_hidden()
  end, { desc = "Clean all hidden terminal buffers" })
end

return M
