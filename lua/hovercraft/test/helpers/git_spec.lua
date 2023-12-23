local Git = require('hovercraft.helpers.git')
local util = require('hovercraft.util')

local eq = assert.are.same

describe('hovercraft', function()
  describe('git._parse_git_blame_output', function()
    it('simple sample', function()
      local lines, commits = Git._parse_git_blame_output({
        [[b86c8625d6686af62e6396309e8a4fdac3623574 1 1 5]],
        [[author Patrick Pichler]],
        [[author-mail <git@patrickpichler.dev>]],
        [[author-time 1702237799]],
        [[author-tz +0100]],
        [[committer Patrick Pichler]],
        [[committer-mail <git@patrickpichler.dev>]],
        [[committer-time 1703024066]],
        [[committer-tz +0100]],
        [[summary Initial commit]],
        [[boundary]],
        [[filename TODO.md]],
        [[	# TODO]],
        [[b86c8625d6686af62e6396309e8a4fdac3623574 2 2]],
        [[	* Implement scrollbar in popup]],
        [[b86c8625d6686af62e6396309e8a4fdac3623574 3 3]],
        [[	    * a scrollbar like the one in nvim-cmp would be neat]],
        [[b86c8625d6686af62e6396309e8a4fdac3623574 4 4]],
        [[	]],
        [[b86c8625d6686af62e6396309e8a4fdac3623574 5 5]],
        [[	* Implement providers:]],
        [[babc40c6c080edf73296ba835df1cb6384ae51bc 6 6 1]],
        [[author Patrick Pichler]],
        [[author-mail <git@patrickpichler.dev>]],
        [[author-time 1703272196]],
        [[author-tz +0100]],
        [[committer Patrick Pichler]],
        [[committer-mail <git@patrickpichler.dev>]],
        [[committer-time 1703272196]],
        [[committer-tz +0100]],
        [[summary feat: add github related providers]],
        [[previous f6c225e3caf9d63d515c134ebc45aa14bd113cd0 TODO.md]],
        [[filename TODO.md]],
        [[	    * Git blame]],
        [[e6999ee62b24f3f8d74f481aaceba899e3d08767 7 7 4]],
        [[author Patrick Pichler]],
        [[author-mail <git@patrickpichler.dev>]],
        [[author-time 1703024252]],
        [[author-tz +0100]],
        [[committer Patrick Pichler]],
        [[committer-mail <git@patrickpichler.dev>]],
        [[committer-time 1703024283]],
        [[committer-tz +0100]],
        [[summary docs: add more todos]],
        [[previous b86c8625d6686af62e6396309e8a4fdac3623574 TODO.md]],
        [[filename TODO.md]],
        [[	]],
        [[e6999ee62b24f3f8d74f481aaceba899e3d08767 8 8]],
        [[	* Run github action for testing]],
        [[e6999ee62b24f3f8d74f481aaceba899e3d08767 9 9]],
        [[	]],
        [[e6999ee62b24f3f8d74f481aaceba899e3d08767 10 10]],
        [[	* Provide help pages]],

      })

      vim.print(vim.inspect({ lines, commits }))
    end)
  end)
end)
