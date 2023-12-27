local async = require('plenary.async')
local Job = require('plenary.job')

local log = require('hovercraft.dev').log

local M = {}

local Error = {
  JobFailed = 'JobFailed',
}

M.list_remotes = async.wrap(function(opts, done)
  opts = opts or {}

  Job:new({
    command = 'git',
    args = { 'remote' },
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        vim.schedule(function()
          done { error = Error.JobFailed, result = j:stderr_result() }
        end)
        return
      end

      local result = j:result()

      vim.schedule(function()
        done { result = result }
      end)
    end
  }):start()
end, 2)

M.remote_url = async.wrap(function(opts, done)
  opts = opts or {}

  local args = { 'ls-remote', '--get-url' }

  if opts.remote then
    table.insert(args, opts.remote)
  end

  Job:new({
    command = 'git',
    args = args,
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        vim.schedule(function()
          done { error = Error.JobFailed, result = j:stderr_result() }
        end)
        return
      end

      local result = j:result()

      if #result > 1 then
        log.info('result has more than a single line (i am going to use the first):')
        log.info(result)
      end

      vim.schedule(function()
        done { result = result[1] }
      end)
    end
  }):start()
end, 2)

M.find_repo_root = async.wrap(function(opts, done)
  opts = opts or {}

  Job:new({
    command = 'git',
    args = { 'rev-parse', '--show-toplevel' },
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        vim.schedule(function()
          done { error = Error.JobFailed, result = j:stderr_result() }
        end)
        return
      end

      local result = j:result()

      if #result > 1 then
        log.info('result has more than a single line (i am going to use the first):')
        log.info(result)
      end

      vim.schedule(function()
        done { result = result[1] }
      end)
    end
  }):start()
end, 2)

M.is_repo = async.wrap(function(opts, done)
  opts = opts or {}

  Job:new({
    command = 'git',
    args = { 'rev-parse', '--is-inside-work-tree' },
    cwd = opts.cwd or '.',
    on_exit = function(_, code)
      vim.schedule(function()
        done { result = code == 0 }
      end)
    end
  }):start()
end, 2)

---@class BlameLine
---@field original integer
---@field final integer
---@field sha string

---@class BlameCommit
---@field sha string
---@field data table<string, string>

---@param blame_lines string[]
---@return BlameLine[] lines, {[string]: BlameCommit} commits
function M._parse_git_blame_output(blame_lines)
  local commits, lines = {}, {}
  local current_commit, current_line

  for _, l in ipairs(blame_lines) do
    if current_commit == nil then
      local _, _, sha, l_org, l_final, _ = l:find([[^([%x]+)%s(%d+)%s(%d+)%s?(%d*)$]])

      current_commit = commits[sha] or { sha = sha, data = {} }
      current_line = { original = tonumber(l_org), final = tonumber(l_final), commit = sha }

      table.insert(lines, current_line)

      commits[sha] = current_commit
      goto continue
    end

    if l:sub(1, 1) == '\t' then
      local text = l:sub(2)

      current_line.text = text

      -- reset state
      current_commit = nil
      current_line = nil

      goto continue
    end

    local _, _, key, value = l:find([[^([%a-]*)%s?(.*)$]])

    if key == 'boundary' then
      goto continue
    end

    current_commit.data[key] = value

    ::continue::
  end

  return lines, commits
end

M.git_blame = async.wrap(function(opts, done)
  opts = opts or {}

  vim.validate {
    file = { opts.file, 'string' },
    cwd = { opts.cwd, { 'string', 'nil' } },
    line = { opts.line, function(v)
      return type(v) == "table" and
          ((#v == 1 and type(v[1]) == "number")
            or (#v == 2 and type(v[1]) == "number" and type(v[2]) == "number"))
    end, 'two or one number' }
  }

  local line_from = opts.line[1]
  local line_to = #opts.line == 2 and opts.line[2] or line_from

  Job:new({
    command = 'git',
    args = {
      'blame',
      '-L', string.format('%d,%d', line_from, line_to),
      '--porcelain',
      opts.file,
    },
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        vim.schedule(function()
          done { error = 'JobFailed', status_code = code, result = j:stderr_result() }
        end)
        return
      end

      local job_result = j:result()

      local lines, commits = M._parse_git_blame_output(job_result)

      vim.schedule(function()
        done { result = { lines = lines, commits = commits } }
      end)
    end
  }):start()
end, 2)

M.git_commit_message = async.wrap(function(opts, done)
  opts = opts or {}

  vim.validate {
    ref = { opts.ref, 'string' },
    cwd = { opts.cwd, { 'string', 'nil' } },
  }

  Job:new({
    command = 'git',
    args = {
      'rev-list',
      '--max-count=1',
      '--no-commit-header',
      '--format=%B',
      opts.ref,
    },
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        vim.schedule(function()
          done { error = 'JobFailed', code = code, result = j:stderr_result() }
        end)
        return
      end

      local job_result = j:result()

      vim.schedule(function()
        done { result = job_result }
      end)
    end
  }):start()
end, 2)

return M
