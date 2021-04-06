require('tests.plenary.utils')

local config = require('noteflow.config')
local PWD = require('os').getenv('PWD')

describe("config.vault_path", function()

  it("should raise an error if not set", function()
    assert.falsy(pcall(function() return config.vault_path end))
  end)

  it("could be set manually", function()
    config.vault_path = PWD
  end)

  it("should raise an error if set to an nonexistant path", function()
    assert.falsy(pcall(function() config.vault_path = '/foo/bar/baz' end))
  end)
end)

describe("config.setup()", function()
  it("requires vault_path option to be set", function()
    assert.falsy(pcall(config.setup, {}))
    assert.truthy(pcall(config.setup, {vault_path = PWD}))
  end)

  it("requires vault_path option to be set", function()
    assert.falsy(pcall(config.setup, {}))
    assert.truthy(pcall(config.setup, {vault_path = PWD}))
  end)

  it("requires templates_path to exist", function()
    assert.falsy(pcall(config.setup, {vault_path = PWD, templates_path='/foo/bar/baz'}))
    assert.truthy(pcall(config.setup,
      {vault_path = abs_fixtures_path('config'),
      templates_path= abs_fixtures_path('config/my_templates')}))
    assert.is.equal(config.templates_path, abs_fixtures_path('config/my_templates'))
  end)

  it("should accept a templates path relative to the vault path", function()
    assert.falsy(pcall(config.setup, {vault_path = PWD, templates_path='baz'}))
    assert.truthy(pcall(config.setup,
      {vault_path = abs_fixtures_path('config'),
      templates_path= 'my_templates'}))
    assert.is.equal(config.templates_path, abs_fixtures_path('config/my_templates'))
  end)

  it("sets templates_path to Templates folder inside vault_path by default", function()
    assert.truthy(pcall(config.setup,
      {vault_path = abs_fixtures_path('config')}))
    assert.is.equal(config.templates_path, abs_fixtures_path('config/Templates'))
  end)
end)
