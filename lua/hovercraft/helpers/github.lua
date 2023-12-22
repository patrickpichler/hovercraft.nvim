local async = require('plenary.async')
local Job = require('plenary.job')

local log = require('hovercraft.dev').log

---@class GithubApi
---@field _token? string | fun(): string? token used for authentication with Github
---@field get_repo fun(self: GithubApi, repo: string): table
local GithubApi = {}
GithubApi.__index = GithubApi

---@enum GithubApi.Error
GithubApi.ERRORS = {
  JobFailed = 'JobFailed',
  NotFound = 'NotFound',
  RateLimiting = 'RateLimiting',
  CannotParseResult = 'CannotParseResult',
  HttpError = 'HttpError',
}

---@param token string | fun(): string? token used for authentication with Github
function GithubApi:update_token(token)
  vim.validate {
    token = { token, { 'function', 'string', 'nil' } }
  }

  self._token = token
end

function GithubApi:_get_token()
  if not self._token then
    return nil
  end

  if type(self._token) == 'string' then
    return self._token
  elseif type(self._token) == 'function' then
    return self._token()
  end
end

function GithubApi:_build_common_curl_args(url)
  local args = {
    '--silent',
    '-w', '%{stderr}%{http_code}\n%header{x-ratelimit-remaining}',
    '-L',
    '-H', 'Accept: application/vnd.github+json',
  }

  local token = self:_get_token()

  if token then
    table.insert(args, '-H')
    table.insert(args, string.format('Authorization: Bearer %s', self:_get_token()))
  end

  table.insert(args, url)

  return args
end

local function handle_job_result(kind, job, code)
  if code ~= 0 then
    local result = table.concat(job:stderr_result(), '\n')

    log.error(string.format('failed to retrieve github %s', kind))
    log.error(result)

    return { kind = kind, error = GithubApi.ERRORS.JobFailed }
  end

  local stderr = job:stderr_result()
  local status_code = tonumber(stderr[1])
  local remaining_rate_limit = tonumber(stderr[2])

  if status_code == 404 then
    return { kind = kind, error = GithubApi.ERRORS.NotFound }
  end

  if remaining_rate_limit == 0 then
    log.error(string.format('cannot retrieve github %s: calls are getting rate limited', kind))

    return { kind = kind, error = GithubApi.ERRORS.RateLimiting }
  end

  local result = job:result()

  local ok, parsed_result = pcall(vim.json.decode, table.concat(result, '\n'))

  ---@cast parsed_result table

  if not ok then
    -- parsed_result should be an error in this case
    log.error(string.format('cannot parse github %s result: %s', kind, vim.inspect(parsed_result)))
    log.error(result)

    return { kind = kind, error = GithubApi.ERRORS.CannotParseResult, result = result }
  end

  if status_code >= 200 and status_code < 300 then
    return { kind = kind, result = parsed_result }
  end

  if parsed_result.message then
    return { kind = kind, error = GithubApi.ERRORS.HttpError, result = parsed_result.message }
  end

  return {
    kind = kind,
    error = GithubApi.ERRORS.HttpError,
    result = string.format('got back http status code `%d`', status_code)
  }
end

---@param self GithubApi
---@param repo string
GithubApi.get_repo = async.wrap(function(self, repo, done)
  vim.validate {
    repo = { repo, 'string' }
  }

  local url = string.format('https://api.github.com/repos/%s', repo)

  local args = self:_build_common_curl_args(url)

  Job:new({
    command = 'curl',
    args = args,
    on_exit = function(j, code)
      local result = handle_job_result('Repository', j, code)

      vim.schedule(function()
        done(result)
      end)
    end
  }):start()
end, 3)

GithubApi.get_repo_readme = async.wrap(function(self, repo, done)
  vim.validate {
    repo = { repo, 'string' }
  }

  local url = string.format('https://api.github.com/repos/%s/readme', repo)

  local args = self:_build_common_curl_args(url)

  Job:new({
    command = 'curl',
    args = args,
    on_exit = function(j, code)
      local result = handle_job_result('Readme', j, code)

      vim.schedule(function()
        done(result)
      end)
    end
  }):start()
end, 3)

GithubApi.get_issue = async.wrap(function(self, repo, issue, done)
  vim.validate {
    repo = { repo, 'string' },
    issue = { issue, { 'string', 'number' } },
  }

  if type(issue) == 'number' then
    issue = tostring(issue)
  end

  local url = string.format('https://api.github.com/repos/%s/issues/%s', repo, issue)
  local args = self:_build_common_curl_args(url)

  Job:new({
    command = 'curl',
    args = args,
    on_exit = function(j, code)
      local result = handle_job_result('Issue', j, code)

      vim.schedule(function()
        done(result)
      end)
    end
  }):start()
end, 4)

---@param user string
---@return table?
GithubApi.get_user = async.wrap(function(self, user, done)
  vim.validate {
    repo = { user, 'string' },
  }

  local url = string.format('https://api.github.com/users/%s', user)
  local args = self:_build_common_curl_args(url)

  Job:new({
    command = 'curl',
    args = args,
    on_exit = function(j, code)
      local result = handle_job_result('User', j, code)

      vim.schedule(function()
        done(result)
      end)
    end
  }):start()
end, 3)

local function new(opts)
  opts = opts or {}

  vim.validate {
    token = { opts.token, { 'function', 'string', 'nil' } }
  }

  return setmetatable({
    _token = opts.token,
  }, GithubApi)
end

---@class TheGithubApi : GithubApi
local TheGithubApi = new({
  token = function()
    return os.getenv("GITHUB_TOKEN")
  end
})

---@return GithubApi
function TheGithubApi.new(opts)
  return new(opts)
end

return TheGithubApi
