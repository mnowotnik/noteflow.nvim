

local utils = require('noteflow.utils')

local wikilinks_iterator = utils.wikilinks_iterator

local M = {}

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
  local line_to_cur = line:sub(1,curpos-1)
  local startpos = line_to_cur:find('(%[%[)[^%[]*$')
	if startpos then
		return startpos,startpos+1
	end
	return
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
    -- lines = vim.fn.getline(1, "$"),
    lines = vim.api.nvim_buf_get_lines(0,0,-1,true),
    i = 1
  }
  return setmetatable(obj, mt)
end


function M.save_meta_in_current_buffer(lines, boundary, fm_start, fm_end)
	print(fm_start,fm_end)
  local view = vim.fn.winsaveview()
  if fm_end then
		vim.api.nvim_buf_set_lines(0,fm_start,fm_end-1,true,lines)
  else
		vim.api.nvim_buf_set_lines(0,0,0,true,vim.tbl_flatten({boundary,lines,boundary}))
  end
  vim.fn.winrestview(view)
end


return M
