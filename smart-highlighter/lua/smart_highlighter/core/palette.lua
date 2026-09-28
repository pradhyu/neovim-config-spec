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

  -- Tag-specific bookmark styles & highlight groups
M.TAG_STYLES = {
  FIXME = {
    canonical = "FIXME",
    label = "FIXME",
    icon = "🔥",
    color_dark = "#f38ba8",
    color_light = "#d73a49",
    bg_dark = "#3b2227",
    bg_light = "#ffeef0",
  },
  TODO = {
    canonical = "TODO",
    label = "TODO",
    icon = "📌",
    color_dark = "#89b4fa",
    color_light = "#0366d6",
    bg_dark = "#1e293b",
    bg_light = "#f0f6fc",
  },
  WARN = {
    canonical = "WARN",
    label = "WARN",
    icon = "⚠️",
    color_dark = "#fab387",
    color_light = "#d99b00",
    bg_dark = "#3b2d1d",
    bg_light = "#fff8e1",
  },
  NOTE = {
    canonical = "NOTE",
    label = "NOTE",
    icon = "📝",
    color_dark = "#a6e3a1",
    color_light = "#28a745",
    bg_dark = "#1c3326",
    bg_light = "#f0fff4",
  },
  HACK = {
    canonical = "HACK",
    label = "HACK",
    icon = "⚡",
    color_dark = "#cba6f7",
    color_light = "#6f42c1",
    bg_dark = "#2e1e3b",
    bg_light = "#fbf0ff",
  },
  GENERAL = {
    canonical = "GENERAL",
    label = "BOOKMARK",
    icon = "🔖",
    color_dark = "#e5c07b",
    color_light = "#b08800",
    bg_dark = "#2c313a",
    bg_light = "#eceff4",
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

  for tag, style in pairs(M.TAG_STYLES) do
    local fg = is_dark and style.color_dark or style.color_light
    local bg = is_dark and style.bg_dark or style.bg_light
    local badge_fg = is_dark and "#181825" or "#ffffff"

    vim.api.nvim_set_hl(0, "SmartBookmarkSign_" .. tag, { fg = fg, bold = true, default = true })
    vim.api.nvim_set_hl(0, "SmartBookmarkLine_" .. tag, { bg = bg, default = true })
    vim.api.nvim_set_hl(0, "SmartBookmarkVirt_" .. tag, { fg = fg, italic = true, bold = true, default = true })
    vim.api.nvim_set_hl(0, "SmartBookmarkBadge_" .. tag, { bg = fg, fg = badge_fg, bold = true, default = true })
  end

  -- Bookmark fallback highlight groups
  vim.api.nvim_set_hl(0, "SmartBookmarkSign", { link = "SmartBookmarkSign_GENERAL", default = true })
  vim.api.nvim_set_hl(0, "SmartBookmarkLine", { link = "SmartBookmarkLine_GENERAL", default = true })
  vim.api.nvim_set_hl(0, "SmartBookmarkVirtText", { link = "SmartBookmarkVirt_GENERAL", default = true })
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
