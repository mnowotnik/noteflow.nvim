local path = require('plenary.path')

local yaml = require('noteflow.yaml')
local utils = require('noteflow.utils')
local config = require('noteflow.config')
local buffer = require('noteflow.buffer')

local wikilinks_iterator = utils.wikilinks_iterator
local startswith = utils.startswith
local at = utils.at
local arr_to_set = utils.arr_to_set
local set_to_arr = utils.set_to_arr

local FRONTMATTER_BOUNDARY = '---'
local INLINE_TAG_PATTERN = '#([%w%-/]+)'
local INLINE_TITLE_PATTERN = '^#%s+(.+[^%s])%s*$'
local INLINE_WIKILINK_PATTERN = '%[%[%s*(.+)%s*%]%]'
local DEFAULT_TEMPLATE =
[[---
created: ${created}
modified: ${modified}
---
# ${title}

]]

local DEFAULT_DAILY_TEMPLATE =
[[---
tags: [daily]
created: ${created}
modified: ${modified}
---

# ${title}



]]


local M = {}

local Note = {}

Note.__index = function(self, key)
  if key ~= 'tags' then
    return Note[key]
  end
  local tags_set = {}

  for _,tag in ipairs(self._fm.tags) do
    tags_set[tag] = 1
  end
  for _,tag in ipairs(self._inline_tags) do
    tags_set[tag] = 1
  end

  self.tags = set_to_arr(tags_set)
end

function Note:dump()
  local r = {}
  if not self._fm then
    return
  end
  for name,val in pairs(self._fm) do
    if val and not (type(val) == 'table' and #val == 0) then
      r[name] = val
    end
  end
  local _,fm = pcall(yaml.dump, r)
  return fm
end

function Note:get_fm_tags()
  return self._fm.tags
end

function Note:toggle_tag(tag)
  local tags = self._fm.tags
  for idx,val in ipairs(tags) do
    if val == tag then
      table.remove(tags, idx)
      self.tags = nil
      return
    end
  end
  table.insert(tags, tag)
  self.tags = nil
end

function M.parse_current_buffer()
  return M.parse_note(buffer.current_buffer_iterator(), vim.fn.expand('%:p'))
end

function Note:save_in_current_buffer()
  assert(vim.fn.expand('%:p') == self.path, 'Current buffer has different path than note!')
  buffer.save_meta_in_current_buffer(self:dump(), FRONTMATTER_BOUNDARY, self._fm_start, self._fm_end)
end

function Note:update_modified_curbuf()
  self._fm['modified'] = utils.current_datetime()
  self:save_in_current_buffer()
end

function Note:change_title_current_buffer(new_title)
  if self._fm.title then
    self._fm.title = new_title
    self:save_in_current_buffer()
    return true
  elseif self._inline_title_line_nr then
    local line_nr = self._inline_title_line_nr
    vim.fn.setline(line_nr, '# ' .. new_title)
    return true
  end
  return false
end


-- function Note:rename_wikilink(from, to)
--   local text = path:new(self.path):read()
--   local changed = false
--   -- TODO aggregate links to reduce iterations
--   for link,_ in pairs(self._internal_links) do
--     if from:lower() == link:lower() then
--       text = text:gsub('%[%[' .. link .. '(|?[^%]]*)%]%]','%[%[' .. to .. '%1%]%]')
--       changed = true
--     end
--   end

--   if changed then
--     path:new(self.path):write(text, 'w')
--   end
-- end

function Note:has_wikilinks_to(title)
  title = vim.trim(title)
  title = title:lower()
  for linked,_ in pairs(self._wikilinks) do
    if linked:lower() == title then
      return true
    end
  end
end

function M.parse_note(line_iter, fn)
  local return_to_it = function(returned, it)
    return function()
      if returned then
        local tmp = returned
        returned = nil
        return tmp
      end
      return it()
    end
  end

  local self = {_wikilinks={}}
	local idx = 0
  local in_fm = false
  local fm_lines = {}
  for line in line_iter do
    idx = idx + 1
    if startswith(line, FRONTMATTER_BOUNDARY) then
      if in_fm then
        self._fm_end = idx
        break
      end
      in_fm = true
      self._fm_start = idx
    elseif not in_fm then
      line_iter = return_to_it(line, line_iter)
      break
    else
      table.insert(fm_lines, line)
    end
  end

  if #fm_lines > 0 then
    local ok,fm = pcall(yaml.eval,table.concat(fm_lines, '\n'))
    if ok then
      self = vim.tbl_extend('keep',self,fm)
      self._fm = fm
      if type(self._fm.tags) == 'string' then
        self._fm.tags = {self._fm.tags}
      end
    end
  end
  self._fm = self._fm or {}

	local tags_set = {}
  local title = self.title
  for line in line_iter do
		idx = idx + 1
    if not title then
      title = line:match(INLINE_TITLE_PATTERN)
			if title then
				self._inline_title_line_nr = idx
				self.title = title
			end
    end
    for tag in string.gmatch(line, INLINE_TAG_PATTERN) do
      tags_set[tag] = 1
    end
    for w in wikilinks_iterator(line) do
      if w.link then
        self._wikilinks[w.link:lower()] = idx
      end
    end
  end
  if type(self.title) ~= 'string' then
    self.title = vim.split(at(vim.split(fn, '/'), -1),'%.')[1]
  end
	self._inline_tags = set_to_arr(tags_set)
  if self._fm.tags then
    for _, tag in ipairs(self._fm.tags) do
      tags_set[tag] = 1
    end
  end
  self.tags = set_to_arr(tags_set)
  self.path = fn
  self.title = vim.trim(self.title)
	return setmetatable(self, Note)
end

local make_note_path = function(folder, title)
  local slug = title
  if config.make_note_slug then
    slug = config.make_note_slug(title)
  end
	return path:new(config.vault_path , folder , (slug .. '.md'))
end

M._make_note_path = make_note_path

function M.create_note_if_not_exists(folder,title,tmpl)
  local p = make_note_path(folder, title)
  if p:exists() then return p:absolute() end

	local dt = utils.current_datetime()
	local ctx = {
		created = dt,
		modified = dt,
		title = title
	}
	local content = utils.interp(tmpl, ctx)
  p:write(content, 'w')

  return p:absolute()
end

return M
