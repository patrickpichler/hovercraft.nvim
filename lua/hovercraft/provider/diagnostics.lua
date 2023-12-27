local M = {}

---@class Hovercraft.Provider.Diagnostics : Hovercraft.Provider
local Diagnostics = {}

Diagnostics.__index = Diagnostics

local function is_in_range(d, row, col)
  return (col >= d.col and row >= d.lnum)
      and (col <= d.end_col and row <= d.end_lnum)
end

function Diagnostics:is_enabled(opts)
  local row = opts.pos[1] - 1
  local col = opts.pos[2]

  local diagnostics = vim.diagnostic.get(opts.bufnr, { lnum = row })

  for _, d in ipairs(diagnostics) do
    if is_in_range(d, row, col) then
      return true
    end
  end

  return false
end

local SeverityNames = {
  [vim.diagnostic.severity.HINT] = 'HINT',
  [vim.diagnostic.severity.INFO] = 'INFO',
  [vim.diagnostic.severity.WARN] = 'WARN',
  [vim.diagnostic.severity.ERROR] = 'ERROR',
}

local function format_severity(severity)
  return SeverityNames[severity] or 'UNKNOWN'
end

---@param diagnostics Diagnostic[]
---@return string[]
local function format_diagnostics(diagnostics)
  local lines = {}

  for i, d in ipairs(diagnostics) do
    if i < #diagnostics then
      table.insert(lines, '---')
    end

    table.insert(lines, '**' .. format_severity(d.severity) .. '**')
    table.insert(lines, d.message)
  end

  return lines
end

function Diagnostics:execute(opts, done)
  local row = opts.pos[1] - 1
  local col = opts.pos[2]

  local diagnostics = vim.diagnostic.get(opts.bufnr, { lnum = row })

  local relevant_diagnostics = {}

  for _, d in ipairs(diagnostics) do
    if is_in_range(d, row, col) then
      table.insert(relevant_diagnostics, d)
    end
  end

  done { lines = format_diagnostics(relevant_diagnostics), filetype = 'markdown' }
end

function M.new()
  return setmetatable({}, Diagnostics)
end

return M
