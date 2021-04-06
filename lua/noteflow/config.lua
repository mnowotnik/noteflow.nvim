
local path = require('plenary.path')
local utils = require('noteflow.utils')
local assert_fmt = utils.assert_fmt
local _data = {}

local DEFAULT_TMPL_DIR = 'Templates'
local VAULT_PATH = 'vault_path'
local TEMPLATES_PATH = 'templates_path'
local CONFIG_DIR_PATHS = {VAULT_PATH, TEMPLATES_PATH}

local mt = {}
local config = {}

function mt.__index(_, key)
  if key == "vault_path" then
    assert(_data.vault_path, "Noteflow vault path not set!")
    return _data.vault_path
  end

  return _data[key]
end

local make_path = function(name, p_str, assert_exists)
  p_str = vim.trim(p_str)
  if not p_str or p_str == "" then
    return
  end
  local p = path:new(path:new(p_str):expand())
  -- assume rest of the paths may be relative to the vault path
  if name ~= VAULT_PATH and not p:is_absolute() then
    p = path:new(config.vault_path, p)
  end
  if not p:exists() or not p:is_absolute() then
    if assert_exists then
      assert_fmt(false, "%s: %s doesn't exist!", name, p.filename)
    else
      return
    end
  end
  return p.filename
end

function mt.__newindex(_, key, val)
  if vim.tbl_contains(CONFIG_DIR_PATHS, key) then
    _data[key] = make_path(key, val, true)
  else
    _data[key] = val
  end
end

function config.setup(opts)
  config.make_note_slug = opts.make_note_slug
  config.make_daily_slug = opts.make_daily_slug
  config.vault_path = opts.vault_path
  if opts.templates_path then
    config.templates_path = opts.templates_path
  else
    _data[TEMPLATES_PATH] = make_path(TEMPLATES_PATH, DEFAULT_TMPL_DIR, false)
  end
end

return setmetatable(config, mt)
