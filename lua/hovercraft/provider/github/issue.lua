local async = require('plenary.async')
local Path = require('plenary.path')
local Git = require('hovercraft.helpers.git')
local GithubApi = require('hovercraft.helpers.github')
local GithubUtil = require('hovercraft.provider.github.util')
local Cache = require('hovercraft.helpers.cache')
local util = require('hovercraft.util')

local M = {}

---@class Github.Issue: Hovercraft.Provider
---@field api GithubApi
---@field _repo_cache Cache
local GithubIssue = {}

GithubIssue.__index = GithubIssue

---@param word string
---@return boolean
function M._is_trigger_word(word)
  return (
        GithubUtil._extract_issue(word)
        or GithubUtil._extract_repo_issue(word)
      )
      and true
      or false
end

function GithubIssue:is_enabled()
  local word = vim.fn.expand('<cWORD>')

  return M._is_trigger_word(word)
end

function GithubIssue:_handle_repo_issue(repo_name, issue, success_handler, failure_handler)
  local gh_issue = self.api:get_issue(repo_name, issue)

  if not gh_issue or gh_issue.error then
    failure_handler(gh_issue)
    return
  end

  success_handler(gh_issue)
end

---@enum Github.Issue.Errors
local ERRORS = {
  NoGitRepo = 'NoGitRepo',
  CannotExtractRemote = 'CannotExtractRemote',
  CannotExtractGithubRepo = 'CannotExtractGithubRepo',
}

function GithubIssue:_load_repo(repo_name)
  return self._repo_cache:get_or_load(repo_name, function(k)
    local repo = self.api:get_repo(k)

    -- if the current repo doesn't have issues enabled, try falling back to parent
    -- TODO: there has to be a better way in figuring out the right repo a issue belongs to
    if repo.error == nil and not repo.result.has_issues then
      return { result = repo.result.parent }
    end

    return repo, repo.error == nil
  end)
end

function GithubIssue:_handle_issue(bufnr, issue, success_handler, failure_handler)
  ---@type Path
  local path = Path.new(util.get_buffer_path(bufnr))
  path = ((not path:is_dir() and path:parent()) or path)

  local target_path = (path:exists() and path or Path:new('.')):absolute()

  if not Git.is_repo({ cwd = target_path }).result then
    failure_handler({ error = ERRORS.NoGitRepo, result = string.format('`%s` is not a git repo', target_path) })
    return
  end

  local remote_result = Git.remote_url({ cwd = target_path })

  if remote_result.error then
    failure_handler { error = ERRORS.CannotExtractRemote, result = string.format('cannot extract remote url for `%s`', target_path) }
    return
  end

  local info = GithubUtil._extract_repo_info(remote_result.result)

  if not info then
    failure_handler { error = ERRORS.NoGitRepo, result = string.format('cannot extract github repo for url `%s`', remote_result.result) }
    return
  end

  local repo = self:_load_repo(string.format('%s/%s', info[1], info[2]))

  if not repo or repo.error then
    failure_handler(repo)
    return
  end

  self:_handle_repo_issue(repo.result.full_name, issue, success_handler, failure_handler)
end

local function format_github_issue_lines(issue)
  local issue_type = issue.pull_request and 'PR' or 'Issue'

  local lines = {
    string.format('# %s #%d: %s', issue_type, issue.number, issue.title),
    '',
    string.format('**URL:** %s', issue.html_url),
    string.format('**Author:** %s', issue.user.login),
    string.format('**State:** %s', issue.state),
    string.format('**Created:** %s', issue.created_at),
    string.format('**Last updated:** %s', issue.updated_at),
  }

  if issue.body and issue.body:len() > 0 then
    util.add_all(lines, {
      '----',
      issue.body,
    })
  end

  return lines
end

---@param self Github.Issue
---@param opts any
GithubIssue.execute = async.void(function(self, opts, done)
  local word = vim.fn.expand('<cWORD>')

  local issue = GithubUtil._extract_issue(word)
  local repo_issue = GithubUtil._extract_repo_issue(word)

  if issue then
    self:_handle_issue(opts.bufnr, issue, function(gh_issue)
      done { lines = format_github_issue_lines(gh_issue.result), filetype = 'markdown' }
    end, function(err)
      done { lines = GithubUtil.format_error(err), filetype = 'markdown' }
    end)
  elseif repo_issue then
    local r = string.format('%s/%s', repo_issue[1], repo_issue[2])

    self:_handle_repo_issue(r, repo_issue[3], function(gh_issue)
      done { lines = format_github_issue_lines(gh_issue.result), filetype = 'markdown' }
    end, function(err)
      done { lines = GithubUtil.format_error(err), filetype = 'markdown' }
    end)
  end
end)

---@return Github.Issue
function M.new(opts)
  opts = opts or {}

  return setmetatable({
    api = opts.api or GithubApi,
    _repo_cache = Cache.new({
      life_time_ms = -1, -- the parent repo info is valid forever, hence no invalidating needed
    })
  }, GithubIssue)
end

return M
