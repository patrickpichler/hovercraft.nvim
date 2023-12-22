local M = {
  _cache_to_clean = setmetatable({}, { __mode = 'v' })
}

---@class CacheLine
---@field time integer
---@field value any

---@class Cache
---@field _cache { [any]: CacheLine }
---@field _life_time integer
local Cache = {}
Cache.__index = Cache

---@param k any
---@param v? any
function Cache:put(k, v)
  self._cache[k] = {
    time = vim.loop.now(),
    value = v,
  }
end

---@param k any
---@return any?
function Cache:get(k)
  local line = self._cache[k]

  if self._life_time < 1 then
    return line and line.value
  end

  if line.time >= vim.loop.now() - self._life_time then
    return line.value
  end
end

function Cache:exists(k)
  local line = self._cache[k]

  if self._life_time < 1 then
    return line and true or false
  end

  if line.time >= vim.loop.now() - self._life_time then
    return true
  end

  return false
end

function Cache:get_or_load(k, fn)
  local line = self._cache[k]

  if not line then
    local item, store = fn(k)

    if store ~= false then
      self:put(k, item)
    end

    return item
  end

  if self._life_time < 1 then
    return line and line.value
  end

  if line.time >= vim.loop.now() - self._life_time then
    return line.value
  end
end

function Cache:prune_invalid()
  -- the cache should not invalidate items
  if self._life_time < 1 then
    return
  end

  local cutoff = vim.loop.now() - self._life_time

  for k, v in pairs(self._cache) do
    if v.time < cutoff then
      self._cache[k] = nil
    end
  end
end

---@param opts? {autoclean?: boolean, life_time_ms?: integer}
---@return Cache
function M.new(opts)
  opts = opts or {}

  local cache = setmetatable({
    _cache = setmetatable({}, { __mode = 'v' }),
    _life_time = opts.life_time_ms,
  }, Cache)

  if opts.life_time_ms > 0 and opts.autoclean ~= false then
    table.insert(M._cache_to_clean, cache)
  end

  return cache
end

-- caches get cleaned every 10 seconds, this should be enough
vim.fn.timer_start(10000, function()
  for _, c in ipairs(M._cache_to_clean) do
    c:prune_invalid()
  end
end, { ["repeat"] = -1 })

return M
