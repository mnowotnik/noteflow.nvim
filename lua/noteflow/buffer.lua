

local utils = require('noteflow.utils')

local wikilinks_iterator = utils.wikilinks_iterator

local M = {}
local BOUNDARY_VIM_PAT = '\\(\\]\\]\\|\\[\\[\\)'

function M.find_wikilink_under_cursor(line)
	if not line then
		line = vim.fn.getline('.')
	end

	local curpos = vim.fn.col('.')
	for w in wikilinks_iterator(line) do
    if w.startpos <= curpos and w.endpos >= curpos then
			return w
		end
	end
end

function M.find_wikilink_open_start(line, curpos)
  -- TODO try to use vim api
  local line_to_cur = line:sub(1,curpos-1)
  local o_start,o_end,match = utils.vim_find_rev(line_to_cur, BOUNDARY_VIM_PAT, 2)
  if not match or match == ']]' then return nil end
  local startpos = string.find(line,'%]%]', curpos)
  if startpos and startpos < curpos then return nil end
  return o_start, o_end
end

function M.show_input_dialog(message, callback)
  local plenary_window = require('plenary.window.float').percentage_range_window(0.5, 0.2)
  vim.api.nvim_buf_set_option(plenary_window.bufnr, 'buftype', 'prompt')
  vim.fn.prompt_setprompt(plenary_window.bufnr, message)
  vim.fn.prompt_setcallback(plenary_window.bufnr, function(text)
    vim.api.nvim_win_close(plenary_window.win_id, true)
    vim.schedule(function()
      callback(text)
    end)
  end)

  vim.cmd [[startinsert]]
end

function M.current_buffer_iterator()
  local mt = {
    __call = function(s)
      local line = s.lines[s.i]
      if line == nil then return end
      s.i = s.i + 1
      return line
    end,
  }

  local obj = {
    lines = vim.fn.getline(1, "$"),
    i = 1
  }
  return setmetatable(obj, mt)
end


function M.save_meta_in_current_buffer(meta_str, boundary, fm_start, fm_end)
  local view = vim.fn.winsaveview()
  if fm_end then
    local cut_start = fm_start + 1
    local cut_end = fm_end - 1
    if cut_start <= cut_end then
      vim.cmd( cut_start .. ',' .. cut_end .. 'd _')
    end
    vim.fn.setpos('.', {0,0,0,fm_start})
    vim.fn.execute("normal A\n" .. meta_str)
  else
    vim.fn.setpos('.', {0,0,0,1})
    vim.fn.execute(utils.interp("normal i${b}\n${fm}\n${b}", {b=boundary,fm=meta_str}))
  end
  vim.cmd'stopinsert'
  vim.fn.winrestview(view)
end


return M
