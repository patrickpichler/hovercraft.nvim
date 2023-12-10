local Config = require('hovercraft.config')
local Providers = require('hovercraft.providers')
local UI = require('hovercraft.ui')
local KeyMap = require('hovercraft.keymap')

local M = {}

---@class Hovercraft.Instance
---@field config Hovercraft.Config
---@field ui Hovercraft.UI
---@field providers Hovercraft.Providers
---@field keymap Hovercraft.KeyMap

---@class Hovercraft.Instance
local Hovercraft = {}

Hovercraft.__index = Hovercraft

---@param id string
---@param provider Hovercraft.Provider
---@param opts {title?: string, priority?: number}
function Hovercraft:register(id, provider, opts)
  opts = opts or {}

  self.providers:register(id, opts.title or id, provider, opts.priority)
end

---@param opts? Hovercraft.UI.ShowOpts
function Hovercraft:hover(opts)
  self.ui:show(opts)
end

---@param opts Hovercraft.UI.ShowNextOpts
function Hovercraft:hover_next(opts)
  self.ui:show_next(opts)
end

function Hovercraft:hover_select()
  self.ui:show_select()
end

function Hovercraft:close()
  self.ui:hide()
end

---@param mappings Hovercraft.KeyMap.KeyMapping[]
function Hovercraft:add_keys(mappings)
  self.keymap:add_mappings(mappings)
end

function Hovercraft:scroll(opts)
  self.ui:scroll(opts)
end

function Hovercraft:is_visible()
  return self.ui:is_visible()
end

function Hovercraft:enter_popup()
  return self.ui:enter_popup()
end

---@param opts? Hovercraft.Config
---@return Hovercraft.Instance
function M.new(opts)
  local config = Config.new(opts)
  local providers = Providers.new(config.providers)
  local keymap = KeyMap.new(config.keys)
  local ui = UI.new(
    providers,
    config.window
  )

  ui:register_onshow(function(bufnr)
    keymap:arm(bufnr)
  end)

  ui:register_onhide(function(bufnr)
    keymap:disarm(bufnr)
  end)

  local instance = setmetatable({
    config = config,
    providers = providers,
    ui = ui,
    keymap = keymap,
  }, Hovercraft)

  return instance
end

return M
