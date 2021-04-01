local make_entry = require('telescope.make_entry')
local Job = require('plenary.job')

local cache = require('noteflow.cache')
local utils = require('noteflow.utils')

local parse_tags_prompt = utils.parse_tags_prompt
local startswith = utils.startswith

local DEFAULT_FZF_ARGS = {'--delimiter',':','--with-nth','-1','--filter'}
local SCAN_DELAY_MS = 100

local M = {}

local IndexingFinder = {
  __call = function(f, ...) return f:_find(...) end,
  close = function() end
}
IndexingFinder.__index = IndexingFinder

function IndexingFinder:new(opts)
  opts = opts or {}

  local obj = setmetatable({
    cwd = opts.cwd,
    maximum_results = opts.maximum_results,
    entry_maker = make_entry.gen_from_string()
  }, self)

  obj._find = coroutine.wrap(function(_, _, _, _)
    cache:refresh({wait_for_completion=true})

    local scan_timer = nil

    while true do
      local finder, _, process_result, process_complete = coroutine.yield()
      -- FIXME ignore telescope prompt (second param) cause it has incorrect values

      local scan = function()

        local raw_prompt = vim.fn.getline('.'):sub(3)
        local tags,prompt = parse_tags_prompt(raw_prompt)

        local fzf_job = Job:new {
          command = 'fzf',
          args = vim.tbl_flatten({DEFAULT_FZF_ARGS, prompt or ""}),
          maximum_results = finder.maximum_results,
          enable_recording = false,

          on_stdout = function(_,line,_)
            if not line or line == "" then return end
            local fn, title = unpack(vim.split(line, ':'))
            local note = cache[fn]
            if #tags > 0 and #note.tags == 0 then
              return
            end
            for _,tag in ipairs(tags) do
              local found_tag = false
              for _,note_tag in pairs(note.tags) do
                if startswith(note_tag,tag) then
                  found_tag = true
                  break
                end
              end
              if not found_tag then return end
            end
            local tag_display = table.concat(vim.tbl_map(function(tag) return '#' .. tag end, note.tags),' ')
            process_result({
              display=title..'\t'..tag_display,ordinal=title,value=fn
            })
          end,
          on_stderr = function(_,error,_)
            utils.log_error('Error running fzf', error)
          end,

          on_exit = function()
            process_complete()
          end,
        }
        fzf_job:start()
        for fn,val in pairs(cache) do
          fzf_job:send(fn .. ':' .. val.title .. '\n')
        end
        fzf_job.stdin:write('\n', function()
          fzf_job.stdin:close()
        end)
      end

      -- delay scanning after last prompt update
      if scan_timer then
        scan_timer:close()
      end
      scan_timer = vim.loop.new_timer()
      scan_timer:start(SCAN_DELAY_MS,0,vim.schedule_wrap(function()
        scan()
        scan_timer = nil
      end))
    end
  end)
  return obj
end

function M.indexing_finder(opts)
  return IndexingFinder:new{opts}
end

function M.two_stage_file_finder(opts)
  -- FIXME: switch to supported API when available
  return finders._new {
    fn_command = function(_, prompt)
      if opts.min_characters then
        if #prompt < opts.min_characters then
          return {
            command = 'true'
          }
        end
      end
      local rg_args = opts.rg_args_maker(prompt)
      local fzf_args
      if opts.fzf_args_maker then
        fzf_args = opts.fzf_args_maker(prompt)
      else
        fzf_args = vim.tbl_flatten({DEFAULT_FZF_ARGS, prompt or ""})
      end
      return {
        writer = Job:new {
          command = 'rg',
          args = rg_args,
          cwd = opts.cwd
        },
        command = 'fzf',
        args = fzf_args
      }
    end,
    entry_maker = opts.entry_maker or make_entry.gen_from_file(opts),
  }
end

return M
