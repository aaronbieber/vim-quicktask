" quicktask.vim: A lightweight task management plugin.
"
" Author:	Aaron Bieber
" Version:	1.2
" Date:		10 January 2012
"
" See the documentation in doc/quicktask.txt
"
" Quicktask is free software: you can redistribute it and/or modify it under
" the terms of the GNU General Public License as published by the Free
" Software Foundation, either version 3 of the License, or (at your option)
" any later version.
"
" Quicktask is distributed in the hope that it will be useful, but WITHOUT ANY
" WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
" FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
" details.
"
" You should have received a copy of the GNU General Public License along with
" Quicktask.  If not, see <http://www.gnu.org/licenses/>.

" Set all buffer-local settings: {{{1
let s:version = '1.2'

" ============================================================================
" QTInit(): Initialize a new task list. {{{1
"
" Create a new Quicktask file in a new buffer.
function! QTInit()
	if len(expand('%:p')) || &modified
		execute "new"
	endif
	setlocal filetype=quicktask
	let new_task_list = [	'# Quicktask v'.s:version,
							\'',
							\'CURRENT TASKS:',
							\'  - My first task.',
							\'    @ Added ['.strftime("%a %Y-%m-%d").']',
							\'COMPLETED TASKS:',
							\'',
							\'# vim:ft=quicktask']
	call append(0, new_task_list)
	execute "normal GddggzR"
endfunction

" ============================================================================
" Commands {{{1
command! QTInit call QTInit()
