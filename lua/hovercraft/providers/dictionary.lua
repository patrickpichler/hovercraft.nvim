local async = require('plenary.async')
local Job = require('plenary.job')

local M = {}

---@class Dictionary : Hovercraft.Provider
local Dictionary = {}

Dictionary.__index = Dictionary


function Dictionary:is_enabled()
  local word = vim.fn.expand('<cword>')

  return string.match(word, [[^[%a%d-_']+$]]) and #vim.spell.check(word) == 0
end

local function process(result)
  local ok, res = pcall(vim.json.decode, result)

  if not ok or not res or not res[1] then
    return
  end

  local json = res[1]

  ---@type string[]
  local lines = {
    json.word,
  }

  for _, def in ipairs(json.meanings[1].definitions) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = def.definition
    if def.example then
      lines[#lines + 1] = 'Example: ' .. def.example
    end
  end

  return lines
end

local cache = {} --- @type table<string,string[]>

Dictionary.execute = async.void(function(_, _, done)
  local word = vim.fn.expand('<cword>')

  if not cache[word] then
    Job:new({
      command = 'curl',
      args = { 'https://api.dictionaryapi.dev/api/v2/entries/en/' .. word },
      on_exit = function(j, return_value)
        if return_value ~= 0 then
          vim.schedule(function()
            done { lines = { 'no definition for ' .. word }, filetype = 'plaintext' }
          end)
          return
        end

        local output = j:result()
        local results = process(table.concat(output, ' ')) or { 'no definition for ' .. word }
        cache[word] = results

        vim.schedule(function()
          done { lines = cache[word], filetype = 'markdown' }
        end)
      end,
    }):start()
  else
    done { lines = cache[word], filetype = 'markdown' }
  end
end)

---@return Dictionary
function M.new()
  return setmetatable({}, Dictionary)
end

return M
