local scratchpad = require("buffer_buddy.core.scratchpad")

local M = {}

---Open interactive scratchpad launcher
function M.open()
  local items = {
    { ft = "markdown", label = "📝 Markdown Notes & Docs" },
    { ft = "lua",      label = "🌙 Lua Scratchpad & Snippets" },
    { ft = "sql",      label = "🗄️ SQL Query Scratchpad" },
    { ft = "json",     label = "📦 JSON Data Editor" },
    { ft = "sh",       label = "🐚 Bash / Shell Scripting" },
    { ft = "python",   label = "🐍 Python Scratchpad" },
  }

  vim.ui.select(items, {
    prompt = "Select Scratchpad Type:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end
    scratchpad.open_scratchpad(choice.ft, "float")
  end)
end

return M
