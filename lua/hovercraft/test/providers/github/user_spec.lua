local GithubUser = require('hovercraft.provider.github.user')

local eq = assert.are.same

describe('GithubUser', function()
  describe('_is_trigger_word', function()
    describe('match user', function()
      it('should not enable for just @ sign', function()
        eq(false, GithubUser._is_trigger_word('@'))
      end)

      it('should not enable for word with @ sign in the middle', function()
        eq(false, GithubUser._is_trigger_word('hansi@hinterseer'))
      end)

      it('should enable for users with just letters', function()
        eq(true, GithubUser._is_trigger_word('@luke'))
      end)

      it('should enable for users with letters and dots', function()
        eq(true, GithubUser._is_trigger_word('@hansi.hinterseer'))
      end)

      it('should enable for users with letters and numbers', function()
        eq(true, GithubUser._is_trigger_word('@hansihinterseer1'))
      end)

      it('should enable for users with letters, numbers and dots', function()
        eq(true, GithubUser._is_trigger_word('@hansi.hinterseer1'))
      end)

      it('should enable for users with letters, numbers, dots and dashes', function()
        eq(true, GithubUser._is_trigger_word('@hansi-hinterseer.1'))
      end)

      it('should enable for users with letters, numbers, dots, dashes and underscores', function()
        eq(true, GithubUser._is_trigger_word('@hansi-hinterseer.1_2'))
      end)

      it('should not match user with space', function()
        eq(false, GithubUser._is_trigger_word('@hansi-hinterseer.  1_2'))
      end)

      it('should not match user with any special char', function()
        eq(false, GithubUser._is_trigger_word('@hansi-hinterseer.#1_2'))
      end)

      it('should match full github url mention', function()
        eq(true, GithubUser._is_trigger_word('https://github.com/patrickpichler'))
      end)
    end)
  end)
end)
