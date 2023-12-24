-- Huge thanks to lewis6991, as this provider took huge inspiration (it is
-- pretty much copied over) from his in hover.nvim

local async = require('plenary.async')

local M = {}

---@class ManProvider : Hovercraft.Provider
local ManProvider = {}
ManProvider.__index = ManProvider

--- @param opts Hover.Provider.IsEnabledOpts
--- @return boolean
function ManProvider:is_enabled(opts)
  return vim.tbl_contains({
    'c', 'sh', 'zsh', 'fish', 'tcl', 'make',
  }, vim.bo[opts.bufnr].filetype)
end

ManProvider.execute = async.void(function(_, opts, done)
  local word = vim.fn.expand('<cword>')
  local section = vim.bo[opts.bufnr].filetype == 'tcl' and 'n' or '1'
  local uri = string.format('man://%s(%s)', word, section)

  local bufnr = vim.api.nvim_create_buf(false, true)

  local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
    -- This will execute when the buffer is hidden
    vim.api.nvim_exec_autocmds('BufReadCmd', { pattern = uri })
  end)

  if not ok or vim.api.nvim_buf_line_count(bufnr) <= 1 then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    done()
    return
  end

  -- Run BufReadCmd again to resize properly
  vim.api.nvim_create_autocmd('BufWinEnter', {
    buffer = bufnr,
    once = true,
    callback = function()
      vim.api.nvim_exec_autocmds('BufReadCmd', { pattern = uri })
    end
  })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  done { lines = lines, filetype = "man" }
end)

function M.new()
  return setmetatable({}, ManProvider)
end

return M
