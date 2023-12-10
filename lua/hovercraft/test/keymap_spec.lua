local KeyMap = require('hovercraft.keymap')

local eq = assert.are.same

describe('KeyMap', function()
  describe('_normalize_keys', function()
    it('should not change lowercase key mappings', function()
      local normalized = KeyMap._normalize_key('abc')

      eq('abc', normalized)
    end)

    it('should not care about case in key sequence', function()
      local normalized = KeyMap._normalize_key('<C-e>abc')
      local normalized2 = KeyMap._normalize_key('<C-E>abc')

      eq(normalized2, normalized)
    end)

    it('should also handle CR', function()
      local normalized = KeyMap._normalize_key('<C-e>abc<CR>')
      local normalized2 = KeyMap._normalize_key('<C-E>abc<CR>')

      eq(normalized2, normalized)
    end)
  end)

  describe('_to_keymap', function()
    it('should transform simple mappings', function()
      local key = { 'l', ':hi' }

      local result = KeyMap._to_keymap({ key })

      eq({ ['l'] = key }, result)
    end)

    it('should deduplicate', function()
      local key1 = { 'l', ':hi' }
      local key2 = { 'l', ':ho' }

      local result = KeyMap._to_keymap({ key1, key2 })

      eq({ ['l'] = key2 }, result)
    end)
  end)
end)
