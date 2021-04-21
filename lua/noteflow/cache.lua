local path = require('plenary.path')
local Job = require('plenary.job')

local utils = require('noteflow.utils')
local notes = require('noteflow.notes')
local config = require('noteflow.config')
local log = utils.log

local text_iterator = utils.text_iterator
local from_paths = utils.from_paths

local luv = vim.loop

local get_mt_time = function(fn)
  local stat = luv.fs_lstat(fn)
  return stat.mtime.sec
end

local mt = {}
mt.__index = mt

local cache = {}

local already_run = false

function mt:by_title(title)
  for _,note in pairs(self) do
    if note.title == title then return note end
  end
end

function mt:refresh(opts)
  opts = opts or {}
  local tmpl_dir = config.templates_dir
  if not already_run then
    vim.cmd('echo "Refreshing note cache for the first time..."')
  end
  local processing = 0
  local processed = 0
  local args = config.find_command()
  local vault_dir = config.vault_dir
  local job = Job:new{
    command =  args[1],
    args = vim.list_slice(args, 2),
    cwd = vault_dir,
    on_stdout = function(_,fn,_)
      fn = from_paths(vault_dir, fn):absolute()
      if not fn or fn == "" then return end
      if tmpl_dir and fn:sub(1,#tmpl_dir) == tmpl_dir then
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
    end

  }
  job:start()
  job:wait(3000, 100)
  vim.wait(5000, function()
    return processed >= processing
  end,100,true)
  if not already_run then
    -- clear command line
    vim.fn.execute[[normal \\<C-l>:\\<C-u>]]
    already_run = true
  end
end

return setmetatable(cache, mt)
