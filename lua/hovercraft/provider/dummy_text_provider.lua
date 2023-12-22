local M = {}

---@class DummyTextProvider : Hovercraft.Provider
---@field lines string[]
---@field filetype string
local Provider = {}

Provider.__index = Provider

function Provider:is_enabled()
  return true
end

function Provider:execute(_, done)
  done({ lines = self.lines, filetype = self.filetype })
end

---@param lines string[]
---@param filetype? string
---@return DummyTextProvider
function M.new(lines, filetype)
  filetype = filetype or 'markdown'

  return setmetatable({ ---@as DummyTextProvider
    lines = lines,
    filetype = filetype
  }, Provider)
end

return M
