require('tests.plenary.utils')

local config = require('noteflow.config')
local PWD = require('os').getenv('PWD')

describe("config.vault_dir", function()

  it("should raise an error if not set", function()
    assert.falsy(pcall(function() return config.vault_dir end))
  end)

  it("could be set manually", function()
    config.vault_dir = PWD
  end)

  it("should raise an error if set to an nonexistant path", function()
    assert.falsy(pcall(function() config.vault_dir = '/foo/bar/baz' end))
  end)
end)

describe("config.setup()", function()
  it("requires vault_dir option to be set", function()
    assert.falsy(pcall(config.setup, {}))
    assert.truthy(pcall(config.setup, {vault_dir = PWD}))
  end)

  it("requires vault_dir option to be set", function()
    assert.falsy(pcall(config.setup, {}))
    assert.truthy(pcall(config.setup, {vault_dir = PWD}))
  end)

  it("requires templates_dir to exist", function()
    assert.falsy(pcall(config.setup, {vault_dir = PWD, templates_dir='/foo/bar/baz'}))
    assert.truthy(pcall(config.setup,
      {vault_dir = abs_fixtures_path('config'),
      templates_dir= abs_fixtures_path('config/my_templates')}))
    assert.is.equal(config.templates_dir, abs_fixtures_path('config/my_templates'))
  end)

  it("should accept a templates path relative to the vault path", function()
    assert.falsy(pcall(config.setup, {vault_dir = PWD, templates_dir='baz'}))
    assert.truthy(pcall(config.setup,
      {vault_dir = abs_fixtures_path('config'),
      templates_dir= 'my_templates'}))
    assert.is.equal(config.templates_dir, abs_fixtures_path('config/my_templates'))
  end)

  it("sets templates_dir to Templates folder inside vault_dir by default", function()
    assert.truthy(pcall(config.setup,
      {vault_dir = abs_fixtures_path('config')}))
    assert.is.equal(config.templates_dir, abs_fixtures_path('config/Templates'))
  end)
end)
