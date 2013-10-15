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

" Compatibility option reset: {{{1
let s:cpo_save = &cpo
set cpo&vim

" Set all buffer-local settings: {{{1
setlocal comments=b:#,f:-,f:*
setlocal formatoptions=qnwta
setlocal spell
setlocal wrap
setlocal textwidth=80

" Quicktask uses real tabs with a visible indentation of two spaces.
setlocal expandtab
setlocal shiftwidth=2
setlocal tabstop=2

" Add the 'at' sign to the list of keyword characters so that our
" abbreviations may use it.
setlocal iskeyword=@,@-@,48-57,_,192-255

" Folding settings
setlocal foldmethod=expr
setlocal foldexpr=QTFoldLevel(v:lnum)
setlocal fillchars="fold: "
setlocal foldtext=QTFoldText()

" Script settings
let s:version = '1.2'
let s:one_indent = repeat(" ", &tabstop)

if has('gui_win32')
	let s:path_sep = '\'
else
	let s:path_sep = '/'
endif

" Global options, defaults
if !exists("g:quicktask_autosave")
	let g:quicktask_autosave = 0
endif

if !exists("g:quicktask_snip_win_height")
	let g:quicktask_snip_win_height = ''
endif

if !exists("g:quicktask_snip_default_filetype")
	let g:quicktask_snip_default_filetype = "text"
endif

if !exists("g:quicktask_snip_win_split_direction") ||
	\ g:quicktask_snip_win_split_direction != "vertical"

	let g:quicktask_snip_win_split_direction = ""
endif

if !exists("g:quicktask_snip_win_maximize")
	let g:quicktask_snip_win_maximize = 0
endif

" ============================================================================
" EchoWarning(): Echo a warning message, in color! {{{1
function! s:EchoWarning(message)
	echohl WarningMsg
	echo a:message
	echohl None
endfunction

" ============================================================================
" Configure snips if the user has configured the path. {{{1
if exists("g:quicktask_snip_path")
	" Expand the path right now so we don't have to do it over and over.
	let g:quicktask_snip_path = expand(g:quicktask_snip_path)

	" Should we create the directory?
	if !isdirectory(expand(g:quicktask_snip_path))
		call s:EchoWarning("Your snips directory, ".g:quicktask_snip_path." doesn't exist.")
		let ans = ''
		while match(ans, '[YyNn]') < 0
			echo "Create it? [y/n] "
			let ans = nr2char(getchar())
		endwhile

		if ans == 'y' || ans == 'Y'
			call mkdir(g:quicktask_snip_path, 'p')
		elseif ans == 'n' || ans == 'N'
			echomsg "You will not be able to create new snips or load existing snips."
		endif
	endif

	" Append a trailing slash if one was not given.
	if match(g:quicktask_snip_path, '[\/]$') == -1
		let g:quicktask_snip_path = g:quicktask_snip_path.s:path_sep
	endif
endif

" ============================================================================
" GetAnyIndent(): Get the indent of any line. {{{1
"
" With the cursor on any line, return the indent level (the number of spaces
" at the beginning of the line, simply).
function! s:GetAnyIndent()
	" What is the indentation level of this task?
	let matches = matchlist(getline('.'), '\v^(\s{-})[^ ]')
	let indent = len(matches[1])

	return indent
endfunction

" ============================================================================
" GetTaskIndent(): Return current indent level. {{{1
"
" With the cursor on a task line, return the indent level of that task.
function! s:GetTaskIndent()
	if getline('.') =~ '^\s*- '
		" What is the indentation level of this task?
		let matches = matchlist(getline('.'), '\v^(\s{-})[^ ]')
		let indent = len(matches[1])

		return indent
	endif

	return -1
endfunction

" ============================================================================
" FindTaskStart(): Find the start of the current task. {{{1
"
" Search backwards for a task line. This function moves the cursor.
" If the cursor is already on a task line, do nothing.
function! s:FindTaskStart(move)
	" Only move the cursor if we are asked to.
	let flags = 'bcW'
	if !a:move
		let flags .= 'n'
	endif

	return search('^\s*- ', flags)
endfunction

" ============================================================================
" FindTaskEnd(): Find the end of the current task. {{{1
"
" Search forward for the end of the current task. If we do not start on a task
" line, we first search backwards for a task line. We then search forward for
" the first line that isn't a part of that task, which may be the next task,
" the next section, or the end of the file.
function! s:FindTaskEnd(move)
	" If we are not on a task line
	call s:FindTaskStart(1)
	let task_end_line = line('.')

	" Get the indent of this task
	let indent = s:GetTaskIndent()

	" If this is a task line
	if indent > -1
		" Search downward, looking for either the end of the task block or
		" start/end notes and record them. Begin on the line immediately
		" following the task line.

		let task_end_line = search('^\($\|\s\{0,'.indent.'}[^ ]\)', 'nW')
	endif

	if a:move
		" Move the cursor to the line immediately prior, which should be the
		" last line of the task we are looking for.
		call cursor(task_end_line-1, 0)
	else
		return task_end_line - 1
	endif
endfunction

" ============================================================================
" FindTaskParent(): Find the start line of the current task's parent. {{{1
"
" Get the indent level of the current task and, if non-zero, find the first
" line of the task that encloses this one (its 'parent').
function! s:FindTaskParent()
	call s:FindTaskStart(1)
	let indent = s:GetTaskIndent()

	if indent == 0
		return 0
	else
		let parent_indent = indent - &tabstop
		let parent_line = search('^\s\{'.parent_indent.'}[^ ]', 'bnW')
		return parent_line
	endif
endfunction!

" ============================================================================
" FindNextSibling(): Find the sibling task below the current task. {{{1
"
" Get the indent level of the current task and find a task below this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! s:FindNextSibling()
	call s:FindTaskStart(1)
	let indent = s:GetTaskIndent()

	" If we might be a child, get the location of the next line 'below' our
	" indent level, such as our parent's next sibling. This is our 'boundary
	" line', beyond which we cannot search for siblings.
	if indent > 0
		let parent_indent = indent - &tabstop
		let boundary_line = search('^\s\{0,'.parent_indent.'}[^ ]', 'nW')
	else
		" If we are at the lowest indent level, our boundary is the end of the
		" file.
		let boundary_line = line('$')
	endif

	return search('^\s\{'.indent.'}-', 'nW', boundary_line-1)
endfunction

" ============================================================================
" FindPrevSibling(): Find the sibling task above the current task. {{{1
"
" Get the indent level of the current task and find a task above this one that
" has the same indent. If the current task is a child, only find siblings
" within the same parent.
function! s:FindPrevSibling()
	call s:FindTaskStart(1)
	let indent = s:GetTaskIndent()

	" If we are a child of something, find the boundary at which we must stop
	" searching. For backwards searching, this is our parent task's line.
	if indent > 0
		let boundary_line = s:FindTaskParent()
	else
		" If we are at the lowest indent level, our boundary is the beginning
		" of the file.
		let boundary_line = 1
	endif

	return search('^\s\{'.indent.'}-', 'bnW', boundary_line)
endfunction

" ============================================================================
" SelectTask(): Create a linewise visual selection of the current task. {{{1
function! s:SelectTask()
	call s:FindTaskStart(1)
	let end_line = s:FindTaskEnd(0)

	execute "normal V".end_line."G"
endfunction

" ============================================================================
" GetTaskText(): Get the first line of text of a task. {{{1
function! s:GetTaskText()
	let task_line_num = s:FindTaskStart(0)
	if task_line_num
		return getline(task_line_num)
	endif

	" Fallback
	return ''
endfunction

" ============================================================================
" MakeSnipName(): Make a snip name out of the task text. {{{1
function! s:MakeSnipName()
	" Begin with the text of the task.
	let task_text = s:GetTaskText()
	let task_string = ''

	" If we have task text, create a snip string automatically.
	if len(task_text)
		let matches = matchlist(task_text, '^\s*- \(.*\)$')
		if len(matches)
			let task_string = tolower(substitute(matches[1], '[^a-zA-Z]', '-', 'g'))
			if strlen(task_string) > 30
				let task_string = matchstr(task_string, '^\(.\{15\}\)')
			endif
		endif
	endif

	" If we couldn't get an adequate string automatically, prompt the user for
	" one.
	if !strlen(task_string)
		echo "The task's name is not long enough or couldn't be found."
		let orig_text = input("Enter a name for the snip: ")
		let task_string = tolower(substitute(orig_text, '[^a-zA-Z]', '-', 'g'))
		if strlen(task_string) > 30
			let task_string = matchstr(task_string, '^\(.\{15\}\)')
		endif
	endif

	" Don't let the string END with a hyphen.
	if match(task_string, '-$')
		let task_string = substitute(task_string, '-$', '', '')
	endif

	return strftime('%Y%m%d%H%M%S-').task_string
endfunction

" ============================================================================
" AddTask(after, indent): Add a task to the file. {{{1
"
" Add a 'skeleton' task to the file after the line given and at the indent
" level specified.
function! s:AddTask(after, indent, move_cursor)
	if a:indent > 0
		let physical_indent = repeat(" ", a:indent)
	else
		let physical_indent = ''
	endif

	" Compose the two lines to insert
	let task_line = physical_indent . "- "
	let date_line = physical_indent . s:one_indent . "@ Added [".strftime("%a %Y-%m-%d")."]"
	call append(a:after, [ task_line, date_line ])

	if a:move_cursor
		call cursor(a:after+1, len(getline(a:after+1)))
		startinsert!
	endif
endfunction

" ============================================================================
" AddTaskAbove(): Add a task above the current task. {{{1
"
" Add a task above the current task, at the current task's level.
function! s:AddTaskAbove()
	" We don't support inserting a task above a section.
  if getline('.') =~ ':$' && getline('.') !~ '^\s*-'
		call s:EchoWarning("Inserting a task above a section isn't supported.")
		return
	endif

	call s:FindTaskStart(1)
	let indent = s:GetTaskIndent()
	" Append the new task above this line
	let task_line_num = line('.')

	" Append the task, moving the cursor and starting insert
	call s:AddTask(task_line_num-1, indent, 1)
endfunction

" ============================================================================
" AddTaskBelow(): Add a task below the current task. {{{1
"
" Add a task below the current task, at the current task's level.
function! s:AddTaskBelow()
	" We insert directly below sections.
	if getline('.') =~ ':$' && getline('.') !~ '^\s*-'
		let indent = s:GetAnyIndent() + &tabstop
		let task_line_num = line('.')
	else
		" Find current task
		call s:FindTaskStart(1)
		" Get indent (this will be our new indent)
		let indent = s:GetTaskIndent()
		if indent < 0
			let indent = &tabstop
		endif

		" Find the end of the task and note the line number
		call s:FindTaskEnd(1)
		let task_line_num = line('.')
	endif

	" Append the task, moving the cursor and starting insert
	call s:AddTask(task_line_num, indent, 1)
endfunction

" ============================================================================
" AddChildTask(): Add a task as a child of the current task. {{{1
function! s:AddChildTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:FindTaskStart(1)

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()
	if indent < 0
		let indent = &tabstop
	else
		" The indent we want to find is the tasks's indent plus one.
		let indent = indent + &tabstop
	endif

	call s:FindTaskEnd(1)
	call s:AddTask(line('.'), indent, 1)
endfunction

" ============================================================================
" MoveTaskDown(): Move the current task down. {{{1
"
" Move the current task below the following task.
function! s:MoveTaskDown()
	call s:FindTaskStart(1)
	let task_start = line('.')

	let next_sibling = s:FindNextSibling()
	if !next_sibling
		call s:EchoWarning("This task has no siblings below it. To move the task elsewhere, use delete/put.")
		return
	else
		call s:FindTaskEnd(1)
		let task_end = line('.')
		call cursor(task_start)
	endif

	" Pull the contents of the task into a list of lines
	let task_text = getline(task_start, task_end)
	" Delete the task from the buffer
	execute "silent! ".task_start.",".task_end."d"

	"Find the end of the task that is now our moved task's prior sibling.
	call s:FindTaskEnd(1)
	let insert_line = line('.')
	call append(insert_line, task_text)
	call cursor(insert_line+1, 0)
endfunction

" ============================================================================
" MoveTaskUp(): Move the current task up. {{{1
"
" Move the current task up above the preceding task.
function! s:MoveTaskUp()
	if line('.') == 1
		return
	endif

	" Move the cursor to the task line that we are moving and get the line
	" number and indent level.
	call s:FindTaskStart(1)
	let task_start = line('.')
	let indent = s:GetTaskIndent()

	" If we are a child of something, anything, make sure we don't try to move
	" our child task into another task.
	if indent > 0
		" __Find the task above us, that we would move beyond ("sibling").__
		" Start the search in the first column because backwards search will
		" match on the current line if the match is prior to the cursor
		" position.
		call cursor(task_start, 0)
		let prev_sibling_line = search('^\s\{'.indent.'}-', 'bnW')

		" __Find our parent.__
		" We assume that our parent is one indent level lower than we are.
		let parent_indent = indent - &tabstop
		" Find the parent line.
		let parent_line = search('^\s\{'.parent_indent.'}-', 'bnW')

		" If the previous sibling is before the parent line in the file then
		" we should not move this task! Display a warning and abort.
		if parent_line > prev_sibling_line
			call s:EchoWarning("You can't move a task out of its parent task; use normal delete/put to move it.")
			call cursor(task_start)

			return
		endif
	endif

	" Place the cursor back at the start of the task to be moved.
	call cursor(task_start)

	" Is the preceding line at the same or greater indent?
	if match(getline(task_start-1), '^\s\{'.indent.',}') > -1
		" Search to the previous task at the same indent.
		call search('^\s\{'.indent.'}-', 'bW')
		"call cursor(task_start-1, 0)
		"call s:FindTaskStart()
		let final_line = line('.')
		call s:MoveTaskDown()
		call cursor(final_line, 0)
	endif
endfunction

" ============================================================================
" CheckSnipsReadiness(): Check snips settings; can we use snips? {{{1
function! s:CheckSnipsReadiness()
	if !exists("g:quicktask_snip_path") || !len(g:quicktask_snip_path)
		call s:EchoWarning("You cannot use snips because your snips path is not configured.")
		return 0
	elseif !isdirectory(g:quicktask_snip_path)
		call s:EchoWarning("You cannot use snips because your snips path does not exist.")
		return 0
	endif

	return 1
endfunction

" ============================================================================
" AddSnipToTask(): Add a new snip to a task as a note. {{{1
"
" Add a new snip (external note) to a task. This will be overhauled in 2.0
" when snips are in external files.
function! s:AddSnipToTask()
	" Make sure we are properly configured to use snips.
	if !s:CheckSnipsReadiness()
		return
	endif

	" If we are not on a task line right now, we need to search up for one.
	call s:FindTaskStart(1)

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + &tabstop
	let physical_indent = repeat(" ", indent)

	" Search downward, looking for either the end of the task block or
	" start/end notes and record them. Begin on the line immediately
	" following the task line.
	let current_line = line('.')+1
	let snip_line = current_line
	let matched = 0
	while current_line <= line('$')
		if match(getline(current_line), '\v^\s{'.indent.'}') > -1
			if match(getline(current_line), '\v^\s*-') > -1
				" Insert the snip above
				let snip_line = current_line - 1
				break
			elseif match(getline(current_line), '\vAdded \[') > -1 ||
				  \match(getline(current_line), '\vStart \[') > -1 ||
				  \match(getline(current_line), '\v\[\$:') > -1

				" We skip over Added, Start, and Snip lines if they exist.
				let current_line = current_line + 1
				continue
			else
				let snip_line = current_line - 1
				break
				" If it matches something else, like a plain note, insert the
				" snip above.
			endif
		else
			" This is the line beyond the task; the line above is the one we
			" want.
			let snip_line = current_line - 1
			break
		endif

		let current_line = current_line + 1
	endwhile

	" Generate a snip name
	let snip_name = s:MakeSnipName()
	"let uuid = substitute(system('uuidgen'), '\n', '', '')

	" Insert the snip placeholder in the task
	call append(snip_line, physical_indent.'* [$: '.snip_name.']')

	" Create a new snip file
	execute "silent! topleft ".g:quicktask_snip_win_split_direction." ".g:quicktask_snip_win_height."split ".g:quicktask_snip_path.snip_name
	execute "normal I# vim:ft=".g:quicktask_snip_default_filetype."\<ESC>O\<ESC>O\<ESC>"
	execute "setf ".g:quicktask_snip_default_filetype
	call s:ConfigureSnipWindow()
endfunction

" ============================================================================
" OpenSnip(): Open a snip file or reveal its buffer. {{{1
function! OpenSnip()
	" Make sure we are properly configured to use snips.
	if !s:CheckSnipsReadiness()
		return
	endif

	if match(getline('.'),  '\[\$:\s.\{-}]') > -1
		let snip_parts = matchlist(getline('.'), '\[\$:\s\(.\{-}\)]')
		if len(snip_parts) < 1
			return
		endif

		let filename = snip_parts[1]
		let full_file = g:quicktask_snip_path.filename
		if filereadable(full_file)
			execute "silent! topleft ".g:quicktask_snip_win_split_direction." ".g:quicktask_snip_win_height."split ".full_file
			call s:ConfigureSnipWindow()
		else
			call s:EchoWarning("The snip file couldn't be found or couldn't be read.")
		endif
	endif
endfunction

" ============================================================================
" ConfigureSnipWindow(): Set up the options for the snip window. {{{1
function! s:ConfigureSnipWindow()
	if g:quicktask_snip_win_maximize
		if g:quicktask_snip_win_split_direction == 'vertical'
			execute "vertical resize"
		else
			execute "resize"
		endif
	endif
	execute "nnoremap <silent> <buffer> <ESC> :bdelete<CR>"
endfunction


" ============================================================================
" AddNextTimeToTask(): Add the next logical timestamp to a task. {{{1
"
" Add the next timestamp to a task. If the task has no timestamps yet,
" add a starting time note. If it has a start with no end, add the end.
" If it has complete start and end notes, add a new start note.
function! s:AddNextTimeToTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:FindTaskStart(1)

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + &tabstop

	" Search downward, looking for either the end of the task block or
	" start/end notes and record them. Begin on the line immediately
	" following the task line.
	let current_line = line('.')+1
	let matched = 0
	while current_line <= line('$')
		" If we are still at the correct indent level
		if match(getline(current_line), '\v^\s{'.indent.'}') > -1
			" If this line is a sub-task, we have reached our location.
			if match(getline(current_line), '\v^\s*-') > -1
				call s:AddStartTimeToTask(current_line-1, indent)
				let matched = 1
				break
			" If this line is a Note, skip over it.
			elseif match(getline(current_line), '\v^\s*\*') > -1
				let current_line = current_line + 1
				continue
			" If this line is an Added/Start line, we have more checking to do.
			elseif match(getline(current_line), '\v^\s*\@') > -1
				if match(getline(current_line), '\vAdded \[') > -1
					" We skip over the Added line if it exists.
					let current_line = current_line + 1
					continue
				elseif match(getline(current_line), '\vStart \[') > -1
					if match(getline(current_line), '\v, end \[\d\d:\d\d\]') == -1
						call s:AddEndTimeToTask(current_line, indent)
						let matched = 1
						break
					endif
				else
					call s:AddStartTimeToTask(current_line-1, indent)
					let matched = 1
					break
				endif
			endif
		else
			" We reached the next task
			call s:AddStartTimeToTask(current_line-1, indent)
			break
		endif

		let current_line = current_line + 1
	endwhile
endfunction

" ============================================================================
" AddStartTimeToTask(): Add a new start time to a task. {{{1
"
" Called by AddNextTimeToTask() to create a new start time note.
function! s:AddStartTimeToTask(start, indent)
	" Place the cursor at the given start line.
	" call cursor(a:start, 0)

	" Create the physical indent.
	let physical_indent = repeat(" ", a:indent)

	" Get the timestamp string.
	let today = '['.strftime("%a %Y-%m-%d").']'
	let now = '['.strftime("%H:%M").']'

	call append(a:start, physical_indent."@ Start ".today." ".now)

	" If the current line is a task line, we have to indent the start time. If
	" not, then we don't.
	"if match(getline('.'), '\v^\s*-') > -1
	"	exe "normal! o\<Tab>@ Start ".today." ".now."\<Esc>"
	"else
	"	exe "normal! o@ Start ".today." ".now."\<Esc>"
	"endif
endfunction

" ============================================================================
" AddEndTimeToTask(): Add the end time to an existing start time. {{{1
"
" Called by AddNextTimeToTask() to append an end time to an existing start
" time note.
function! s:AddEndTimeToTask(start, indent)
	" Place the cursor at the given start line.
	call cursor(a:start, 0)

	if match(getline('.'), '\vStart \[') == -1
		call s:AddStartTimeToTask(a:start-1)
	endif

	" Now insert the end time.
	let now = '['.strftime("%H:%M").']'
	exe "normal! A, end ".now."\<Esc>"
endfunction

" ============================================================================
" TaskComplete(): Mark a task as complete (DONE). {{{1
"
" Mark a task as complete by placing a note at the very end of the task
" containing the keyword DONE followed by the current timestamp.
function! s:TaskComplete()
	" If we are not on a task line right now, we need to search up for one.
	call s:FindTaskStart(1)

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus the length of one
	" indent (the number of spaces in the user's tabstop).
	let indent = indent + &tabstop

	" Search downward, looking for either a reduction in the indentation level
	" or the end of the file. The first line to fail to match will be the line
	" AFTER our insertion point. Start searching on the line after the task
	" line.
	let current_line = line('.') + 1
	let matched = 0
	while current_line <= line('$')
		" If we are still at the correct indent level
		if match(getline(current_line), '\v^\s{'.indent.'}') == -1
			" Move the cursor to the line preceding this one.
			let start = current_line - 1
			" Break out, we have arrived.
			break
		endif

		let current_line = current_line + 1
	endwhile

	" Create the timestamp.
	let today = s:GetDatestamp('today')

	" Save the contents of register 'a'.
	" let old_a = @a
	" Create the DONE line and save it in register 'a'.
	" let @a = physical_indent.s:one_indent."* DONE ".today
	" Insert the DONE line.
	let physical_indent = repeat(" ", indent)
	call append(start, physical_indent."@ DONE ".today)
	"exe "normal! o\<Esc>\"aP"
	" Restore the value of register 'a'.
	"let @a = old_a
endfunction

" ============================================================================
" SaveOnFocusLost(): Save the current file silently. {{{1
"
" This will be called by an autocommand to save the current task list file
" when focus is lost.
function! s:SaveOnFocusLost()
	if &filetype == "quicktask"
		:silent! w
	endif
endfunction

" ============================================================================
" GetDatestamp(): Get a Quicktask-formatted datestamp. {{{1
"
" Datestamps are used throughout Quicktask both for user convenience of
" tracking their tasks in the continuum of the universe immemorial and also to
" locate current tasks. GetDatestamp() returns a Quicktask-formatted
" datestamp for the requested time relative to 'now.'
function! s:GetDatestamp(coordinate)
	if a:coordinate == 'today'
		return '['.strftime('%a %Y-%m-%d').']'
	elseif a:coordinate == 'tomorrow'
		return '['.strftime('%a %Y-%m-%d', localtime()+86400).']'
	elseif a:coordinate == 'yesterday'
		return '['.strftime('%a %Y-%m-%d', localtime()-86400).']'
	elseif a:coordinate == 'nextweek'
		return '['.strftime('%a %Y-%m-%d', localtime()+604800).']'
	endif

	" Always return something ("today" in this case).
	return '['.strftime('%a %Y-%m-%d').']'
endfunction

" ============================================================================
" GetTimestamp(): Get a Quicktask-formatted timestamp. {{{1
"
" Timestamps are used for the start and end times added to tasks and by the
" abbreviation system. GetTimestamp() returns a Quicktask-formatted timestamp
" for the current time.
function! s:GetTimestamp()
	return '['.strftime('%H:%M').']'
endfunction

" ============================================================================
" QTFoldLevel(): Returns the fold level of the current line. {{{1
"
" This is used by the Vim folding system to fold tasks based on their depth
" and relationship to one another.
function! QTFoldLevel(linenum)
	let pre_indent = indent(a:linenum-1) / &tabstop
	let cur_indent = indent(a:linenum) / &tabstop
	let nxt_indent = indent(a:linenum+1) / &tabstop

	if nxt_indent == cur_indent + 1
		return '>'.nxt_indent
	elseif pre_indent == cur_indent && nxt_indent < cur_indent
		return '<'.cur_indent
	else
		return cur_indent
	endif
endfunction

" ============================================================================
" AddNoteToTask(): Add a new note to a task. {{{1
"
" Add a new note to the task.
function! s:AddNoteToTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:FindTaskStart(1)

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + &tabstop

	let physical_indent = repeat(" ", indent)
	let note_line = physical_indent . '* '

	" Search downward, looking for existing note or beginning of Added note
	let current_line = line('.') + 1

	while current_line <= line('$')
		" If we are still at the correct indent level
		if match(getline(current_line), '\v^\s{'.indent.'}') > -1
			" If this line is a sub-task, we have reached our location.
			if match(getline(current_line), '\v^\s*-') > -1
				let current_line = current_line - 1
				break
			" If this line is an Added/Start line, we have reached our 
			" location.
			elseif match(getline(current_line), '\v^\s*\@') > -1
				let current_line = current_line - 1
				break
			" If this line is a note, keep looking.
			elseif match(getline(current_line), '\v^\s*\*') > -1
				let current_line = current_line + 1
				continue
			endif
		else
			" We have reached the end of the task; we have arrived.
			let current_line = current_line - 1
			break
		endif

		let current_line = current_line + 1
	endwhile

	" Add the note to current task and move the cursor to the note
	call append(current_line, [note_line])
	call cursor(current_line + 1, indent + 3)

	" Switch to insert mode to edit the note
	startinsert!
endfunction

" ============================================================================
" GetEpoch, GetDuration, GetTimes, PrintDuration, FormatDate, FormatDateWord {{{1
"
" These functions are unused at this time.
function! GetEpoch(timestring)
	return system("c:/cygwin/bin/ruby.exe -e 'require \"time\"; print Time.parse(ARGV[0]).to_i' -- ".a:timestring)
endfunction

function! GetDuration(times)
	let epochs = [ GetEpoch(a:times[0]), GetEpoch(a:times[1]) ]
	let difference = (epochs[1] - epochs[0]) / 60
	let duration = ''

	if difference > 60
		let duration .= (difference / 60).'h'
		let difference = difference % 60
	endif
	if difference > 0
		if len(duration) > 0
			let duration .= ' '
		endif
		let duration .= difference.'m'
	endif

	return duration
endfunction

function! GetTimes()
	let times = matchlist(getline('.'), '\v\[(\d\d:\d\d)\].*\[(\d\d:\d\d)\]')
	return [ times[1], times[2] ]
endfunction

function! PrintDuration()
	let times = GetTimes()
	let duration = GetDuration(times)
	exe "normal! A (duration ".duration.")\<ESC>"
endfunction

function! FormatDate(datestring)
	let newdate = substitute(system("c:/cygwin/bin/date.exe -d '".a:datestring."' +'%a %F'"), "\n", "", "g")
	return newdate
endfunction

function! FormatDateWord()
	let old_z = @z
	exe "normal! \"zyiW"
	let @z = '['.FormatDate(@z).']'
	exe "normal! ciW\<C-R>\<Esc>"
	let @z = old_z
endfunction

" ============================================================================
" QTFoldText(): Provide the text displayed on a fold when closed. {{{1
"
" This is used by the Vim folding system to find the text to display on fold
" headings when folds are closed. We use this to cause the headings to display
" in an indented fashion matching the tasks themselves.
function! QTFoldText()
	let lines = v:foldend - v:foldstart + 1
	return getline(v:foldstart).' ('.lines.')'
	"return substitute(getline(v:foldstart), "\s", '  ', 'g').' ('.lines.')'
endfunction

" ============================================================================
" CloseFoldIfOpen(): Quietly close a fold only if it is open. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! CloseFoldIfOpen()
	if foldclosed(line('.')) == -1
		silent! normal zc
	endif
endfunction

" ============================================================================
" OpenFoldIfClosed(): Quietly open a fold only if it is closed. {{{1
"
" This is used when automatically opening and closing folded tasks based on
" their status.
function! OpenFoldIfClosed()
	if foldclosed(line('.')) > -1
		execute "silent! normal ".foldlevel(line('.'))."zo"
	endif
endfunction

" ============================================================================
" ShowActiveTasksOnly(): Fold all completed tasks. {{{1
"
" The net result is that only incomplete (active) tasks remain open and
" visible in the list.
function! s:ShowActiveTasksOnly()
	let current_line = line('.')
	execute "normal! zR"
	execute "g/DONE\\|HELD/call CloseFoldIfOpen()"
	call cursor(current_line, 0)
endfunction

function! s:ShowTodayTasksOnly()
	execute "normal! zM"
	execute "g/".strftime("%Y-%m-%d")."/call OpenFoldIfClosed()"
	execute "normal! gg"
endfunction

" ============================================================================
" ShowWatchedTasksOnly(): Fold all except watched tasks. {{{1
"
" The net result is that only tasks that you are watching (containing "WATCH"
" remain open and visible in the list.
function! s:ShowWatchedTasksOnly()
	let current_line = line('.')
	execute "normal! zM"
	execute "g/WATCH/call OpenFoldIfClosed()"
	call cursor(current_line, 0)
endfunction

" ============================================================================
" FindIncompleteTimestamps(): Execute a search for incomplete timestamps. {{{1
"
" This function only sets the forward search pattern. It is called from a
" command that forces hlsearch to "on", which has the effect of highlighting
" any timestamp notes that have start times and no end times (presumably
" beceause you forgot to end them or they are still pending).
function! s:FindIncompleteTimestamps()
	let @/ = '@\sStart\s\[\w\w\w\s\d\d\d\d-\d\d-\d\d\]\s\[\d\d:\d\d\]$'
endfunction

" ============================================================================
" Key mappings {{{1
nnoremap <buffer> <Leader>tv :call <SID>SelectTask()<CR>
nnoremap <buffer> <Leader>tD :call <SID>TaskComplete()<CR>
nnoremap <buffer> <Leader>ta :call <SID>ShowActiveTasksOnly()<CR>
nnoremap <buffer> <Leader>tw :call <SID>ShowWatchedTasksOnly()<CR>
nnoremap <buffer> <Leader>ty :call <SID>ShowTodayTasksOnly()<CR>
nnoremap <buffer> <Leader>ts :call <SID>AddNextTimeToTask()<CR>
nnoremap <buffer> <Leader>tO :call <SID>AddTaskAbove()<CR>
nnoremap <buffer> <Leader>to :call <SID>AddTaskBelow()<CR>
nnoremap <buffer> <Leader>tn :call <SID>AddNoteToTask()<CR>
nnoremap <buffer> <Leader>tc :call <SID>AddChildTask()<CR>
nnoremap <buffer> <Leader>tu :call <SID>MoveTaskUp()<CR>
nnoremap <buffer> <Leader>td :call <SID>MoveTaskDown()<CR>
nnoremap <buffer> <Leader>tS :call <SID>AddSnipToTask()<CR>
nnoremap <buffer> <Leader>tfi :call <SID>FindIncompleteTimestamps()<CR>:silent set hlsearch \| echo<CR>
" I don't know if this is rude.
nnoremap <buffer> <CR> :call OpenSnip()<CR>

" ============================================================================
" Autocommands {{{1
if g:quicktask_autosave
	autocmd BufLeave,FocusLost * call <SID>SaveOnFocusLost()
endif

" ============================================================================
" Abbreviations {{{1
iabbrev <expr> @today <SID>GetDatestamp('today')
iabbrev <expr> @tomorrow <SID>GetDatestamp('tomorrow')
iabbrev <expr> @yesterday <SID>GetDatestamp('yesterday')
iabbrev <expr> @nextweek <SID>GetDatestamp('nextweek')
iabbrev <expr> @now <SID>GetTimestamp()

" Compatibility option reset: {{{1
let &cpo = s:cpo_save
unlet s:cpo_save
