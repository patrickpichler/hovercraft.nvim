local GithubRepo = require('hovercraft.provider.github.repo')

local eq = assert.are.same

describe('GithubIssue', function()
  describe('_is_trigger_word', function()
    describe('match https url', function()
      it('should match github https url', function()
        eq(true, GithubRepo._is_trigger_word('https://github.com/hansi.hinterseer/project-1.nvim'))
      end)

      it('should not enable for any https url', function()
        eq(false, GithubRepo._is_trigger_word('https://github.com/about'))
      end)
    end)

    describe('match ssh url', function()
      it('should match github url', function()
        eq(true, GithubRepo._is_trigger_word('git@github.com:hansi.hinterseer/project-1.nvim.git'))
      end)

      it('should not enable for any almost git url', function()
        eq(false, GithubRepo._is_trigger_word('git@github.com/hansi.hinterseer/project-1.nvim.git'))
      end)
    end)
  end)
end)
