local M = {}

---@alias Hovercraft.KeyMap.ArmedState.MappingTable { [string[]]: Hovercraft.KeyMap.KeyMapping } mappings that have been replaced by hovercraft. the key is a tuple of mode and lhs

---@class Hovercraft.KeyMap.ArmedState
---@field mappings Hovercraft.KeyMap.ArmedState.MappingTable

---@class Hovercraft.KeyMap
---@field mappings { [string]: Hovercraft.KeyMap.Options.KeySpec }
---@field armed_state? Hovercraft.KeyMap.ArmedState
local KeyMap = {}

KeyMap.__index = KeyMap

-- normalize_key takes the lhs of a key mapping and converts it into a normalized
-- form. Without normailzation, <C-e> and <c-e> would be two different mappings.
-- Normilazation transfroms both of them into <C-E>. Note keycodes are note case
-- sensitive, so <C-E> is equivalent to <C-e>.
--
---@param key string raw lhs key from mapping
---@return string key in normalized form
function M._normalize_key(key)
  vim.validate {
    key = { key, 'string' }
  }

  -- i am not 100% sure if this will work out in all cases though, but i
  -- have yet to see it break
  local internal = vim.api.nvim_replace_termcodes(key, true, true, true)

  -- keytrans is the inverse of nvim_replace_termcodes
  return vim.fn.keytrans(internal)
end

---@class Hovercraft.KeyMap.Options.KeySpec
---@field [1] string lhs
---@field [2] (string|fun()) rhs
---@field modes? (string|string[])
---@field opts? Hovercraft.KeyMap.KeyOptions

-- Mapping of the key as provided from the nvim keymap
---@class Hovercraft.KeyMap.KeyMapping : Hovercraft.KeyMap.KeyOptions
---@field lhs string
---@field rhs string

---@class Hovercraft.KeyMap.KeyOptions
---@field expr boolean
---@field callback? any
---@field desc? string
---@field noremap boolean
---@field script boolean
---@field silent boolean
---@field nowait boolean
---@field buffer boolean
---@field replace_keycodes boolean

---@param mappings Hovercraft.KeyMap.Options.KeySpec[]
---@return { [string]: Hovercraft.KeyMap.Options.KeySpec }
function M._to_keymap(mappings)
  local result = {}

  for _, m in ipairs(mappings) do
    local key = M._normalize_key(m[1])

    result[key] = m
  end

  return result
end

---@param keys Hovercraft.KeyMap.Options.KeySpec[]
---@return Hovercraft.KeyMap
function M.new(keys)
  keys = keys or {}

  local keymap = { ---@type Hovercraft.KeyMap
    mappings = M._to_keymap(keys),
  }

  return setmetatable(keymap, KeyMap)
end

function KeyMap:add_mappings(mappings)
  local override = M._to_keymap(mappings)

  self.mappings = vim.tbl_extend('force', self.mappings, override)
end

local function keys_equals(k1, k2)
  return M._normalize_key(k1) == M._normalize_key(k2)
end

-- gets the keymapping from the active buffer. This method takes heavy inspiration
-- from how it is implemented in nvim-cmp (so kudos to them!).
--
---@param mode string
---@param lhs string
---@return Hovercraft.KeyMap.KeyMapping?
local function get_map(mode, lhs)
  lhs = M._normalize_key(lhs)

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keys_equals(map.lhs, lhs) then
      return { ---@type Hovercraft.KeyMap.KeyMapping
        lhs = map.lhs,
        rhs = map.rhs or '',
        expr = map.expr == 1,
        callback = map.callback,
        desc = map.desc,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = true,
        replace_keycodes = map.replace_keycodes == 1,
      }
    end
  end
end

-- Set keymapping
-- Once again copied over from the nvim-cmp project
---@param mode string
---@param lhs string
---@param rhs any
---@param opts Hovercraft.KeyMap.KeyOptions
local function set_map(bufnr, mode, lhs, rhs, opts)
  opts = opts or {}

  if type(rhs) == 'function' then
    opts.callback = rhs
    rhs = ''
  end

  opts.desc = 'hovercraft.keymap.set_map'

  if vim.fn.has('nvim-0.8') == 0 then
    opts.replace_keycodes = nil
  end

  vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
end

---@param bufnr number
function KeyMap:arm(bufnr)
  ---@type Hovercraft.KeyMap.ArmedState.MappingTable
  local active_mappings = {}

  for _, mapping in pairs(self.mappings) do
    local modes = type(mapping.modes) == 'table' and mapping.modes or { mapping.modes or 'n' }
    local lhs = mapping[1]
    local rhs = mapping[2]

    for _, mode in ipairs(modes --[[@as string[] ]]) do
      local active_mapping = get_map(mode, lhs)

      if active_mapping then
        local key = { mode, lhs }
        active_mappings[key] = active_mapping
      end

      set_map(bufnr, mode, lhs, rhs, mapping.opts)
    end
  end

  self.armed_state = {
    mappings = active_mappings,
  }
end

---@param bufnr number
function KeyMap:disarm(bufnr)
  if not self.armed_state or not vim.api.nvim_buf_is_valid(bufnr) then
    -- if no armed state is set or the given bufnr is not valid anymore,
    -- we are not active and have nothing to do
    return
  end

  local armed_state = self.armed_state
  ---@cast armed_state Hovercraft.KeyMap.ArmedState was checked for nil explicitly before

  for _, mapping in pairs(self.mappings) do
    local modes = type(mapping.modes) == 'table' and mapping.modes or { mapping.modes or 'n' }
    local lhs = mapping[1]

    for _, mode in ipairs(modes --[[@as string[] ]]) do
      local original_mapping = armed_state.mappings[{ mode, lhs }]

      if original_mapping then
        set_map(bufnr, mode, lhs, original_mapping.rhs, original_mapping)
      else
        vim.api.nvim_buf_del_keymap(bufnr, mode, lhs)
      end
    end
  end

  self.armed_state = nil
end

return M
