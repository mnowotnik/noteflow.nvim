
function s:extended_markdown()
	let l:has_vim_markdown = exists(':HeaderDecrease')
	if l:has_vim_markdown
		syn clear mkdListItemLine
	endif
	syn region mkdTodoStrike matchgroup=htmlStrike start="\[x\]"ms=e+2 end="$"
	hi def link mkdTodoStrike htmlStrike

	if l:has_vim_markdown
		syn clear mkdNonListItemBlock
	endif
	syn region NoteflowWikilink start="\[\[" end="\]\]"
	hi link NoteflowWikilink Underlined
endfunction

augroup NoteflowGroup
	autocmd! * <buffer>
	autocmd BufWrite <buffer> lua require('noteflow').update_modified()
	if get(g:, 'noteflow_extended_markdown', 0)
		autocmd BufEnter *.md call s:extended_markdown()
	endif
augroup END

