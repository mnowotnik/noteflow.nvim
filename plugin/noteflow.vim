if exists('g:loaded_noteflow') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=1 NoteflowNew call luaeval("require'noteflow':new_note(_A)", expand('<args>'))
command! -nargs=0 NoteflowDaily lua require'noteflow':daily_note()
command! -nargs=0 NoteflowFind lua require'noteflow':find_note_by_title()
command! -nargs=0 NoteflowGrep lua require'noteflow':grep_notes()
command! -nargs=0 NoteflowStagedGrep lua require'noteflow':staged_grep()
command! -nargs=0 NoteflowFollowWikilink lua require'noteflow':follow_wikilink()
command! -nargs=0 NoteflowInsertWikilink lua require'noteflow':insert_link()
command! -nargs=0 NoteflowEditTags lua require'noteflow':edit_tags()
command! -nargs=1 NoteflowRename call luaeval("require'noteflow':rename_note(_A)", expand('<args>'))
command! -nargs=0 NoteflowPreview lua require'noteflow':preview()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_noteflow = 1
