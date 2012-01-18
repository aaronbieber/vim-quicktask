" quicktask.vim: A lightweight task management plugin.
"
" Author:	Aaron Bieber
" Version:	1.0
" Date:		10 January 2012
"
" See the documentation in doc/quicktask.txt

" Set all buffer-local settings: {{{1
let s:version = '1.0'

" ============================================================================
" QTInit(): Initialize a new task list. {{{1
"
" Create a new Quicktask file in a new buffer.
function! QTInit()
	echom "Filename: ".expand('%:p')
	echom "Modified: ".&modified
	if len(expand('%:p')) || &modified
		execute "new"
	endif
	setlocal filetype=quicktask
	let new_task_list = [	'# Quicktask v'.s:version,
							\'',
							\'CURRENT TASKS:',
							\'	- My first task.',
							\'		* Added ['.strftime("%a %Y-%m-%d").']',
							\'COMPLETED TASKS:',
							\'',
							\'# vim:ft=quicktask']
	call append(0, new_task_list)
	execute "normal GddggzR"
endfunction

" ============================================================================
" Commands {{{1
command! QTInit call QTInit()
