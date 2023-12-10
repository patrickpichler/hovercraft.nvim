local Dict = require('hovercraft.providers.dictionary')
local Man = require('hovercraft.providers.man')
local Lsp = require('hovercraft.providers.lsp')

local M = {}

---@class Hovercraft.Config
---@field providers? Hovercraft.Providers.Options
---@field window? Hovercraft.UI.Options
---@field keys? Hovercraft.KeyMap.Options.KeySpec[]
local defaults = {
  providers = {
    providers = {
      {
        'LSP',
        Lsp.new(),
      },
      {
        'Man',
        Man.new(),
      },
      {
        'Dictionary',
        Dict.new(),
      },
    }
  },

  window = {
    border = 'single',
  },

  keys = {
    { '<C-u>',   function() require('hovercraft').scroll({ delta = -4 }) end },
    { '<C-d>',   function() require('hovercraft').scroll({ delta = 4 }) end },
    { '<TAB>',   function() require('hovercraft').hover_next() end },
    { '<S-TAB>', function() require('hovercraft').hover_next({ step = -1 }) end },
  }
}

---@param opts? Hovercraft.Config
---@return Hovercraft.Config
function M.new(opts)
  opts = opts or {}
  return vim.tbl_deep_extend('force', defaults, opts)
end

return M
