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

return M
