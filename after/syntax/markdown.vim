if exists("b:noteflow_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim
lua require('noteflow'):_syntax_setup()

let b:noteflow_syntax = 1

let &cpo = s:cpo_save
unlet s:cpo_save
