-- Huge thanks to lewis6991, as this provider took huge inspiration (it is
-- pretty much copied over) from his in hover.nvim

local util = require('hovercraft.provider.lsp.util')

local M = {}

---@class Hovercraft.Provider.Lsp.Hover : Hovercraft.Provider
local Lsp = {}

Lsp.__index = Lsp

function Lsp:is_enabled(opts)
  local bufnr = opts.bufnr

  for _, client in pairs(util.get_clients()) do
    if client.supports_method('textDocument/hover', { bufnr = bufnr }) then
      return true
    end
  end
  return false
end

function Lsp:execute(opts, done)
  local clients = util.get_clients({ bufnr = opts.bufnr })

  if #clients == 0 then
    done()
    return
  end

  local row, col = opts.pos[1] - 1, opts.pos[2]

  util.buf_request_all(
    opts.bufnr,
    'textDocument/hover',
    util.create_params(opts.bufnr, row, col),
    function(results)
      for _, result in pairs(results or {}) do
        if result.contents then
          local lines = result.contents
          if type(lines) == 'string' then
            done { lines = {lines}, filetype = 'markdown' }
            return
          elseif not vim.tbl_isempty(lines) then
            done { lines = lines, filetype = 'markdown' }
            return
          end
        end
      end
      -- no results
      done()
    end,
    clients
  )
end

---@return Hovercraft.Provider.Lsp.Hover
function M.new()
  return setmetatable({}, Lsp)
end

return M
