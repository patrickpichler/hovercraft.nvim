-- Huge thanks to lewis6991, as this provider took huge inspiration (it is
-- pretty much copied over) from his in hover.nvim

local util = require('hovercraft.provider.lsp.util')
local ms = require('vim.lsp.protocol').Methods
local hover_ns = vim.api.nvim_create_namespace('hovercraft.provider.lsp.hover_range')

local M = {}

---@class Hovercraft.Provider.Lsp.Hover : Hovercraft.Provider
local Lsp = {}

Lsp.__index = Lsp

function Lsp:is_enabled(opts)
  local bufnr = opts.bufnr

  for _, client in pairs(util.get_clients({ bufnr = bufnr })) do
    if client:supports_method(ms.textDocument_hover) then
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

  -- This part of the code takes heavy inspiration from the vim.lsp.hover implementation.
  vim.lsp.buf_request_all(0, ms.textDocument_hover, util.client_positional_params(), function(results, ctx)
    local bufnr = assert(ctx.bufnr)
    if vim.api.nvim_get_current_buf() ~= bufnr then
      -- Ignore result since buffer changed. This happens for slow language servers.
      return
    end

    local results1 = {} --- @type table<integer,lsp.Hover>

    for client_id, resp in pairs(results) do
      local err, result = resp.err, resp.result
      if err then
        vim.lsp.log.error(err.code, err.message)
      elseif result then
        results1[client_id] = result
      end
    end

    if vim.tbl_isempty(results1) then
      -- no results
      done()
      return
    end

    local contents = {} --- @type Hovercraft.Line[]

    local nresults = #vim.tbl_keys(results1)

    local format = 'markdown'

    for client_id, result in pairs(results1) do
      local client = assert(vim.lsp.get_client_by_id(client_id))
      if nresults > 1 then
        -- Show client name if there are multiple clients
        contents[#contents + 1] = string.format('# %s', client.name)
      end

      if type(result.contents) == 'table' and result.contents.kind == 'plaintext' then
        if #results1 == 1 then
          format = 'plaintext'
          contents = vim.split(result.contents.value or '', '\n', { trimempty = true })
        else
          -- Surround plaintext with ``` to get correct formatting
          contents[#contents + 1] = '```'
          vim.list_extend(
            contents,
            vim.split(result.contents.value or '', '\n', { trimempty = true })
          )
          contents[#contents + 1] = '```'
        end
      else
        local res = result.contents

        if type(res) == "table" and #res > 0 then
          vim.list_extend(contents, res)
        elseif (type(res) == "table" and res.value) or type(res) then
          contents[#contents + 1] = res
        end
      end
      local range = result.range
      if range then
        local start = range.start
        local end_ = range['end']
        local start_idx = vim.lsp.util._get_line_byte_from_position(bufnr, start, client.offset_encoding)
        local end_idx = vim.lsp.util._get_line_byte_from_position(bufnr, end_, client.offset_encoding)

        vim.hl.range(
          bufnr,
          hover_ns,
          'LspReferenceTarget',
          { start.line, start_idx },
          { end_.line, end_idx },
          { priority = vim.hl.priorities.user }
        )
      end
      contents[#contents + 1] = '---'
    end

    -- Remove last linebreak ('---')
    contents[#contents] = nil

    done { lines = contents, filetype = format, customize = function(customize_opts)
      vim.api.nvim_create_autocmd('WinClosed', {
        pattern = tostring(customize_opts.winnr),
        once = true,
        callback = function()
          vim.api.nvim_buf_clear_namespace(bufnr, hover_ns, 0, -1)
          return true
        end,
      })
    end }
  end)
end

---@return Hovercraft.Provider.Lsp.Hover
function M.new()
  return setmetatable({}, Lsp)
end

return M
