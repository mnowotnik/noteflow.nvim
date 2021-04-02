require('tests.plenary.utils')

set_vault_path_to('follow_wikilink')

local attempt_to_jump = function(initial_file, move_to_word, modifier, modifier_args)
    open_file(initial_file)
    jump_to_word(move_to_word)
    local before_fn = vim.fn.expand('%:p')
    if modifier then
      modifier(unpack(vim.tbl_flatten({modifier_args})))
    end
    vim.cmd[[NoteflowFollowWikilink]]
    return before_fn
end


local move_cursor = function(x)
  local dir = 'l'
  if x < 0 then
    dir = 'h'
    x = -x
  end
  vim.cmd("normal " .. x .. dir)
end

describe('Following wikilink', function()

  after_each(close_all_buffers)

  describe('should open a note', function()

    it('if cursor is on the second leftmost [ character', function ()
      local title = "Same dir fm title"
      attempt_to_jump("from.md", title, move_cursor, -1)
      assert.are.same(filename_by_title(title), vim.fn.expand('%:p'))
    end)

    it('if cursor is on the leftmost [ character', function ()
      local title = "Same dir fm title"
      attempt_to_jump("from.md", title, move_cursor, -2)
      assert.are.same(filename_by_title(title), vim.fn.expand('%:p'))
    end)

    it('if cursor is on the label', function ()
      attempt_to_jump("from.md", "Label and link")
      assert.are.same(filename_by_title("Same dir fm title"), vim.fn.expand('%:p'))
    end)

    it('if cursor is on the pipe character', function ()
      attempt_to_jump("from.md", "Label and link", move_cursor, -1)
      assert.are.same(filename_by_title("Same dir fm title"), vim.fn.expand('%:p'))
    end)

    local test_jumping_to = function(opened_note, title)
      attempt_to_jump(opened_note, title)
      assert.are.same(filename_by_title(title), vim.fn.expand('%:p'))
    end

    it('in the same dir when a title is in the frontmatter', function()
      test_jumping_to("from.md", "Same dir fm title")
    end)

    it('in the same dir when a title is in the header', function()
      test_jumping_to("from.md", "Same dir h1 title")
    end)

    it('in the same dir when a mixed case title is in the header', function()
      test_jumping_to("from.md", "by h1 title case insensitive")
    end)

    it('in the same dir when a mixed case title is in the frontmatter', function()
      test_jumping_to("from.md", "by fm title case insensitive")
    end)

    it('when the title has non-ascii characters', function()
      test_jumping_to("from.md", "🤟😀ö")
    end)

    it('by filename if title is missing', function()
      local stem = "By_filename"
      attempt_to_jump("from.md", stem)
      assert.are.same(path_in_vault(stem .. ".md"), vim.fn.expand('%:p'))
    end)

    it('by capitalized filename if title is missing', function()
      local stem = "By_filename"
      attempt_to_jump("from.md", stem)
      assert.are.same(path_in_vault(stem .. ".md"), vim.fn.expand('%:p'))
    end)

    it('by capitalized filename if title is missing and wikilink is lowercase', function()
      local stem = "by_filename"
      attempt_to_jump("from.md", stem)
      assert.are.same(path_in_vault("By_filename" .. ".md"), vim.fn.expand('%:p'))
    end)

    it('by capitalized filename if title is missing and wikilink has mixed case', function()
      local stem = "by_Filename"
      attempt_to_jump("from.md", stem)
      assert.are.same(path_in_vault("By_filename" .. ".md"), vim.fn.expand('%:p'))
    end)

    it('when its title is quoted in the frontmatter', function()
      test_jumping_to("from.md", "quoted title in fm")
    end)

    it('when its title is surrounded by whitespace in the frontmatter', function()
      test_jumping_to("from.md", "whitespace title fm")
    end)

    it('when its title is surrounded by whitespace in the header', function()
      test_jumping_to("from.md", "whitespace title h1")
    end)

    it('when the note is in different directory and its title is in the frontmatter', function()
      test_jumping_to("cat1/cat1_from.md", "diff dir fm title")
    end)

    it('when the note is in a different directory and its title is in the header', function()
      test_jumping_to("cat1/cat1_from.md", "diff dir h1 title")
    end)

    it('when the note is in the same directory one level deep in a vault and the title is in the fm', function()
      test_jumping_to("cat1/cat1_from.md", "cat1/same dir fm title")
    end)

    it('when the note is in the same directory one level deep in a vault and the title is in the h1', function()
      test_jumping_to("cat1/cat1_from.md", "cat1/same dir h1 title")
    end)

  end)
  describe('should not open a note', function()
    it('if cursor is not on wikilink', function()
      local before_fn = attempt_to_jump("from.md", "Same dir fm title", jump_to_word, "From")
      assert.are.same(before_fn, vim.fn.expand('%:p'))
    end)

    it('if cursor is one char to the left of a wikilink', function()
      local before_fn = attempt_to_jump("from.md", "Same dir fm title", move_cursor, -3)
      assert.are.same(before_fn, vim.fn.expand('%:p'))
    end)

    it('if cursor is one char to the right of a wikilink', function()
      local before_fn = attempt_to_jump("from.md", "Same dir fm title", vim.cmd,"normal f]2l")
      assert.are.same(before_fn, vim.fn.expand('%:p'))
    end)

    it('in a file without an extension', function()
      local stem = "by_filename_no_ext"
      attempt_to_jump("from.md", stem)
      assert_in_telescope_prompt()
    end)

    it('in a file with an unsupported extension', function()
      local stem = "by_filename_other_ext"
      attempt_to_jump("from.md", stem)
      assert_in_telescope_prompt()
    end)
  end)
  describe("should not create a new note", function()
    it('when wikilink contains only a label', function ()
      attempt_to_jump("from.md", "Only label")
      assert_not_in_telescope_prompt()
    end)
  end)
end)
