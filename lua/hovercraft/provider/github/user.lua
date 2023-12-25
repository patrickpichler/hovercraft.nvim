local async = require('plenary.async')
local GithubApi = require('hovercraft.helpers.github')
local GithubUtil = require('hovercraft.provider.github.util')
local Cache = require('hovercraft.helpers.cache')
local util = require('hovercraft.util')

local M = {}

---@class Github.User : Hovercraft.Provider
---@field api GithubApi
---@field _user_cache Cache
local GithubUser = {}

GithubUser.__index = GithubUser

---@param word string
---@return boolean
function M._is_trigger_word(word)
  return (
        GithubUtil._extract_user(word)
      )
      and true
      or false
end

function GithubUser:is_enabled()
  local word = vim.fn.expand('<cWORD>')

  return M._is_trigger_word(word)
end

local UserFields = {
  { 'URL',      'html_url' },
  { 'Name',     'name' },
  { 'Email',    'email' },
  { 'Company',  'company' },
  { 'Hireable', 'hireable' },
  { 'Blog',     'blog' },
  { 'Location', 'location' },
  { 'Twitter', 'twitter_username', function(handle)
    return string.format('https://twitter.com/%s', handle)
  end },
  { 'Followers', 'followers' },
  { 'Following', 'following' },
  { 'Repos',     'public_repos' },
  { 'Created',   'created_at' },
}

local OrganizationFields = {
  { 'URL',      'html_url' },
  { 'Name',     'name' },
  { 'Email',    'email' },
  { 'Company',  'company' },
  { 'Blog',     'blog' },
  { 'Location', 'location' },
  { 'Twitter', 'twitter_username', function(handle)
    return string.format('https://twitter.com/%s', handle)
  end },
  { 'Followers', 'followers' },
  { 'Following', 'following' },
  { 'Repos',     'public_repos' },
  { 'Created',   'created_at' },
}

local function format_github_user(user)
  local lines = {
    string.format('# %s', user.login),
    '---',
  }

  local fields = user.type == 'User' and UserFields or OrganizationFields

  for _, f in ipairs(fields) do
    local key = f[1]
    local value = user[f[2]]
    local formatter = f[3]

    if not value or value == vim.NIL then
      goto continue
    end

    if formatter then
      value = formatter(value)
    end

    table.insert(lines, string.format('**%s**: %s', key, value))

    ::continue::
  end

  if user.bio and user.bio ~= vim.NIL then
    table.insert(lines, '')
    table.insert(lines, '---')
    util.add_all(lines, util.split_lines(user.bio))
  end

  return lines
end

function GithubUser:_handle_user(username, success_handler, failure_handler)
  local user = self._user_cache:get_or_load(username, function()
    local user = self.api:get_user(username)

    return user, user.error == nil
  end)

  if not user or user.error then
    failure_handler(user)
    return
  end

  success_handler(user)
end

---@param self Github.User
GithubUser.execute = async.void(function(self, _, done)
  local word = vim.fn.expand('<cWORD>')

  local user = GithubUtil._extract_user(word)

  if user then
    self:_handle_user(user, function(gh_user)
      done { lines = format_github_user(gh_user.result), filetype = 'markdown' }
    end, function(err)
      done { lines = GithubUtil.format_error(err), filetype = 'markdown' }
    end)
  end
end)

---@return Github.User
function M.new(opts)
  opts = opts or {}

  return setmetatable({
    api = opts.api or GithubApi,
    _user_cache = Cache.new({
      life_time_ms = 20000,
    }),
  }, GithubUser)
end

return M
