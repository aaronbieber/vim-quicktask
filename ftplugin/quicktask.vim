" quicktask.vim: A lightweight task management plugin.
"
" Author:	Aaron Bieber
" Version:	1.0
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
setlocal noexpandtab
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
let s:version = '1.0'

" Global options, defaults
if !exists("g:quicktask_autosave")
	let g:quicktask_autosave = 0
endif

" ============================================================================
" GetTaskIndent(): Return current indent level. {{{1
"
" With the cursor on a task line, return the indent level of that task.
function! s:GetTaskIndent()
	if match(getline(line('.')), '^\t*- ') > -1
		" What is the indentation level of this task?
		let matches = matchlist(getline('.'), '\v^(\t{-})-')
		let indent = len(matches[1])

		return indent
	endif

	return -1
endfunction

" ============================================================================
" SearchToTaskStart(): Find the start of the current task. {{{1
"
" Search backwards for a task line. This function moves the cursor.
" If the cursor is already on a task line, do nothing.
function! s:SearchToTaskStart()
	call search('^\t*- ', 'bcW')
endfunction

" ============================================================================
" SearchToTaskEnd(): Find the end of the current task. {{{1
"
" Search forward for the end of the current task. If we do not start on a task 
" line, we first search backwards for a task line. We then search forward for 
" the first line that isn't a part of that task, which may be the next task, 
" the next section, or the end of the file.
function! s:SearchToTaskEnd()
	" If we are not on a task line
	if match(getline(line('.')), '^\t*- ') == -1
		" Find the task line above
		call s:SearchToTaskStart()
	endif

	" Get the indent of this task
	let indent = s:GetTaskIndent()

	if indent > -1
		" Search downward, looking for either the end of the task block or
		" start/end notes and record them. Begin on the line immediately
		" following the task line.

		let task_end_line = search('^\t\{0,'.indent.'}[^\t]', 'W')

		" Move the cursor to the line immediately prior, which should be the 
		" last line of the task we are looking for.
		call cursor(task_end_line-1,0)
	endif
endfunction

" ============================================================================
" AddTask(after, indent): Add a task to the file. {{{1
"
" Add a 'skeleton' task to the file after the line given and at the indent 
" level specified.
function! s:AddTask(after, indent, move_cursor)
	if a:indent > 0
		let physical_indent = repeat("\t", a:indent)
	else
		let physical_indent = ''
	endif

	" Compose the two lines to insert
	let task_line = physical_indent . "- "
	let date_line = physical_indent . "\t* Added [".strftime("%a %Y-%m-%d")."]"
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
	call s:SearchToTaskStart()
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
	" Find current task
	call s:SearchToTaskStart()
	" Get indent (this will be our new indent)
	let indent = s:GetTaskIndent()
	if indent < 0
		let indent = 1
	endif

	" Find the end of the task and note the line number
	call s:SearchToTaskEnd()
	let task_line_num = line('.')

	" Append the task, moving the cursor and starting insert
	call s:AddTask(task_line_num, indent, 1)
endfunction

" ============================================================================
" AddChildTask(): Add a task as a child of the current task. {{{1
function! s:AddChildTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:SearchToTaskStart()

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()
	if indent < 0
		let indent = 1
	else
		" The indent we want to find is the tasks's indent plus one.
		let indent = indent + 1
	endif

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
				call s:AddTask(current_line-1, indent, 1)
				let matched = 1
				break
			endif
		else
			" We reached the next task
			call s:AddTask(current_line-1, indent, 1)
			break
		endif

		let current_line = current_line + 1
	endwhile
endfunction

" ============================================================================
" MoveTaskDown(): Move the current task down. {{{1
"
" Move the current task below the following task.
function! s:MoveTaskDown()
	call s:SearchToTaskStart()
	let task_start = line('.')

	call s:SearchToTaskEnd()
	let task_end = line('.')
	call cursor(task_start)

	" Pull the contents of the task into a list of lines
	let task_text = getline(task_start, task_end)
	" Delete the task from the buffer
	execute "silent! ".task_start.",".task_end."d"

	call s:SearchToTaskEnd()
	let insert_line = line('.')
	call append(insert_line, task_text)
	call cursor(insert_line+1, 0)
endfunction

" ============================================================================
" MoveTaskUp(): Move the current task up. {{{1
"
" Move the current task up above the preceding task.
function! s:MoveTaskUp()
	call s:SearchToTaskStart()
	let task_start = line('.')
	let indent = s:GetTaskIndent()

	call s:SearchToTaskEnd()
	let task_end = line('.')

	" Is the preceding line at the same or greater indent?
	if match(getline(task_start-1), '^\t\{'.indent.',}') > -1
		call cursor(task_start-1, 0)
		call s:SearchToTaskStart()
		let final_line = line('.')
		call s:MoveTaskDown()
		call cursor(final_line, 0)
	endif
endfunction

" ============================================================================
" AddSnipToTask(): Add a new snip to a task as a note. {{{1
"
" Add a new snip (external note) to a task. This will be overhauled in 2.0 
" when snips are in external files.
function! s:AddSnipToTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:SearchToTaskStart()

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + 1
	let physical_indent = repeat("\t", indent)

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
				  \match(getline(current_line), '\v\[Snip ') > -1

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

	" Generate a UUID
	let uuid = substitute(system('uuidgen'), '\n', '', '')

	" Insert the snip placeholder in the task
	call append(snip_line, physical_indent . '* [Snip '.uuid.']')

	" Insert the snip contents
	call append(line('$')-1, [ "[+".uuid."]", "", "[-".uuid."]" ])
	call cursor(line('$')-2, 0)
	startinsert!
endfunction

" ============================================================================
" JumpToSnip(): Jump from a snip marker to the snip and back. {{{1
"
" Jump from a snip's GUID to the snip itself or back to the GUID marker. This 
" will be deprecated when snips become external file references.
function! s:JumpToSnip()
	if match(getline('.'), '\v\[(Snip |-|\+)[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}\]') > -1
		let snip_parts = matchlist(getline('.'), '\v\[(Snip |-|\+)([a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12})\]')
		let snip_prefix = snip_parts[1]
		let snip_uuid = snip_parts[2]
		echom "Found a snip starting with ".snip_prefix
		if len(snip_prefix) && len(snip_uuid)
			if snip_prefix == 'Snip '
				call search('\v^\[\+'.snip_uuid.'\]')
			elseif snip_prefix == '+' || snip_prefix == '-'
				call search('\v\[Snip '.snip_uuid.'\]', 'w')
			endif
		else
			echom "The snip could not be found."
		endif
	endif
endfunction

" ============================================================================
" AddNextTimeToTask(): Add the next logical timestamp to a task. {{{1
"
" Add the next timestamp to a task. If the task has no timestamps yet,
" add a starting time note. If it has a start with no end, add the end.
" If it has complete start and end notes, add a new start note.
function! s:AddNextTimeToTask()
	" If we are not on a task line right now, we need to search up for one.
	call s:SearchToTaskStart()

	" What is the indentation level of this task?
	let indent = s:GetTaskIndent()

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + 1

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
			" If this line is a note, we have more checking to do.
			elseif match(getline(current_line), '\v^\s*\*') > -1
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
	let physical_indent = repeat("\t", a:indent)

	" Get the timestamp string.
	let today = '['.strftime("%a %Y-%m-%d").']'
	let now = '['.strftime("%H:%M").']'

	call append(a:start, physical_indent."* Start ".today." ".now)

	" If the current line is a task line, we have to indent the start time. If 
	" not, then we don't.
	"if match(getline('.'), '\v^\t*-') > -1
	"	exe "normal! o\<Tab>* Start ".today." ".now."\<Esc>"
	"else
	"	exe "normal! o* Start ".today." ".now."\<Esc>"
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
	if match(getline(line('.')), '^\t*- ') == -1
		exe "normal! ?^\t*- \<CR>"
	endif

	" What is the indentation level of this task?
	let matches = matchlist(getline('.'), '\v^(.{-})-')
	" Save the actual tab characters for use in the completion bullet later.
	let physical_indent = matches[1]
	" Get the size of the indent for use in a regexp.
	let indent = len(physical_indent)

	" The indent we want to find is the tasks's indent plus one.
	let indent = indent + 1

	" Search downward, looking for either a reduction in the indentation level 
	" or the end of the file. The first line to fail to match will be the line 
	" AFTER our insertion point. Start searching on the line after the task 
	" line.
	let current_line = line('.')+1
	let matched = 0
	while current_line <= line('$')
		" If we are still at the correct indent level
		if match(getline(current_line), '\v^\t{'.indent.'}') == -1
			" Move the cursor to the line preceding this one.
			call cursor(current_line-1, 0)
			" Break out, we have arrived.
			break
		endif

		let current_line = current_line + 1
	endwhile

	" Create the timestamp.

	let today = '['.strftime("%a %Y-%m-%d").']'
	" Save the contents of register 'a'.
	let old_a = @a
	" Create the DONE line and save it in register 'a'.
	let @a = physical_indent."\t"."* DONE ".today
	" Insert the DONE line.
	exe "normal! o\<Esc>\"aP"
	" Restore the value of register 'a'.
	let @a = old_a
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
" GetEpoch, GetDuration, GetTimes, PrintDuration, FormatDate, FormatDateWord {{{1
"
" These functions are unused at this time.
function! GetEpoch(timestring)
	return system("ruby -e 'require \"time\"; print Time.parse(ARGV[0]).to_i' -- ".a:timestring)
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
	return substitute(getline(v:foldstart), "\t", '  ', 'g').' ('.lines.')'
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
" FindIncompleteTimestamps(): Execute a search for incomplete timestamps. {{{1
"
" This function only sets the forward search pattern. It is called from a 
" command that forces hlsearch to "on", which has the effect of highlighting 
" any timestamp notes that have start times and no end times (presumably 
" beceause you forgot to end them or they are still pending).
function! s:FindIncompleteTimestamps()
	let @/ = '\*\sStart\s\[\w\w\w\s\d\d\d\d-\d\d-\d\d\]\s\[\d\d:\d\d\]$'
endfunction

" ============================================================================
" Key mappings {{{1
nmap <Leader>tD :call <SID>TaskComplete()<CR>
nmap <Leader>ta :call <SID>ShowActiveTasksOnly()<CR>
nmap <Leader>ty :call <SID>ShowTodayTasksOnly()<CR>
nmap <Leader>ts :call <SID>AddNextTimeToTask()<CR>
nmap <Leader>tO :call <SID>AddTaskAbove()<CR>
nmap <Leader>to :call <SID>AddTaskBelow()<CR>
nmap <Leader>tc :call <SID>AddChildTask()<CR>
nmap <Leader>tu :call <SID>MoveTaskUp()<CR>
nmap <Leader>td :call <SID>MoveTaskDown()<CR>
nmap <Leader>tS :call <SID>AddSnipToTask()<CR>
nmap <Leader>tj :call <SID>JumpToSnip()<CR>
nmap <Leader>tfi :call <SID>FindIncompleteTimestamps()<CR>:silent set hlsearch \| echo<CR>
" I don't know if this is rude.
nnoremap <CR> :call <SID>JumpToSnip()<CR>

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
