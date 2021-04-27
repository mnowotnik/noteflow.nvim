
local F = require('plenary.functional')
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
	local default_opts = {
		vault_dir = nil,
		templates_dir = DEFAULT_TMPL_DIR,
		daily_dir = DEFAULT_DAILY_DIR,
		daily_template = nil,
		default_template = nil,
		syntax = {
			wikilink = true,
			todo = true
		},
		on_open = function() end,
		update_modified_on_save = true,
		make_note_slug = nil,
		make_daily_slug = nil,
	}
	opts = vim.tbl_deep_extend('keep', {}, opts)
	opts = vim.tbl_deep_extend('keep', opts, default_opts)
	for name,val in pairs(opts) do
		config[name] = val
	end
end

function config.find_command(opts)
  opts = opts or {}
  local args = {'rg', '--files', '-tmd'}
  local ignore_fp = utils.from_paths(config.vault_dir, '.noteflowignore')
  if ignore_fp:exists() then
    table.insert(args, '--ignore-file')
    table.insert(args, ignore_fp:absolute())
  end
  table.insert(args, opts.dir or '.')
  return args
end

function config.grep_command(opts)
  assert(opts)
  assert(opts.prompt)
  local args =  {'rg','-tmd', '--vimgrep', '-i', '-F', opts.prompt }
  local ignore_fp = utils.from_paths(config.vault_dir, '.noteflowignore')
  if ignore_fp:exists() then
    table.insert(args, '--ignore-file')
    table.insert(args, ignore_fp:absolute())
  end
  table.insert(args, opts.dir or '.')
  return args
end

return setmetatable(config, mt)
