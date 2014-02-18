" Recognize .qt and .quicktask files
if has("autocmd")
    autocmd BufNewFile,BufRead *.qt setf quicktask
    autocmd BufNewFile,BufRead *.quicktask setf quicktask
endif
