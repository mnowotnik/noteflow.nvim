
local path = require('plenary.path')
local config = {}

local DEFAUTLT_TMPL_DIR = 'Templates'

function config:setup(opts)
  local templates_dir
  if opts.templates_path then
    templates_dir = path:new(opts.templates_path)
  else
    templates_dir = path:new(self:vault_path(), DEFAUTLT_TMPL_DIR)
  end
  templates_dir = templates_dir:expand()
  self.templates_dir = templates_dir
end

function config:vault_path()
  return path:new(vim.g.noteflow_vault_path):expand() or ""
end

return config
