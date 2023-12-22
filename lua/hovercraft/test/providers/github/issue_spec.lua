local GithubIssue = require('hovercraft.provider.github.issue')

local eq = assert.are.same

describe('GithubIssue', function()
  describe('_is_trigger_word', function()
    describe('match issue', function()
      it('should match issue', function()
        eq(true, GithubIssue._is_trigger_word('#123'))
      end)

      it('should not enable for only pound sign', function()
        eq(false, GithubIssue._is_trigger_word('#'))
      end)

      it('should not enable for pound sign in the middle', function()
        eq(false, GithubIssue._is_trigger_word('123#123'))
      end)
    end)
  end)
end)
