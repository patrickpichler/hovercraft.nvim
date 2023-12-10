local M = {}

function M.split_lines(value)
  value = string.gsub(value, '\r\n?', '\n')
  return vim.split(value, '\n', {})
end

return M
