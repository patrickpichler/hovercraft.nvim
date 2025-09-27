local util = require('hovercraft.util')

local M = {}

function M._extract_issue(word)
  return word:match('^#(%d+)$')
end

function M._extract_repo_issue(word)
  local user, repo, issue, type

  _, _, user, repo, issue = word:find('^([%a%d._-]+)/([%a%d._-]+)#(%d+)$')

  if user and repo and issue then
    return user and repo and issue and { user, repo, issue }
  end

  _, _, user, repo, type, issue = word:find('^https://github.com/([%a%d._-]+)/([%a%d._-]+)/(%a*)/(%d+)$')

  if vim.tbl_contains({ 'issues', 'pulls' }, type) then
    return user and repo and issue and { user, repo, issue }
  end

  return nil
end

local known_github_pages = {
  'about',
  'events',
  'explore',
  'projects',
  'pulls',
  'repositories',
  'sponsors',
  'settings',
  'stars',
  'topics',
  'trending',
}
local user_prefixes = { 'TODO', 'FIXME', 'FIX' }

---@param word string
---@return string?
function M._extract_user(word)
  -- matches user (note: github users follow a stricter regex, but this should be good enough)
  ---@type string?
  local user = word:match([[^@([%a%d\._-]+)$]])

  if user then
    return user
  end

  ---@type string?
  user = word:match([[^https://github.com/([%a%d._-]+)/?$]])

  if user and not vim.tbl_contains(known_github_pages, user:lower()) then
    return user
  end

  local comment_type

  _, _, comment_type, user = word:find([[(%a+)%(@?([%a%d\._-]+)%):?$]])

  if vim.tbl_contains(user_prefixes, comment_type) then
    return user
  end

  return nil
end

---@param word string
---@return { [1]: string, [2]: string }?
function M._extract_repo_info(word)
  local _, _, user, repo = word:find([[^https://github.com/([%a%d._-]+)/([%a%d\._-]+)$]]) -- matches https repo

  if user and repo then
    return { user, repo }
  end

  _, _, user, repo = word:find([[^git@github.com:([%a%d\._-]+)/([%a%d\._-]+).git$]]) -- matches ssh repo

  if user and repo then
    return { user, repo }
  end

  return nil
end

function M.format_error(result)
  if result.error == 'NotFound' then
    return { string.format('--- %s not found ---', result.kind) }
  end

  if result.error == 'RateLimiting' then
    return { '--- **Error**: hitting rate limit ---' }
  end

  local lines = {
    string.format('**Error while retrieving %s**: %s', result.kind, result.error),
  }

  if result.result then
    table.insert(lines, '---')
    util.add_all(lines, util.split_lines(result.result))
  end

  return lines
end

return M
