local async = require('plenary.async')
local M = {}

---@class Hovercraft.Providers
---@field _providers table<string, Hovercraft.RegisteredProvider>
---@field _sorted_providers? Hovercraft.RegisteredProvider[]
---@field _highest_priority number
local Providers = {}

--- @class Hovercraft.Provider.ExecuteOptions
--- @field bufnr integer
--- @field pos {[1]: integer, [2]: integer} tuple of [row, col]
--
--- @class Hovercraft.Provider.ExecuteResult
--- @field lines? string[]
--- @field filetype? string

---@alias Hovercraft.Provider.ExecuteFunction fun(self: Hovercraft.Provider, opts?: Hovercraft.Provider.ExecuteOptions, done: fun(result: Hovercraft.Provider.ExecuteResult))
---@alias Hovercraft.RegisteredProvider.ExecuteFunction fun(opts?: Hovercraft.Provider.ExecuteOptions): Hovercraft.Provider.ExecuteResult

---@class Hover.Provider.IsEnabledOpts
---@field bufnr integer
---@field pos {[1]: integer, [2]: integer}

---@class Hovercraft.RegisteredProvider
---@field id string
---@field title string
---@field priority number
---@field provider Hovercraft.Provider
---@field execute Hovercraft.RegisteredProvider.ExecuteFunction
---@field is_enabled fun(opts: Hover.Provider.IsEnabledOpts): boolean

---@class Hovercraft.Provider
---@field is_enabled fun(self: Hovercraft.Provider, opts: Hover.Provider.IsEnabledOpts): boolean
---@field execute Hovercraft.Provider.ExecuteFunction

---@alias Hovercraft.Provider.Function fun(opts: Hovercraft.Provider.ExecuteOptions, done: fun(result:Hovercraft.Provider.ExecuteResult))
---@alias Hovercraft.ProviderOrFunction Hovercraft.Provider | Hovercraft.Provider.Function

---@class Hovercraft.Providers.Options
---@field providers { [1]: string, [2]: Hovercraft.ProviderOrFunction, title?: string, priority?: number }[]
--
---@param f Hovercraft.Provider.Function
---@return Hovercraft.Provider
local function make_provider(f)
  return {
    is_enabled = function(_, _)
      return true
    end,
    execute = function(_, opts, done)
      return f(opts, done)
    end
  }
end

Providers.__index = Providers

---@param opts Hovercraft.Providers.Options
---@return Hovercraft.Providers
function M.new(opts)
  opts = opts or {}

  ---@type Hovercraft.Providers
  local obj = setmetatable({
    _providers = {},
    _highest_priority = 1000,
  }, Providers)

  for i, p in ipairs(opts.providers) do
    -- TODO: figure out if this is nice to use or not
    local priority = p.priority or (90000 + (i * 10))

    obj:register(p[1], p.title or p[1], p[2], priority)
  end

  return obj
end

---@param id string
---@param title string
---@param provider Hovercraft.ProviderOrFunction
---@param priority? number
function Providers:register(id, title, provider, priority)
  local p

  if type(provider) == 'function' then
    p = make_provider(provider)
  else
    p = provider
  end

  ---@type Hovercraft.RegisteredProvider
  local registerd_provider = {
    id = id,
    title = title,
    priority = priority or (self._highest_priority + 10),
    provider = p,
    execute = async.wrap(function(opts, done)
      return p:execute(opts, done)
    end, 2),
    is_enabled = function(opts)
      return p:is_enabled(opts)
    end
  }

  -- we need to reset the sorted providers, since we add a new provider
  self._sorted_providers = nil

  if self._highest_priority < registerd_provider.priority then
    self._highest_priority = registerd_provider.priority
  end

  self._providers[id] = registerd_provider
end

---@param a Hovercraft.RegisteredProvider
---@param b Hovercraft.RegisteredProvider
---@return boolean
local function _cmp_providers(a, b)
  if a.priority == b.priority then
    return a.title < b.title
  end

  return a.priority < b.priority
end

---@param providers table<string, Hovercraft.RegisteredProvider>
---@return Hovercraft.RegisteredProvider[]
function M._to_sorted_providers(providers)
  local result = {}

  for _, p in pairs(providers) do
    table.insert(result, p)
  end

  table.sort(result, _cmp_providers)

  return result
end

---@return Hovercraft.RegisteredProvider[]
function Providers:get_providers()
  if self._sorted_providers then
    return self._sorted_providers
  end

  return M._to_sorted_providers(self._providers)
end

---@param id string
---@return Hovercraft.RegisteredProvider?
function Providers:get_provider(id)
  return self._providers[id]
end

return M
