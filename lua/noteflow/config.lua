
local path = require('plenary.path')
local utils = require('noteflow.utils')
local assert_fmt = utils.assert_fmt
local _data = {}

local DEFAULT_TMPL_DIR = 'Templates'
local DEFAULT_DAILY_DIR = 'Daily'
local VAULT_DIR = 'vault_dir'
local TEMPLATES_DIR = 'templates_dir'
local DAILY_DIR = 'daily_dir'
local CONFIG_DIR_PATHS = {VAULT_DIR, TEMPLATES_DIR, DAILY_DIR}

local mt = {}
local config = {}

function mt.__index(_, key)
  if key == VAULT_DIR then
    assert(_data[VAULT_DIR], "Noteflow vault path not set!")
    return _data[VAULT_DIR]
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
  if name ~= VAULT_DIR and not p:is_absolute() then
    p = path:new(config[VAULT_DIR], p)
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
    assert_fmt(val, "Value for %s is nil!", key)
    _data[key] = make_path(key, val, true)
  else
    _data[key] = val
  end
end

function config.setup(opts)
  config.make_note_slug = opts.make_note_slug
  config.make_daily_slug = opts.make_daily_slug
  config.vault_dir = opts.vault_dir
  config.daily_template = opts.daily_template
  config.default_template = opts.default_template
  if opts.templates_dir then
    config.templates_dir = opts.templates_dir
  else
    _data.templates_dir = make_path(TEMPLATES_DIR, DEFAULT_TMPL_DIR, false)
  end

  if opts.daily_dir then
    config.daily_dir = opts.daily_dir
  else
    _data.daily_dir = DEFAULT_DAILY_DIR
  end
end

return setmetatable(config, mt)
