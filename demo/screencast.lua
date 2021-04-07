

local commands = {}

local key_delay = 80

local press_keys = function(keys, cb)
  keys = keys:gsub('<bs>', '')
  keys = vim.api.nvim_replace_termcodes(keys, true, true, true)
  local iter = keys:gmatch"."
  local press
  press = function()
    local c = iter()
    print(c)
    if not c then return cb() end
    vim.fn.feedkeys(c)
    vim.defer_fn(press, key_delay)
  end
  vim.defer_fn(press, key_delay)
end

local runner
local idx = 1
runner = function()
  local cmd = commands[idx]
  if not cmd then return end
  idx = idx + 1
  local action
  if type(cmd) == 'number' then
    vim.defer_fn(runner, cmd)
  elseif type(cmd) == 'string' then
    press_keys(cmd, runner)
  else
    assert(false)
  end
end

function send(keys)
  table.insert(commands,keys)
end

function wait(ms)
  table.insert(commands,ms)
end

send(":NoteflowNew Introduction<CR>")
wait(300)
send("Note<CR>")
send("oWelcome to Noteflow demonstration!<cr><cr>")
wait(500)
send("To create new notes use command<cr>")
send("  :NoteflowNew <title><cr><bs>")
send("To edit tags<cr>")
send("  :NoteflowEditTags (or ,ne mapping )<cr><bs>")
send("To browse notes<cr>")
send("  :NoteflowFind (or ,nf mapping )<cr><bs>")
send("To insert wikilink<cr>")
send("  :NoteflowInsertLink (or ,nl mapping)<cr><bs><cr>")
send("Let's see them in action!<esc>")
send(":NoteflowEditTags<cr>")
send("basic<C-t><cr>")
send("Go<cr><bs>We just added 'basic' tag to this note<esc>:w<cr>")
send(":NoteflowNew Foo bar<CR>")
wait(200)
send("Note<CR>")
wait(200)
send("oFoobar is a placeholder name in [[computer programming]].<esc>hh")
send(":NoteflowFollowWikilink<cr>")
wait(200)
send("Note<cr>")
wait(200)
send("oThis is a new note about programming. Let's go back to the intro, though.<esc>bbb")
send(":NoteflowInsertLink<cr>")
send("#<C-x><C-o>b<C-n> <cr>")
wait(300)
send(":NoteflowFollowWikilink<cr>")
wait(500)
send(":qa!")

runner()
