" quicktask.vim: A lightweight task management plugin.
"
" Author:   Aaron Bieber
" Version:  1.4
" Date:     25 January 2014
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

" Global user configurable variables
let g:quicktask_default_filename = "todo.txt"
let g:quicktask_window_height    = 15

" Set all buffer-local settings: {{{1
let s:version = '1.4'

if !exists('quicktask_filenames')
    let s:quicktask_filenames = []
endif

" script local variables
function! s:TaskFileNamesAdd(fn)
    call filter(s:quicktask_filenames, "v:val !=# '" . a:fn . "'")
    let s:quicktask_filenames += [a:fn]
endf

" always 10 chars height window
function! s:SetBufferFixedSize()
    if len(tabpagebuflist())
        exe "resize " . g:quicktask_window_height
        set winfixheight
    endif
endf

" Closes the quicktask window in the current tab
function! s:QTclose()
    for l:fn in s:quicktask_filenames
        let l:bn = bufnr(l:fn)
        if index(tabpagebuflist(), l:bn) != -1
            exe "bdelete " . l:bn
            call filter(s:quicktask_filenames, "v:val !=# '" . l:fn . "'")
            return
        endif
    endfor
endf

" Open the todo in seperate window
function! s:QTopen(filename)
    if len(a:filename)
        let l:fn = a:filename
    else
        let l:fn = g:quicktask_default_filename
    endif

    let l:path = findfile(l:fn, ".;")
    if !len(l:path)
        echoerr l:fn . " doesn't exist!"
        return
    endif

    let l:buffername = bufname(l:path)
    let l:buffnumber = bufnr(l:buffername)
    if !len(l:buffername) || index(tabpagebuflist(), l:buffnumber) == -1
        exe "split " . l:path

        if &filetype !=# 'quicktask'
            exe "q"
            echoerr l:path . " is not a quicktask file!"
            return
        endif

        " now that window is created (split), the buffer exists
        call s:TaskFileNamesAdd(l:path)

        call s:SetBufferFixedSize()
    endif
endf

" autocommands
augroup quicktask-plugin-autocommands
    au!
    " if the file that is opened is a quicktask file, add it to the array of
    " opened quicktask files.
    autocmd BufWinEnter,FileType quicktask call s:TaskFileNamesAdd(bufname("%"))
augroup end

" ============================================================================
" QTInit(): Initialize a new task list. {{{1
"
" Create a new Quicktask file in a new buffer.
function! QTInit()
    if len(expand('%:p')) || &modified || !&modifiable
        execute "new"
    endif
    setlocal filetype=quicktask
    let new_task_list = [   '# Quicktask v'.s:version,
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
command! QTclose silent call s:QTclose()
command! -nargs=? QTopen silent call s:QTopen(<q-args>)

