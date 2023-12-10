local UI = require('hovercraft.ui')

local eq = assert.are.same

---@param num integer number of dummy providers to create
---@return string[]
local function make_dummy_provider_ids(num)
  ---@type string[]
  local result = {}

  for i = 1, num do
    table.insert(result, string.format('provider-%d', i))
  end

  return result
end

describe('hovercraft', function()
  describe('hovercraft.ui._get_next_provider_id', function()
    it('simple step forward', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, 1, true)

      eq(providers[2], next_provider_id)
    end)

    it('step multiple forward', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, 3, true)

      eq(providers[4], next_provider_id)
    end)

    it('step forward over bounds with cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[10]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, 1, true)

      eq(providers[1], next_provider_id)
    end)

    it('step forward over bounds without cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[10]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, 1, false)

      eq(providers[10], next_provider_id)
    end)

    it('simple step backwards', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[2]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -1, true)

      eq(providers[1], next_provider_id)
    end)

    it('step multiple backwards', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[4]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -3, true)

      eq(providers[1], next_provider_id)
    end)

    it('step backwards over bounds with cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -1, true)

      eq(providers[10], next_provider_id)
    end)

    it('step backwards over bounds without cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -1, false)

      eq(providers[1], next_provider_id)
    end)

    it('step multiple backwards over bounds with cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -3, true)

      eq(providers[8], next_provider_id)
    end)

    it('step backwards over bounds without cycle', function()
      local providers = make_dummy_provider_ids(10)
      local current_provider_id = providers[1]

      local next_provider_id = UI._get_next_provider_id(providers, current_provider_id, -4, false)

      eq(providers[1], next_provider_id)
    end)
  end)
end)
