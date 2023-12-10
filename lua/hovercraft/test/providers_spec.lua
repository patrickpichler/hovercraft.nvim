local Providers = require('hovercraft.providers')

local eq = assert.are.same

---@return Hovercraft.RegisteredProvider
local function make_test_provider(id, priority, opts)
  opts = opts or {}

  local provider = {
    is_enabled = function() return true end,
    execute = function(_, _, done)
      done({})
    end,
  }

  return { --[[@type Hovercraft.RegisteredProvider]]
    id = id,
    title = opts.title or id,
    priority = priority,
    provider = provider,
    execute = function()
      return {}
    end,
    is_enabled = function()
      return true
    end
  }
end

---@param ... Hovercraft.RegisteredProvider
---@return table<string, Hovercraft.RegisteredProvider>
local function to_provider_map(...)
  local result = {}

  for _, p in ipairs({ ... }) do
    result[p.id] = p
  end

  return result
end

describe('Providers', function()
  describe('_to_sorted_providers', function()
    it('should sort based on priority', function()
      local p1 = make_test_provider('1', 200)
      local p2 = make_test_provider('2', 100)
      local p3 = make_test_provider('3', 500)

      local sorted = Providers._to_sorted_providers(to_provider_map(p1, p2, p3))

      eq({ p2, p1, p3 }, sorted)
    end)

    it('should sort based on priority or name if priority match', function()
      local p1 = make_test_provider('test', 200)
      local p2 = make_test_provider('bllo', 100)
      local p3 = make_test_provider('allo', 100)

      local sorted = Providers._to_sorted_providers(to_provider_map(p1, p2, p3))

      eq({ p3, p2, p1 }, sorted)
    end)
  end)
end)
