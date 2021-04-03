local path = require('plenary.path')

DATETIME_PATTERN = '%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d'

function jump_to_word(word)
  word = word:gsub('/', '\\\\/')
	vim.cmd([[execute "normal /]] .. word .. [[\<cr>"]])
end

function open_file(fn)
	local p = path:new(get_vault_path(), fn):absolute()
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

function close_all_buffers()
  vim.cmd[[bufdo! bwipeout]]
end

function read_note_lines(rel_note_path)
  assert(rel_note_path)
  return path:new(get_vault_path(), rel_note_path):readlines()
end

function get_note_frontmatter(rel_note_path)
  local lines = read_note_lines(rel_note_path)
  assert.are.equal('---',lines[1], "Invalid frontmatter. Line 1:" .. rel_note_path)
  local r = {}
  local end_nr
  for idx,line in ipairs(lines) do
    if idx > 1 and line == '---' then
      end_nr = idx
      break
    end
    if idx > 1 then
      local split = vim.split(line, ': ')
      assert.is.equal(2, #split)
      table.insert(r, split)
    end
  end
  assert.is_not_nil(end_nr, "Invalid frontmatter. End not found: " .. rel_note_path)
  return r
end

function assert_matches_datetime_pattern(val)
  assert.truthy(string.match(val, DATETIME_PATTERN), val .. " not matching datetime pattern")
end
