local M = {}

-- 16 Distinct high-visibility colors with dark & light theme palettes
M.PALETTES = {
  modern = {
    dark = {
      { bg = "#e06c75", fg = "#282c34", name = "Coral Red" },
      { bg = "#98c379", fg = "#282c34", name = "Mint Green" },
      { bg = "#e5c07b", fg = "#282c34", name = "Warm Yellow" },
      { bg = "#61afef", fg = "#282c34", name = "Sky Blue" },
      { bg = "#c678dd", fg = "#282c34", name = "Purple" },
      { bg = "#56b6c2", fg = "#282c34", name = "Teal Cyan" },
      { bg = "#d19a66", fg = "#282c34", name = "Amber Orange" },
      { bg = "#ff79c6", fg = "#282c34", name = "Pink Neon" },
      { bg = "#8be9fd", fg = "#282c34", name = "Electric Cyan" },
      { bg = "#50fa7b", fg = "#282c34", name = "Spring Green" },
      { bg = "#f1fa8c", fg = "#282c34", name = "Lemon Yellow" },
      { bg = "#bd93f9", fg = "#282c34", name = "Lavender" },
      { bg = "#ff5555", fg = "#282c34", name = "Crimson" },
      { bg = "#ffb86c", fg = "#282c34", name = "Tangerine" },
      { bg = "#00d2d3", fg = "#282c34", name = "Turquoise" },
      { bg = "#ff9ff3", fg = "#282c34", name = "Orchid" },
    },
    light = {
      { bg = "#d73a49", fg = "#ffffff", name = "Deep Crimson" },
      { bg = "#28a745", fg = "#ffffff", name = "Forest Green" },
      { bg = "#d99b00", fg = "#ffffff", name = "Dark Golden" },
      { bg = "#0366d6", fg = "#ffffff", name = "Cobalt Blue" },
      { bg = "#6f42c1", fg = "#ffffff", name = "Royal Purple" },
      { bg = "#0086b3", fg = "#ffffff", name = "Deep Teal" },
      { bg = "#d15700", fg = "#ffffff", name = "Burnt Orange" },
      { bg = "#ea4aaa", fg = "#ffffff", name = "Magenta" },
      { bg = "#059669", fg = "#ffffff", name = "Emerald" },
      { bg = "#2563eb", fg = "#ffffff", name = "Bright Blue" },
      { bg = "#7c3aed", fg = "#ffffff", name = "Violet" },
      { bg = "#db2777", fg = "#ffffff", name = "Rose" },
      { bg = "#ca8a04", fg = "#ffffff", name = "Mustard" },
      { bg = "#0d9488", fg = "#ffffff", name = "Dark Cyan" },
      { bg = "#4f46e5", fg = "#ffffff", name = "Indigo" },
      { bg = "#e11d48", fg = "#ffffff", name = "Ruby" },
    },
  },
}

---Initialize and define highlight groups in Neovim
function M.setup_highlights()
  local is_dark = vim.o.background ~= "light"
  local theme = M.PALETTES.modern[is_dark and "dark" or "light"]

  for idx, slot in ipairs(theme) do
    local group_name = string.format("SmartHighlightSlot%d", idx)
    vim.api.nvim_set_hl(0, group_name, {
      bg = slot.bg,
      fg = slot.fg,
      bold = true,
      default = false,
    })

    -- Subtle dimmed variant for secondary matches or non-active scopes
    local group_subtle = string.format("SmartHighlightSlotSubtle%d", idx)
    vim.api.nvim_set_hl(0, group_subtle, {
      underline = true,
      sp = slot.bg,
      bold = true,
      default = false,
    })
  end

  -- Generic UI highlight groups
  vim.api.nvim_set_hl(0, "SmartHighlightBorder", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "SmartHighlightHUDTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "SmartHighlightHUDHeader", { fg = "#61afef", bold = true, default = true })
  vim.api.nvim_set_hl(0, "SmartHighlightCount", { fg = "#98c379", bold = true, default = true })
  vim.api.nvim_set_hl(0, "SmartHighlightDisabled", { fg = "#5c6370", italic = true, default = true })
end

---Get color descriptor for a specific slot index
---@param slot_idx integer
---@return { bg: string, fg: string, name: string }
function M.get_slot_color(slot_idx)
  local is_dark = vim.o.background ~= "light"
  local theme = M.PALETTES.modern[is_dark and "dark" or "light"]
  local safe_idx = ((slot_idx - 1) % #theme) + 1
  return theme[safe_idx]
end

return M
