local path = require('plenary.path')

function jump_to_word(word)
  word = word:gsub('/', '\\\\/')
	vim.cmd([[execute "normal /]] .. word .. [[\<cr>"]])
end

function open_file(fn)
	local p = path:new(require('noteflow.config').vault_path(), fn):absolute()
	vim.cmd("e " .. p)
end

function close_file(fn)
	vim.cmd("bdelete " .. fn)
end

function close_last_file()
	vim.cmd("bd!")
end

function save_last_file()
	vim.cmd("w")
end

local by_title_cache = {}

function filename_by_title(title)
	if by_title_cache[title] then
		return by_title_cache[title]
	end
	local dir = require('noteflow.config'):vault_path()
	local path = require('plenary.path')
	local fns = require('plenary.scandir').scan_dir(dir)
	for _,fn in ipairs(fns) do
		local basename = vim.fn.fnamemodify(fn, ':t')
		if not basename:find('from') then
			local data = path:new(fn):read()
			data = data:lower()
			if data:find(title:lower()) then
				by_title_cache[title] = fn
				return fn
			end
		end
	end
end

function set_vault_path_to(dir_in_fixture)
	local path = require('plenary.path')
	local p = path:new(vim.fn.expand('%:p:h'), 'tests', 'plenary', 'fixtures', dir_in_fixture):absolute()
	vim.g.noteflow_vault_path = p
end

function get_vault_path()
  return vim.g.noteflow_vault_path
end

function assert_in_telescope_prompt()
  assert.are.same('TelescopePrompt', vim.bo.ft)
end

function assert_not_in_telescope_prompt()
  assert.are_not.same('TelescopePrompt', vim.bo.ft)
end

function path_concat(...)
  return path:new(...):absolute()
end

function path_in_vault(...)
  return path:new(get_vault_path(),...):absolute()
end
