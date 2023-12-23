local async = require('plenary.async')

local M = {}

function M.split_lines(value)
  value = string.gsub(value, '\r\n?', '\n')
  return vim.split(value, '\n', {})
end

function M.concat(target, to_add)
  for _, l in ipairs(to_add) do
    table.insert(target, l)
  end
end

M.get_buffer_path = async.wrap(function(bufnr, done)
  vim.api.nvim_buf_call(bufnr, function()
    done(vim.fn.expand('%:p'))
  end)
end, 2)

return M
