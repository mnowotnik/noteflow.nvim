require('tests.plenary.utils')

set_vault_path_to('create_note/empty_vault')

describe("Note file basename", function()

  it("should be created directly from title by default", function()
    local notes = require('noteflow.notes')
    local fn = notes._make_note_path('FooFolder', 'Foo title'):absolute()
    assert.are.same(('%s/%s/%s'):format(get_vault_path(), 'FooFolder', 'Foo title.md'), fn)
  end)

  it("should be created using a user hook if available", function()
    local notes = require('noteflow.notes')
    require('noteflow.config').make_note_slug = function(_) return 'Not bar' end
    local fn = notes._make_note_path('FooFolder', 'Bar'):absolute()
    assert.are.same(('%s/%s/%s'):format(get_vault_path(), 'FooFolder', 'Not bar.md'), fn)
  end)
end)
