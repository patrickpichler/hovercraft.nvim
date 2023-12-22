local async = require('plenary.async')
local GithubApi = require('hovercraft.helpers.github')
local Base64 = require('hovercraft.vendor.lbase64')
local GithubUtil = require('hovercraft.provider.github.util')
local Cache = require('hovercraft.helpers.cache')

local M = {}

---@class Github.Repo : Hovercraft.Provider
---@field api GithubApi
---@field _repo_cache Cache
---@field _fetch_readme boolean
local GithubRepo = {}

GithubRepo.__index = GithubRepo

---@param word string
---@return boolean
function M._is_trigger_word(word)
  return (
        GithubUtil._extract_repo_info(word)
      )
      and true
      or false
end

function GithubRepo:is_enabled()
  local word = vim.fn.expand('<cWORD>')

  return M._is_trigger_word(word)
end

function GithubRepo:_load_repo(repo_name)
  return self._repo_cache:get_or_load(repo_name, function(k)
    local repo = self.api:get_repo(k)

    return repo, repo.error == nil
  end)
end

function GithubRepo:_handle_repo(repo_name, fetch_readme, success_handler, failure_handler)
  local repo = self:_load_repo(repo_name)

  if not repo or repo.error then
    failure_handler(repo)
    return
  end

  local readme = nil

  if fetch_readme then
    -- TODO: we might want to cache readmes as well
    local gh_readme = self.api:get_repo_readme(repo_name)

    if gh_readme and not gh_readme.error then
      if gh_readme.result.encoding == 'base64' then
        readme = Base64.decode(gh_readme.result.content)
      end
    end
  end

  success_handler(repo, readme)
end

local function format_github_repo(repo, readme)
  local result = {
    string.format('# %s', repo.full_name),
    repo.description,
    '---',
    string.format('**URL:** %s', repo.html_url),
    string.format('**Owner:** %s', repo.owner.login),
    string.format('**Stars:** %s', repo.stargazers_count),
    string.format('**Created:** %s', repo.created_at),
    string.format('**Topics:** %s', table.concat(repo.topics, ', ')),
  }

  if readme then
    table.insert(result, '')
    table.insert(result, '---')
    table.insert(result, readme)
  end

  return result
end

---@param self Github.Repo
GithubRepo.execute = async.void(function(self, _, done)
  local word = vim.fn.expand('<cWORD>')

  local repo = GithubUtil._extract_repo_info(word)

  if repo then
    local r = string.format('%s/%s', repo[1], repo[2])

    self:_handle_repo(r, self._fetch_readme, function(gh_repo, readme)
      done { lines = format_github_repo(gh_repo.result, readme), filetype = 'markdown' }
    end, function(err)
      done { lines = GithubUtil.format_error(err), filetype = 'markdown' }
    end)
  end
end)

---@param opts { api?: GithubApi, fetch_readme?: boolean }
---@return Github.Repo
function M.new(opts)
  opts = opts or {}

  return setmetatable({
    api = opts.api or GithubApi,
    _repo_cache = Cache.new({
      life_time_ms = 10000,
    }),
    _fetch_readme = opts.fetch_readme or true,
  }, GithubRepo)
end

return M
