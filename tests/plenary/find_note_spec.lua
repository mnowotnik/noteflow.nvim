require('tests.plenary.utils')

set_vault_path_to('find_note')

local cache = require('noteflow.cache')

describe("when set in .noteflowignore cache ignores", function()
  cache:refresh()
  it("directory", function()
    assert.falsy(cache:by_title("ignored"))
  end)
  it("file", function()
    assert.falsy(cache:by_title("ignored note"))
    assert.truthy(cache:by_title("unignored note"))
  end)
  vim.wait(100)
end)

describe("cache find notes", function()
  it("in a vault dir", function()
    assert.truthy(cache:by_title("xyz1"))
  end)
  it("in a nested dir inside vault dir", function()
    assert.truthy(cache:by_title("bar1"))
    assert.truthy(cache:by_title("foo1"))
  end)
end)


