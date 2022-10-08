local finders = require('telescope.finders')
local Job = require('plenary.job')
local make_entry = require('telescope.make_entry')

local cache = require('noteflow.cache')
local utils = require('noteflow.utils')

local parse_tags_prompt = utils.parse_tags_prompt
local startswith = utils.startswith

local function note_has_any_of_tags(note, tags)
  if #note.tags == 0 then return false end

  for _, tag in ipairs(tags) do
    for _, note_tag in pairs(note.tags) do
      if startswith(note_tag, tag) then
          return true
      end
    end
  end
  return false
end

local M = {}

function M.note_finder()
  local entry_maker = function(note)
    local tag_display = table.concat(
      vim.tbl_map(function(tag) return '#' .. tag end, note.tags), ' ')
    return {
      display = note.title .. ' ' .. tag_display,
      ordinal = note.title .. ' ' .. tag_display,
      value = note.path }
  end
  local supplier = function(prompt)
    local tags, _ = parse_tags_prompt(prompt)
    if #tags == 0 then
      return cache.notes_list
    end

    local result = {}
    for _, note in pairs(cache.notes_list) do
      if note_has_any_of_tags(note, tags) then
        table.insert(result, note)
      end
    end
    return result
  end
  return finders.new_dynamic({fn=supplier, entry_maker=entry_maker})
end

function M.note_finder_old(opts)
  opts = opts or {}
  local fzf_args = {'--delimiter', ':', '--with-nth', '-1', '--filter'}
  local fzf_job

  local find = function(finder, raw_prompt, process_result, process_complete)
    local tags, prompt = parse_tags_prompt(raw_prompt)

    fzf_job = Job:new{
      command = 'fzf',
      args = vim.tbl_flatten({fzf_args, prompt or ""}),
      maximum_results = finder.maximum_results,
      enable_recording = false,

      on_stdout = function(_, line, _)
        if not line or line == "" then return end
        local fn, title = unpack(vim.split(line, ':'))
        local note = cache.notes[fn]
        if #tags > 0 and #note.tags == 0 then return end
        for _, tag in ipairs(tags) do
          local found_tag = false
          for _, note_tag in pairs(note.tags) do
            if startswith(note_tag, tag) then
              found_tag = true
              break
            end
          end
          if not found_tag then return end
        end
        if type(note.tags) == "table" then
          local tag_display = table.concat(vim.tbl_map(
            function(tag) return '#' .. tag end, note.tags), ' ')
          process_result({
            display = title .. '\t' .. tag_display,
            ordinal = title,
            value = fn
          })
          return
        end
        process_result({display = title, ordinal = title, value = fn})
      end,
      on_stderr = function(_, error, _) utils.log_error('Error running fzf', error) end,

      on_exit = function() process_complete() end
    }
    fzf_job:start()
    for fn, val in pairs(cache.notes) do fzf_job:send(fn .. ':' .. val.title .. '\n') end
    fzf_job.stdin:write('\n', function() fzf_job.stdin:close() end)
  end

  return setmetatable({
    maximum_results = opts.maximum_results,
  }, {
    __call = function(finder, prompt, process_result, process_complete)
      if fzf_job then
          fzf_job:close(true)
      end
      -- local scheduler = require("plenary.async").util.scheduler
      cache:refresh()
      find(finder, prompt, process_result, process_complete)
      while true do find(coroutine.yield()) end
    end
  })
end

function M.fzf_finder(opts)
  assert(opts)
  assert(opts.results)
  local fzf_args = {'--filter'}
  local entry_maker = opts.entry_maker or make_entry.gen_from_string()

  local find = function(finder, raw_prompt, process_result, process_complete)
    local tags, prompt = parse_tags_prompt(raw_prompt)

    local fzf_job = Job:new{
      command = 'fzf',
      args = vim.tbl_flatten({fzf_args, prompt or ""}),
      maximum_results = finder.maximum_results,
      enable_recording = false,
      on_stdout = function(_, line, _)
        process_result(entry_maker(line))
      end,
      on_stderr = function(_, error, _) utils.log_error('Error running fzf', error) end,
      on_exit = function() process_complete() end
    }
    fzf_job:start()
    for _, val in ipairs(opts.results) do fzf_job:send(val .. '\n') end
    fzf_job.stdin:write('\n', function() fzf_job.stdin:close() end)
  end

  local obj = setmetatable({
    maximum_results = opts.maximum_results,
    close = function() end
  }, {
    __call = coroutine.wrap(function(...)
      cache:refresh()
      find(...)
      while true do find(coroutine.yield()) end
    end)
  })

  return obj
end

function M.two_stage_file_finder(opts)
  -- FIXME: switch to finders.new_job
  return finders._new{
    fn_command = function(_, prompt)
      if opts.min_characters then
        if #prompt < opts.min_characters then return {command = 'true'} end
      end
      local grep_args = opts.grep_args_maker(prompt)
      local find_args = opts.find_args_maker(prompt)
      return {
        writer = Job:new{command = grep_args[1], args = vim.list_slice(grep_args, 2), cwd = opts.cwd},
        command = find_args[1],
        args = vim.list_slice(find_args,2)
      }
    end,
    entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
  }
end

return M
