
local F = require('plenary.functional')

local M = {
  -- log = require('plenary.log').new({
  --   use_file = false,
  --   level = require('os').getenv('DEBUG_NOTEFLOW') and 'debug' or 'info'
  -- })
}

local log = {
  level = require('os').getenv('DEBUG_NOTEFLOW') and 'debug' or 'info'
}

function log.info(msg)
  print(msg)
end

function log.debug(msg)
  if log.level ~= 'debug' then
    return
  end
  print(msg)
end

function log.fmt_debug(msg, ...)
  if log.level ~= 'debug' then
    return
  end
	local args = {...}
	local vars = {}
	for _,arg in ipairs(args) do
		table.insert(vars, vim.inspect(arg))
	end
	print(msg:format(unpack(vars)))
end

M.log = log

function M.wikilinks_iterator(line)
  local parse_wikilink = function(wikilink)
    local title, desc = string.match(wikilink, '(.+[^%s])%s*|(.+)')
    if not title then
      wikilink = vim.trim(wikilink)
      if wikilink:sub(1,1) == '|' then
        return nil, wikilink
      end
    end
    return title or wikilink, desc
  end

  local iter = string.gmatch(line, '()(%[%[.+%]%])()')
  return function()
    local startpos, match, endpos = iter()
    if not match then return end
    local link_content = string.match(match, '%[%[%s*([^%s].+[^%s])%s*%]%]')
    local r = {startpos=startpos,endpos=endpos-1}
    if link_content then
      local link, description = parse_wikilink(link_content)
      r.link = link
      r.description = description
    end
    return r
  end
end

function M.startswith(s, with)
  return string.sub(s,1,#with)==with
end

function M.at(lst,i)
  if i < 0 then
    if #lst > 1 then
      return lst[#lst + i + 1]
    end
    if #lst == 1 then return lst[1] else return nil end
  end
  return lst[i]
end

function M.vim_find_rev(s, pat, len)
  local startpos = vim.fn.match(s:reverse(), pat)
  if startpos == -1 then return end
  startpos = startpos + 1 -- to 1-indexed
  local r = {#s - startpos + 1 , #s - startpos + len + 1}
  return r[1],r[2],s:sub(r[1],r[2])
end

function M.set_to_arr(set)
  local arr = {}
  for val,_ in pairs(set) do
    table.insert(arr, val)
  end
  return arr
end

function M.arr_to_set(arr)
  local set = {}
  for _,val in ipairs(arr) do
    set[val] = 1
  end
  return set
end

function M.text_iterator(text)
  return vim.gsplit(text, '\r?\n')
end

function M.open_file(p, opts)
  opts = opts or {}
  vim.cmd(':edit' .. p)
  if opts.move_to_end then
    vim.cmd(':normal G$')
  end
end

-- http://lua-users.org/wiki/StringInterpolation
function M.interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

function M.current_datetime()
  return vim.fn.strftime('%FT%T')
end

function M.current_date()
  return vim.fn.strftime('%F')
end

function M.log_error(line, cause)
  if cause then
    print('noteflow: ' .. line .. '. Caused by: ' .. cause)
  else
    print('noteflow: ' .. line)
  end
end

function M.with_vim(cb, opts)
  opts = opts or {}
  local reg_val
  local cur_pos
  if opts.restore_register then
    reg_val = vim.fn.getreg('"')
  end
  if opts.retore_cursor then
    cur_pos = vim.fn.getpos('.')
  end

  cb(opts[1])

  if opts.restore_register then
    vim.fn.setreg('"', reg_val)
  end
  if opts.restore_cursor then
    vim.fn.setpos('.', cur_pos)
  end
end

function M.vim_exec(opts)
  M.with_vim(vim.fn.execute, opts)
end

function M.parse_tags_prompt(prompt)
  if prompt == '#' then return {}, "" end
  local tags = {}
  for tag in string.gmatch(prompt, '#([%w%-]+)') do
    table.insert(tags,tag)
  end
  if #tags ~= 0 then
    prompt = vim.trim(prompt:gsub('#[%w%-]+', ''))
  end
  if prompt:sub(#prompt-1,#prompt) == ' #' then
    return tags, prompt:sub(1,#prompt-1)
  end
  return tags, prompt
end

function M.assert_fmt(cond, msg, ...)
	if cond then return end
	local inspected = F.map(function(x) return vim.inspect(x) end, {...})
	assert(cond, msg:format(unpack(inspected)))
end

return M

