local Instance = require('hovercraft.instance')

---@type Hovercraft.Instance
local instance

---@type boolean
local setup_done = false

local function setup(opts)
  instance = Instance.new(opts)
  setup_done = true
end

local the_hovercraft = setmetatable({}, {
  __index = function(t, k)
    if not setup_done then
      setup({})
    end

    local result = instance[k]

    if type(result) == 'function' then
      return function(...)
        local args = { ... }

        if args[1] == t then
          args[1] = instance
        else
          table.insert(args, 1, instance)
        end

        return result(table.unpack(args))
      end
    end

    return result
  end,

  __new_index = function()
    error('cannot set values on hovercraft')
  end,
})

---@param opts? Hovercraft.Config
function the_hovercraft.setup(opts)
  setup(opts)
end

return the_hovercraft
