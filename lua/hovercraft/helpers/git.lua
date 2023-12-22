local async = require('plenary.async')
local Job = require('plenary.job')

local log = require('hovercraft.dev').log


local M = {}

M.list_remotes = async.wrap(function(opts, done)
  opts = opts or {}

  Job:new({
    command = 'git',
    args = { 'remote' },
    cwd = opts.cwd or '.',
    on_exit = function(j, code)
      if code ~= 0 then
        log.warn('failed to list remotes')
        log.warn(table.concat(j:stderr_result(), '\n'))
        done()
        return
      end

      local result = j:result()

      done(result)
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
        log.warn('failed to retrieve remote url')
        log.warn(table.concat(j:stderr_result(), '\n'))
        done()
        return
      end

      local result = j:result()

      if #result > 1 then
        log.warn('result has more than a single line (i am going to use the first):')
        log.warn(result)
      end

      done(result[1])
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
        log.warn('failed to retrieve repo root')
        log.warn(table.concat(j:stderr_result(), '\n'))
        done()
        return
      end

      local result = j:result()

      if #result > 1 then
        log.warn('result has more than a single line (i am going to use the first):')
        log.warn(result)
      end

      done(result[1])
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
      done(code == 0)
    end
  }):start()
end, 2)

return M
