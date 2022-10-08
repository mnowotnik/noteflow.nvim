local path = require('plenary.path')
local Job = require('plenary.job')

local utils = require('noteflow.utils')
local note = require('noteflow.notes')
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

local cache = {
  notes = {},
  notes_list = {}
}

local already_run = false

function mt:initialized()
  return already_run
end

function mt:by_title(title)
  for _,meta in pairs(self.notes) do
    if meta.title == title then return meta end
  end
  return nil
end

mt.refresh = utils.async(function(_, opts)
  opts = opts or {}
  local tmpl_dir = config.templates_dir
  if not already_run and not opts.silent then
    vim.cmd('echo "Refreshing note cache for the first time..."')
  end
  local processing = 0
  local processed = 0
  local args = config.find_command()
  local vault_dir = config.vault_dir
  local new_notes = {}
  local new_notes_list = {}
  local notes = cache.notes
  local cor = coroutine.running()
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
      if notes[fn] then
        mt_time = get_mt_time(fn)
        local meta = notes[fn]
        if meta.mt_time == mt_time then
          if opts.on_insert then opts.on_insert(meta) end
            new_notes[fn] = meta
            table.insert(new_notes_list, meta)
          return
        end
      end
      processing = processing + 1
      path:new(fn):read(function(text)
        local meta = note.parse_note(text_iterator(text), fn)
        meta.mt_time = mt_time or get_mt_time(fn)
        new_notes[fn] = meta
        table.insert(new_notes_list, meta)
        if opts.on_insert then pcall(opts.on_insert,meta) end
        processed = processed + 1
        if processed >= processing then
          cache.notes = new_notes
          cache.notes_list = new_notes_list
          utils.resume(cor)
        end
      end)
    end,
    on_stderr = function(error)
      print('Error while indexing notes: ' .. error)
    end,
    on_exit = function()
      if processing == 0 then
        cache.notes = new_notes
        utils.resume(cor)
      end
    end
  }
  job:start()
  already_run = true
  coroutine.yield()
end)

return setmetatable(cache, mt)
