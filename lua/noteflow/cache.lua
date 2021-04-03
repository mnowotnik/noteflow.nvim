local scandir = require('plenary.scandir')
local path = require('plenary.path')

local utils = require('noteflow.utils')
local notes = require('noteflow.notes')
local config = require('noteflow.config')
local log = utils.log

local text_iterator = utils.text_iterator

local luv = vim.loop

local get_mt_time = function(fn)
    local stat = luv.fs_lstat(fn)
    return stat.mtime.sec
end

local mt = {}
mt.__index = mt

local cache = {}

local already_run = false

function mt:refresh(opts)
  opts = opts or {}
  local completed = false
  local tmpl_path = config.templates_dir
  if not already_run then
    vim.cmd('echon "Refreshing note cache for the first time..."')
  end
  local processing = 0
  local processed = 0
  scandir.scan_dir(config:vault_path(), {
    search_pattern='.+%.md$',
    on_insert = function(fn)
      -- exclude templates dir
      if tmpl_path and fn:sub(1,#tmpl_path) == tmpl_path then
        return
      end
      local mt_time = nil
      if cache[fn] then
        mt_time = get_mt_time(fn)
        local meta = cache[fn]
        if meta.mt_time == mt_time then
          if opts.on_insert then opts.on_insert(meta) end
          return
        end
      end
      processing = processing + 1
      path:new(fn):read(function(text)
         local meta = notes.parse_note(text_iterator(text), fn)
         meta.mt_time = mt_time or get_mt_time(fn)
         cache[fn] = meta
         if opts.on_insert then opts.on_insert(meta) end
         processed = processed + 1
      end)
    end,
  })
  vim.wait(5000, function()
    return processed >= processing
  end,10,true)
  if not already_run then
    already_run = true
		vim.cmd('echon "\rRefreshing note cache for the first time... done!"')
  end
end

return setmetatable(cache, mt)
