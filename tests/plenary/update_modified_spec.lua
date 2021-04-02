require('tests.plenary.utils')

set_vault_path_to('update_modified')

describe("Saving note", function()

  after_each(function()
    vim.fn.system('git checkout ' .. vim.fn.bufname())
    close_all_buffers()
  end)

  it("should add modified attribute when a note has no frontmatter", function()
    open_file("no_frontmatter.md")
    assert.truthy(string.match(vim.bo.filetype, 'noteflow'))
    vim.cmd[[write!]]
    local fm = get_note_frontmatter('no_frontmatter.md')
    assert.is.equal(1, #fm)
    local key, val = unpack(vim.split(fm[1], ': '))
    assert.are.equal(key, 'modified')
    assert.truthy(string.match(val, DATETIME_PATTERN), val .. " not matching datetime pattern")
  end)
end)
