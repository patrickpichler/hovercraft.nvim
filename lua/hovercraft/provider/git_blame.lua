local Git = require('hovercraft.helpers.git')
local async = require('plenary.async')
local Path = require('plenary.path')
local util = require('hovercraft.util')

local M = {}

local GitBlame = {}
GitBlame.__index = GitBlame

-- GitBlame.is_enabled = async.wrap(function(opts, done)
--   local path = Path:new(util.get_buffer_path(opts.bufnr))
--
--   done(Git.is_repo({ cwd = path:absolute() }))
-- end, 2)

GitBlame.is_enabled = async.wrap(function(_, opts, done)
  async.void(function()
    local path = Path:new(util.get_buffer_path(opts.bufnr))
    path = ((not path:is_dir() and path:parent()) or path)

    local target_path = (path:exists() and path or Path:new('.')):absolute()

    done(Git.is_repo({ cwd = target_path }))
  end)()
end, 3)

local function format_commit(commit)
  local commit_date = os.date('%c', tonumber(commit.data['commit-time']))

  return {
    string.format('**%s**', commit.sha),
    string.format('**Author:** %s', commit.data['author']),
    string.format('**Author-Mail:** %s', commit.data['author-mail']),
    string.format('**Committer:** %s', commit.data['committer']),
    string.format('**Committer-Mail:** %s', commit.data['committer-mail']),
    string.format('**Commit-Date:** %s', commit_date),
  }
end

local function first(t)
  for _, v in pairs(t) do
    return v
  end

  return nil
end

local function format_error(result)
  local lines

  if result.error == 'JobFailed' then
    lines = { string.format('--- Job failed with code %d ---', result.code) }
  else
    lines = {
      string.format('**Error while retrieving blame result**: %s', result.error),
    }
  end

  if result.result then
    table.insert(lines, '---')
    util.concat(lines, util.split_lines(result.result))
  end

  return lines
end

GitBlame.execute = async.void(function(_, opts, done)
  local file_path = Path:new(util.get_buffer_path(opts.bufnr))

  local cwd = file_path:parent():absolute()

  local result = Git.git_blame({ cwd = cwd, line = { opts.pos[1] }, file = file_path:absolute() })

  if result.error ~= nil then
    done({ lines = format_error(result), filetype = 'markdown' })
    return
  end

  local commit = first(result.commits)

  if not commit then
    done({ lines = { '--- No commit data ---' }, filetype = 'markdown' })
    return
  end

  done({ lines = format_commit(commit), filetype = 'markdown' })
end)

function M.new(opts)
  return setmetatable({}, GitBlame)
end

return M
