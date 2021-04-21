require('tests.plenary.utils')

set_vault_path_to('update_modified')

local trigger_write_and_get_fm = function(fn)
  open_file(fn)
  vim.fn.append('$','foobar')
  vim.cmd[[write!]]
  return get_note_frontmatter(fn)
end

local assert_key_val = function(fm, nr, key, val_assertion)
  local t_key,val = unpack(fm[nr])
  assert.is.not_nil(val)
  assert.is.equal(key, t_key)
  if type(val_assertion) ~= 'function' then
    assert.is.equal(val_assertion, val)
  else
    val_assertion(val)
  end
end

describe("Saving note", function()

  after_each(function()
    vim.fn.system('git checkout ' .. vim.fn.bufname())
    close_all_buffers()
  end)
  describe('should add modified attribute', function()

    it("when a note has no frontmatter", function()
      local fm = trigger_write_and_get_fm('no_frontmatter.md')
      assert.is.equal(1, #fm)
      assert_key_val(fm, 1, 'modified', assert_matches_datetime_pattern)
    end)

    it("when a note has an empty frontmatter and a title in the header", function()
      local fm = trigger_write_and_get_fm('has_empty_frontmatter_title_h1.md')
      assert.is.equal(1, #fm)
      assert_key_val(fm, 1, 'modified', assert_matches_datetime_pattern)
    end)

    it("when a title is just under frontmatter", function()
      local fm = trigger_write_and_get_fm('title_just_under_fm.md')
      assert.is.equal(2, #fm)
      assert_key_val(fm, 1, 'modified', assert_matches_datetime_pattern)
      assert_key_val(fm, 2, 'type', 'Journal')
    end)

    it("when a note has only title in header", function()
      local fm = trigger_write_and_get_fm('no_frontmatter_title_h1.md')
      assert.is.equal(1, #fm)
      assert_key_val(fm, 1, 'modified', assert_matches_datetime_pattern)
    end)

    it("when a note has frontmatter and title in header", function()
      local fm = trigger_write_and_get_fm('has_frontmatter_title_h1.md')
      assert.is.equal(3, #fm)
      assert_key_val(fm, 1, 'ale', 'good')
      assert_key_val(fm, 2, 'modified', assert_matches_datetime_pattern)
      assert_key_val(fm, 3, 'type', 'Journal')
    end)

    it("when a note has a title in the frontmatter", function()
      local fm = trigger_write_and_get_fm('title_in_fm.md')
      assert.is.equal(2, #fm)
      assert_key_val(fm, 1, 'modified', assert_matches_datetime_pattern)
      assert_key_val(fm, 2, 'title', 'title in fm')
    end)

  end)

end)
