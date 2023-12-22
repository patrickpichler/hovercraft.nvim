local util = require('hovercraft.provider.github.util')

local eq = assert.are.same

describe('GithubUtil', function()
  describe('_extract_issue', function()
    it('should extract issue', function()
      eq('123', util._extract_issue('#123'))
    end)

    it('should return nil for invalid', function()
      eq(nil, util._extract_issue('#'))
    end)
  end)

  describe('_extract_user', function()
    it('should extract user', function()
      eq('hansi.hinterseer', util._extract_user('@hansi.hinterseer'))
    end)

    it('should extract user from url', function()
      eq('hansi.hinterseer', util._extract_user('https://github.com/hansi.hinterseer'))
    end)

    it('should return nil for invalid', function()
      eq(nil, util._extract_user('invalid user'))
    end)

    it('should extract user in TODO', function()
      eq('hansi.hinterseer', util._extract_user('TODO(@hansi.hinterseer)'))
    end)
  end)

  describe('_extract_repo_info', function()
    it('should extract https repo info', function()
      eq({ 'hansi.hinterseer', 'test-1_nvim' },
        util._extract_repo_info('https://github.com/hansi.hinterseer/test-1_nvim'))
    end)

    it('should extract ssh repo info', function()
      eq({ 'hansi.hinterseer', 'test-1_nvim' },
        util._extract_repo_info('git@github.com:hansi.hinterseer/test-1_nvim.git'))
    end)

    it('should return nil for invalid url', function()
      eq(nil, util._extract_repo_info('git@github.com/hansi.hinterseer/test-1_nvim.git'))
    end)

    describe('_extract_repo_issue', function()
      it('should extract issue', function()
        local result = util._extract_repo_issue('neovim/tree-sitter-vim#123')

        eq({ 'neovim', 'tree-sitter-vim', '123' }, result)
      end)

      it('should extract issue for https url', function()
        local result = util._extract_repo_issue('https://github.com/neovim/tree-sitter-vim/issues/123')

        eq({ 'neovim', 'tree-sitter-vim', '123' }, result)
      end)

      it('should extract issue for pull https url', function()
        local result = util._extract_repo_issue('https://github.com/neovim/tree-sitter-vim/pulls/123')

        eq({ 'neovim', 'tree-sitter-vim', '123' }, result)
      end)

      it('should return nil for invalid', function()
        eq(nil, util._extract_repo_issue('tree-sitter-vim#123'))
      end)
    end)
  end)
end)
