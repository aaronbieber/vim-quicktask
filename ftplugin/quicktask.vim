let s:cpo_save = &cpo
set cpo&vim

setlocal comments=b:#,f:-,f:*
setlocal formatoptions=qnwta
setlocal spell

" Folding
setlocal foldmethod=expr
setlocal foldexpr=TodoFoldLevel(v:lnum)
setlocal fillchars="fold: "

setlocal shiftwidth=2
setlocal tabstop=2

" GetTaskIndent():
" 	With the cursor on a task line, return the indent level of that task.
function! s:GetTaskIndent()
	if match(getline(line('.')), '^\t*- ') > -1
		" What is the indentation level of this task?
		let matches = matchlist(getline('.'), '\v^(.{-})-')
		let indent = len(matches[1])

		return indent
	endif

	return -1
endfunction

" SearchToTaskStart():
" 	Search backwards for a task line. This function moves the cursor.
" 	If the cursor is already on a task line, do nothing.
function! s:SearchToTaskStart()
	if match(getline(line('.')), '^\t*- ') == -1
		execute "normal! ?^\t*- \<CR>"
	endif
endfunction

" SearchToTaskEnd():
" 	Search forward for the end of the current task. If we do not start on a task 
" 	line, we first search backwards for a task line. We then search forward for 
" 	the first line that isn't a part of that task, which may be the next task, 
" 	the next section, or the end of the file.
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
		"let current_line = line('.')+1
		"let indent = indent + 1
		"let matched = 0
		"while current_line <= line('$')
		"	" If we no longer at the correct indent level
		"	if match(getline(current_line), '\v^\s{'.indent.'}') == -1
		"		" We reached the next task or section
		"		break
		"	endif

		"	let current_line = current_line + 1
		"endwhile

		"call cursor(current_line-1, 1)
		execute "normal! /\\v^\t\{0,".indent."}[^\t]/-1\<CR>"
	endif
endfunction

" AddTaskAbove():
" 	Add a task above the current task, at the current task's level.
function! s:AddTaskAbove()
	call s:SearchToTaskStart()
	let indent = s:GetTaskIndent()
	let task_line_num = line('.')
	
	if indent > -1
		let physical_indent = repeat("\t", indent)

		" Compose the two lines to insert
		let task_line = physical_indent . "- "
		let date_line = physical_indent . "\t* Added [".strftime("%a %Y-%m-%d")."]"
		call append(task_line_num-1, [ task_line, date_line ])
		call cursor(task_line_num, len(getline(task_line_num)))

		" Leave us in insert mode! Please!
		startinsert!
	endif
endfunction

" AddTaskBelow():
" 	Add a task below the current task, at the current task's level.
function! s:AddTaskBelow()
	" Find current task
	call s:SearchToTaskStart()
	" Get indent (this will be our new indent)
	let indent = s:GetTaskIndent()

	if indent > -1
		let physical_indent = repeat("\t", indent)
		let task_line = physical_indent . "- "
		let date_line = physical_indent . "\t* Added [".strftime("%a %Y-%m-%d")."]"

		" Move to the end
		call s:SearchToTaskEnd()
		let task_line_num = line('.')

		"execute "normal! o\<CR>\<Esc>k"
		call append(task_line_num, [ task_line, date_line ])
		call cursor(task_line_num+1, len(getline(task_line_num+1)))

		startinsert!
	endif
endfunction

" MoveTaskDown():
" 	Move the current task below the following task.
function! s:MoveTaskDown()
	call s:SearchToTaskStart()
	let task_start = line('.')

	call s:SearchToTaskEnd()
	let task_end = line('.')
	call cursor(task_start)

	" Pull the contents of the task into a list of lines
	let task_text = getline(task_start, task_end)
	" Delete the task from the buffer
	execute task_start.",".task_end."d"

	call s:SearchToTaskEnd()
	let insert_line = line('.')
	call append(insert_line, task_text)
	call cursor(insert_line+1, 0)
endfunction

" MoveTaskUp():
" 	Move the current task up above the preceding task.
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

" AddSnipToTask():
" 	Add a new snip (external note) to a task.
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

" AddNextTimeToTask():
" 	Add the next timestamp to a task. If the task has no timestamps yet,
" 	add a starting time note. If it has a start with no end, add the end.
" 	If it has complete start and end notes, add a new start note.
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
				call s:AddStartTimeToTask(current_line-1)
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
						call s:AddEndTimeToTask(current_line)
						let matched = 1
						break
					endif
				else
					call s:AddStartTimeToTask(current_line-1)
					let matched = 1
					break
				endif
			endif
		else
			" We reached the next task
			call s:AddStartTimeToTask(current_line-1)
			break
		endif

		let current_line = current_line + 1
	endwhile
endfunction

function! s:AddStartTimeToTask(start)
	" Place the cursor at the given start line.
	call cursor(a:start, 0)

	" Get the timestamp string.

	let today = '['.strftime("%a %Y-%m-%d").']'
	let now = '['.strftime("%H:%M").']'

	" If the current line is a task line, we have to indent the start time. If 
	" not, then we don't.
	if match(getline('.'), '\v^\s*-') > -1
		exe "normal! o\<Tab>* Start ".today." ".now."\<Esc>"
	else
		exe "normal! o* Start ".today." ".now."\<Esc>"
	endif
endfunction

function! s:AddEndTimeToTask(start)
	" Place the cursor at the given start line.
	call cursor(a:start, 0)

	if match(getline('.'), '\vStart \[') == -1
		call s:AddStartTimeToTask(a:start-1)
	endif

	" Now insert the end time.
	let now = '['.strftime("%H:%M").']'
	exe "normal! A, end ".now."\<Esc>"
endfunction

function! s:SetCurrentTask()
	" Store the current cursor location.
	let cursorpos = getpos('.')

	" Remove any existing task markers.
	exe "%s/- >> /- /g"

	" Restore the cursor position (this is important).
	call cursor(cursorpos[1:])

	" Find the task line. Are we on it right now? If not, search backwards.
	if match(getline(line('.')), '^\t*- ') == -1
		exe "normal! ?^\t*- \<CR>"
	endif

	" Start at the beginning of the line, anyway.
	normal! |
	" See if this is the current task already.
	if search('>>', 'n', line('.')) > 0
		" Delete the marker
		exe "normal! |/>>\<CR>dW"
	else
		" Create a new marker
		exe "normal! |/-\<CR>a >>\<Esc>"
	endif
endfunction

" TaskComplete()
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

function! s:SaveOnFocusLost()
	if &filetype == "quicktask"
		:silent! w
	endif
endfunction

function! TodoFoldLevel(linenum)
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

function! TodoFoldText()
	let lines = v:foldend - v:foldstart + 1
	return substitute(getline(v:foldstart), "\t", '  ', 'g').' ('.lines.')'
endfunction

set foldtext=TodoFoldText()

function! CloseFoldIfOpen()
	if foldclosed(line('.')) == -1
		silent! normal zc
	endif
endfunction

function! OpenFoldIfClosed()
	if foldclosed(line('.')) > -1
		execute "silent! normal ".foldlevel(line('.'))."zo"
	endif
endfunction

function! s:ShowActiveTasksOnly()
	let current_line = line('.')
	exe "normal! zR:g/DONE\\|HELD/call CloseFoldIfOpen()\<CR>"
	call cursor(current_line, 0)
endfunction

function! s:FindIncompleteTimestamps()
	let @/ = '\*\sStart\s\[\w\w\w\s\d\d\d\d-\d\d-\d\d\]\s\[\d\d:\d\d\]$'
endfunction

nmap <Leader>tt :call <SID>SetCurrentTask()<CR>
nmap <Leader>tc gg/>>z.
nmap <Leader>tD :call <SID>TaskComplete()<CR>
nmap <Leader>ta :call <SID>ShowActiveTasksOnly()<CR>
nmap <Leader>ty zM:exe ":g/".strftime("%Y-%m-%d")."/call OpenFoldIfClosed()"<CR>gg
nmap <Leader>ts :call <SID>AddNextTimeToTask()<CR>
nmap <Leader>tO :call <SID>AddTaskAbove()<CR>
nmap <Leader>to :call <SID>AddTaskBelow()<CR>
nmap <Leader>tu :call <SID>MoveTaskUp()<CR>
nmap <Leader>td :call <SID>MoveTaskDown()<CR>
nmap <Leader>tS :call <SID>AddSnipToTask()<CR>
nmap <Leader>tj :call <SID>JumpToSnip()<CR>
nmap <Leader>tfi :call <SID>FindIncompleteTimestamps()<CR>:silent set hlsearch \| echo<CR>

" I don't know if this is rude.
nnoremap <CR> :call <SID>JumpToSnip()<CR>

autocmd BufLeave,FocusLost * call <SID>SaveOnFocusLost()

let &cpo = s:cpo_save
unlet s:cpo_save
