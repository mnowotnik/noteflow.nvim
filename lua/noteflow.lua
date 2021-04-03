-- https://www.2n.pl/blog/how-to-write-neovim-plugins-in-lua

local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local path = require('plenary.path')
local scandir = require('plenary.scandir')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local telescope_conf = require('telescope.config').values
local sorters = require('telescope.sorters')

local config = require('noteflow.config')
local custom_finders = require('noteflow.custom_finders')
local notes = require('noteflow.notes')
local utils = require('noteflow.utils')
local cache = require('noteflow.cache')

local vim_find_rev = utils.vim_find_rev
local set_to_arr = utils.set_to_arr
local arr_to_set = utils.arr_to_set
local parse_tags_prompt = utils.parse_tags_prompt
local log = utils.log

local buffer = require('noteflow.buffer')
local find_wikilink_open_start = buffer.find_wikilink_open_start
local find_wikilink = buffer.find_wikilink_under_cursor

local luv = vim.loop

local get_templates_path = function()
  if path:new(config.templates_dir):exists() then
    return config.templates_dir
  end
  return nil
end

local get_all_tags = function()
  local tags = {}
  cache:refresh({
    on_insert = function(meta)
      for _,tag in ipairs(meta.tags) do
        tags[tag] = 1
      end
    end,
    wait_for_completion = true
  })
  return set_to_arr(tags)
end

local find_note = function(opts)
  local fzy = require('telescope.algos.fzy')
  pickers.new(opts, {
    finder = custom_finders.indexing_finder({cwd=config:vault_path()}),
    sorter = sorters.Sorter:new {
      scoring_function = function() return 0 end,

      highlighter = function(_, _, display)
        -- FIXME ignore telescope prompt (second param) cause it has incorrect values
        local raw_prompt = vim.fn.getline('.'):sub(2)
        if display == "" then
          return {}
        end
        local prompt_tags, title_prompt = parse_tags_prompt(raw_prompt)
        local title, tags = unpack(vim.split(display, '\t'))
        local hl = fzy.positions(title_prompt, title)
        -- match tags regardless of order on the prompt line
        if tags and #prompt_tags > 0 then
          tags = vim.split(tags, ' ')
          local tag_offset = #title + 1
          for _,tag in ipairs(tags) do
            for _,p_tag in ipairs(prompt_tags) do
              -- find matching part of escaped tag
              local startpos,endpos = tag:find(p_tag:gsub('%-','%%-'))
              if startpos then
                for i=startpos,endpos do
                  table.insert(hl, i + tag_offset)
                end
                break
              end
            end
            tag_offset = tag_offset + #tag + 1
          end
        end
        return hl
      end,
    },
    previewer = telescope_conf.file_previewer(opts),
    attach_mappings = opts.attach_mappings
  }):find()
end

local get_vault_folders = function()
    local fd = luv.fs_scandir(config:vault_path())
    if fd == nil then return end
    local result = {}
    local tmpl_path = get_templates_path()
    while true do
      local name, typ = luv.fs_scandir_next(fd)
      if name == nil then break end
      if typ == 'directory'
        and not vim.startswith(name, ".")
        and tmpl_path -- filter out template dir
        and tmpl_path ~= path:new(config:vault_path(), name):absolute() then
        table.insert(result, name)
      end
    end
    return result
end

local get_templates = function()
  local tmpl_path = get_templates_path()
  if not tmpl_path then
    return {}
  end
  local templates = {}
  scandir.scan_dir(tmpl_path, {
    search_pattern='.+%.md',
    on_insert = function(fn)
      local tmpl_content = path:new(fn):read()
      templates[vim.fn.fnamemodify(fn,':t')] = tmpl_content
    end,
  })
  templates['empty'] = ''
  return templates
end

local on_choose_from_table_factory = function(args)
  local source = args.source
  local default_prompt = args.default_prompt
  return function(callback, opts)
    opts = opts or {}
    local results = source()
    if #results < 2 then
      callback(results[0])
    end
    pickers.new(opts, {
      prompt_title = default_prompt,
      finder = finders.new_table{results=results,entry_maker=opts.entry_maker},
      sorter = telescope_conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          callback(selection.value)
        end)
        return true
      end
    }):find()
  end
end


local on_choose_template = function(callback, opts)
  opts = opts or {}
  local templates = get_templates()
  local picker = on_choose_from_table_factory{
    default_prompt='Choose template',
    source=function()
      local tmpl_names = vim.tbl_keys(templates)
      local default_template = vim.g.noteflow_default_template
      if default_template then
        table.sort(tmpl_names, function(a,b)
          if a==default_template then return true end
          if b==default_template then return false end
          return a<b
        end)
      else
        table.sort(tmpl_names)
      end
      return tmpl_names
    end,
  }
  opts.entry_maker = function(line)
    return {
      ordinal=line,
      display=line,
      value=templates[line]
    }
  end
  picker(callback,opts)
end

local on_choose_folder = on_choose_from_table_factory{source=get_vault_folders, default_prompt='Choose folder'}

local M = {}

function M.find_note_by_title()
  -- TODO add sorting by modified
  -- TODO support multiple vaults
  find_note {
    prompt_title = "Notes",
    width = .25,
    layout_strategy = 'horizontal',
    layout_config = {
      preview_width = 0.65,
    },
  }
end

local staged_grep = function(opts)
  opts = {unpack(opts)} or {}

  local fzf_separator = opts.fzf_separator or "|"

  local parse_prompt = function(prompt)
    local rg_prompt, fzf_prompt = string.match(prompt, '(.+)' .. fzf_separator .. '(.+)')
    if not rg_prompt then
      local startpos = string.find(prompt, fzf_separator)
      if not startpos then rg_prompt = prompt
      else
        rg_prompt = prompt:sub(1,startpos-1)
      end
      fzf_prompt = ""
    end
    return rg_prompt, fzf_prompt
  end
  opts.rg_args_maker = function(prompt)
      local rg_prompt, _ = parse_prompt(prompt)
      return {'--vimgrep', '-i', '-F', rg_prompt, "." }
  end
  opts.fzf_args_maker = function(prompt)
      local _, fzf_prompt = parse_prompt(prompt)
      fzf_prompt = fzf_prompt or ""
      return vim.tbl_flatten({{'--delimiter',':','--with-nth','-1','--filter'}, fzf_prompt})
  end
  opts.entry_maker = make_entry.gen_from_vimgrep(opts)
  opts.min_characters = 1

  local fzy = require('telescope.algos.fzy')
  pickers.new(opts, {
    prompt_title = 'Notes:staged search',
    finder = custom_finders.two_stage_file_finder(opts),
    previewer = telescope_conf.grep_previewer(opts),
    sorter = sorters.get_generic_fuzzy_sorter{higlighter=function(_, prompt, display)
      local rg_prompt, fzf_prompt = parse_prompt(prompt)
      if #fzf_prompt > 0 then
        return fzy.positions(fzf_prompt, display)
      else
        return fzy.positions(rg_prompt, display)
      end
    end}
  }):find()
end

local live_grep = function(opts)
  local live_grepper = finders.new_job(function(prompt)
      if not prompt or prompt == "" then
        return nil
      end
      return vim.tbl_flatten { telescope_conf.vimgrep_arguments, '-i', '-F',prompt, '.' }
    end,
    opts.entry_maker or make_entry.gen_from_vimgrep(opts),
    opts.max_results,
    opts.cwd
  )

  pickers.new(opts, {
    prompt_title = opts.prompt_title or "Live Grep",
    finder = live_grepper,
    previewer = opts.previewer or telescope_conf.grep_previewer(opts),
    sorter = opts.sorter or telescope_conf.generic_sorter(opts),
  }):find()
end

function M.grep_notes()
  live_grep {
   prompt_title = "Notes: search",
   cwd = config:vault_path(),
   shorten_path = true,
   previewer = false,
   sorter = sorters.highlighter_only()
  }
end

function M.staged_grep()
  staged_grep {
    cwd = config:vault_path(),
    shorten_path = true,
    previewer = false,
    fzf_separator = "|>",
  }
end

function M.new_note(title)
  on_choose_template(function(tmpl)
    on_choose_folder(function(folder)
      local p = notes.create_note_if_not_exists(folder, title, tmpl)
      utils.open_file(p, {move_to_end=true})
    end)
  end)
end

function M.new_empty_note(title)
  on_choose_folder(function(folder)
    local templates = get_templates()
    local tmpl = templates[vim.g.noteflow_default_template]
    if not tmpl then
      tmpl = templates['empty']
    end
    local p = notes.create_note_if_not_exists(folder, title, tmpl.content)
    utils.open_file(p, {move_to_end=true})
  end)
end

function M.update_modified()
  local meta = notes.parse_current_buffer()
  meta:update_modified_curbuf()
end

function M.follow_wikilink()
  local wikilink = find_wikilink()
  if not wikilink or not wikilink.link then return end

	log.fmt_debug("Found wikilink: '%s'", wikilink.link)

  cache:refresh({wait_for_completion=true})

  local link = wikilink.link:lower()
  if vim.trim(link) == "" then return end
  for fn, meta in pairs(cache) do
    if meta.title:lower() == link then
			log.fmt_debug("Opening note for wikilink: '%s'", fn)
      utils.open_file(fn)
      return
    end
  end
	log.fmt_debug("No notes found. Creating a new note for wikilink: '%s'", wikilink.link)

	M.new_note(link)
end

local in_telescope = function()
  return action_state.get_current_picker(vim.fn.bufnr()) ~= nil
end

function _G.noteflow_omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local curpos = vim.fn.col('.')
    local startpos
    if in_telescope() then
      local line_to_cur = line:sub(1,curpos)
      -- tag completion
      startpos,_,_ = vim_find_rev(line_to_cur, '\\w*#', 1)
    else
      startpos = find_wikilink_open_start(line, curpos)
      if not startpos then return end
      vim.schedule(function()
        find_note({
          prompt_title = 'Choose wikilink note',
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              local title = cache[selection.value].title
              local mode = 'i'
              local _, _, col, _ = unpack(vim.fn.getpos('.'))
              if col >= #vim.fn.getline('.') then
                mode = 'a'
              end
              local pos = vim.fn.getpos('.')
              vim.defer_fn(function()
                vim.fn.setpos('.', pos)
                utils.vim_exec{'normal ' .. mode .. title, restore_register=true}
              end, 10)
            end)
            return true
          end})
        end)
        return -2
      end
    -- to 0-indexed and then move 1 to the right
    if startpos then return startpos - 1 + 1 else return -3 end
  elseif findstart == 0 then
    if vim.bo.ft == 'TelescopePrompt' then
      return get_all_tags()
    end
    return {}
  end
end

function M.insert_link()
	-- already in wikilink?
  if find_wikilink() then
    return
  end
	-- any non-empty word under cursor?
  if not string.find(vim.fn.expand('<cword>'), '[^%s]') then
    return
  end

  local opts = {
    prompt_title = "Notes: search by title",
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local title = cache[selection.value].title
        -- FIXME telescope incorrectly restores pos
        local oldpos = vim.fn.getpos('.')
        vim.defer_fn(function()
          vim.fn.setpos('.', oldpos)
          utils.vim_exec{'normal ciw[[' .. title .. '|' .. '\\<C-r>\\\"' .. ']]\\<Esc>', restore_register=true}
        end, 10)
      end)
      return true
    end
  }

  find_note(opts)
end

function M.noteflow_ftdetect()
  if config:vault_path() == "" then
    return
  end
  if string.match(vim.bo.filetype, "noteflow") then
    return
  end

  if vim.startswith(vim.fn.expand('%:p:h'), config:vault_path()) then
    local old_ft = vim.bo.filetype or ""
    old_ft = vim.trim(old_ft)
    vim.bo.filetype = old_ft ~= "" and old_ft .. ".noteflow" or "noteflow"
  end
end

function M.daily_note()
	assert(vim.g.noteflow_daily_folder, 'Daily notes folder not configured!')
	assert(vim.g.noteflow_daily_template, 'Daily notes template not configured!')
	local title = current_date()
  local daily_tmpl = get_templates()[vim.g.noteflow_daily_template]
	assert(daily_tmpl, 'Daily notes template does not exist!')
	local p = notes.create_note_if_not_exists(vim.g.noteflow_daily_folder, title,
		daily_tmpl)
	utils.open_file(p, {move_to_end=true})
end

-- TODO allow adding new tags
function M.edit_tags()
  local meta = notes.parse_current_buffer()
  local modified = false
  local all_tags = get_all_tags()
  local view = vim.fn.winsaveview()
  assert(meta, "Can't parse frontmatter")

  local sort_tags = function(tags)
    local meta_tags = arr_to_set(meta.get_fm_tags())
    table.sort(tags, function(a,b)
      local a_in_meta = meta_tags[a]
      local b_in_meta = meta_tags[b]
      if a_in_meta and b_in_meta then
        return a<b
      end

      if a_in_meta then return true end
      if b_in_meta then return false end

      return a<b
    end)
  end

  sort_tags(all_tags)

  local max_tag_len = 0
  for _,tag in ipairs(all_tags) do
    if #tag > max_tag_len then
      max_tag_len = #tag
    end
  end
  max_tag_len = max_tag_len > 0 and max_tag_len or 30

  local entry_maker = function(line)
    local display = line
    if vim.tbl_contains(meta.get_fm_tags(), display) then
      display = string.format('%-'.. max_tag_len .. 's%s', line, '✔️')
    end
    return {
      ordinal=line,
      display=display,
      value=line
    }
  end

  local make_finder = function()
    return finders.new_table{results=all_tags,entry_maker=entry_maker}
  end

  local picker
  picker = pickers.new({
    prompt_title = "Edit tags. <space> to toggle",
    selection_strategy = 'row',
    finder = make_finder(),
    sorter = telescope_conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<C-t>', function()
        local tag = action_state.get_current_line()
        if not tag or #tag == 0  then
          return
        end
        tag = vim.trim(tag)
        if vim.tbl_contains(all_tags, tag) then
          print("Tag " .. tag .. " already exists!")
        end
        table.insert(all_tags, tag)
        meta:toggle_tag(tag)
        modified = true
        sort_tags(all_tags)
        picker:refresh(make_finder())
      end)
      map('n','<space>',function()
        local selection = action_state.get_selected_entry()
        meta:toggle_tag(selection.value)
        modified = true
        picker:refresh(make_finder())
        vim.schedule_wrap(function()
          picker:set_selection(selection.index)
        end)
      end, {nowait=true})

      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        if not modified then return end
        meta:save_in_current_buffer()
        vim.fn.winrestview(view)
      end)

      return true
    end
  })
  picker:find()
  picker:set_selection(0)
end

function M.setup(opts)
  config:setup(opts)
end

function M.rename_note(new_title)
  local cnote = notes.parse_current_buffer()
  local old_title = cnote.title
  if not cnote:change_title_current_buffer(new_title) then return end

	cache:refresh({wait_for_completion=true})
  local bufnr = vim.fn.bufnr()
  -- vim.api.nvim_command[[argdelete *]]
  -- print(vim.api.nvim_command[[args]])
  for _,note in pairs(cache) do
    if note:has_wikilinks_to(old_title) then
      -- vim.api.nvim_command('argadd ' .. vim.fn.fnameescape(note.path))
      vim.api.nvim_command('e ' .. vim.fn.fnameescape(note.path))
      vim.api.nvim_command([[silent %s/\v\[\[\s*]] .. old_title .. [[\s*(\|[^|]+)?\]\]/\[\[]] .. new_title .. [[\2\]\]/g | silent update | bd]])
    end
  end
  vim.cmd('buffer ' .. bufnr)
end

return M
