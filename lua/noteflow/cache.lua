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

log.level = "debug"
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
  scandir.scan_dir_async(config:vault_path(), {
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
      path:new(fn):read(function(text)
         local meta = notes.parse_note(text_iterator(text), fn)
         meta.mt_time = mt_time or get_mt_time(fn)
         cache[fn] = meta
         if opts.on_insert then opts.on_insert(meta) end
      end)
    end,
    on_exit = function()
      if opts.on_exit then opts.on_exit() end
      completed = true
    end
  })

  if opts.wait_for_completion then
    log.debug('Waiting for cache refresh')

    vim.wait(5000, function()
      return completed
    end,10,true)
    -- FIXME change to fmt_debug after fix in plenary is merged
    log.debug('Waiting for cache ended. Indexing completed: ' .. tostring(completed))
  end
  if not already_run then
    already_run = true
		vim.cmd('echon "\rRefreshing note cache for the first time... done!"')
  end
end

return setmetatable(cache, mt)
