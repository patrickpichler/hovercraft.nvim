local Git = require('hovercraft.helpers.git')
local async = require('plenary.async')
local Path = require('plenary.path')
local util = require('hovercraft.util')

local M = {}

local GitBlame = {}
GitBlame.__index = GitBlame

local dummy_commit_sha = '0000000000000000000000000000000000000000'

local function first(t)
  for _, v in pairs(t) do
    return v
  end

  return nil
end

GitBlame.is_enabled = async.wrap(function(_, opts, done)
  async.void(function()
    local file_path = Path:new(util.get_buffer_path(opts.bufnr))

    local cwd = file_path:parent():absolute()

    local blame_result = Git.git_blame({ cwd = cwd, line = { opts.pos[1] }, file = file_path:absolute() })

    if blame_result.error then
      done(false)
      return
    end

    local commits = blame_result.result.commits

    if not commits then
      done(false)
      return
    end

    local commit = first(commits)

    if not commit then
      done(false)
      return
    end


    done(commit.sha ~= dummy_commit_sha)
  end)()
end, 3)

local function format_commit(commit, message)
  local commit_date = os.date('%c', tonumber(commit.data['committer-time']))

  local result = {
    string.format('**Commit**: %s', commit.sha),
    string.format('**Author:** %s', commit.data['author']),
    string.format('**Author-Mail:** %s', commit.data['author-mail']),
    string.format('**Committer:** %s', commit.data['committer']),
    string.format('**Committer-Mail:** %s', commit.data['committer-mail']),
    string.format('**Committer-Date:** %s', commit_date),
  }

  if message and #message > 0 then
    table.insert(result, '---')
    util.add_all(result, message)
  end

  return result
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
    util.add_all(lines, result.result)
  end

  return lines
end

GitBlame.execute = async.void(function(self, opts, done)
  local file_path = Path:new(util.get_buffer_path(opts.bufnr))

  local cwd = file_path:parent():absolute()

  local result = Git.git_blame({ cwd = cwd, line = { opts.pos[1] }, file = file_path:absolute() })

  if result.error ~= nil then
    done({ lines = format_error(result), filetype = 'markdown' })
    return
  end

  local commit = first(result.result.commits)

  if not commit then
    done({ lines = { '--- No commit data ---' }, filetype = 'markdown' })
    return
  end

  local message = nil

  if self.show_commit_message and commit.sha ~= dummy_commit_sha then
    local message_result = Git.git_commit_message({ cwd = cwd, ref = commit.sha })

    if message_result.error ~= nil then
      done({ lines = format_error(message_result), filetype = 'markdown' })
      return
    end

    message = message_result.message
  end

  done({ lines = format_commit(commit, message), filetype = 'markdown' })
end)

function M.new(opts)
  opts = opts or {}

  return setmetatable({
    show_commit_message = opts.show_commit_message or true
  }, GitBlame)
end

return M
