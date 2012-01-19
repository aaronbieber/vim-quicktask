" quicktask.vim: A lightweight task management plugin.
"
" Author:	Aaron Bieber
" Version:	1.0
" Date:		10 January 2012
"
" This syntax file was based upon the work of Eric Talevich in his 
" "todolist" syntax format. Though many patterns have been re-worked, Eric's 
" base file was the inspiration that made Quicktask possible.
"
" See the documentation in doc/quicktask.txt

if exists("b:current_syntax")
  finish
endif

" Save compatibility and force vim compatibility
let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Sections, tasks, and notes (the building blocks of any list)
syn match	quicktaskSection		'^.*:\s*$'
									\ contains=quicktaskMarker,@Spell
syn match	quicktaskNote			'^\(\t*\)[*].\{-}\n\%(\1\t[^*].\{-}\n\)*'
									\ contains=quicktaskMarker,quicktaskTicket,@Spell,quicktaskConstant,
									 \quicktaskDone,quicktaskDatestamp,quicktaskTimestamp,quicktaskSnip,
									 \quicktaskIncomplete
syn match	quicktaskTask			'^\(\t*\)[-].\{-}\n\%(\1\t[^-*].\{-}\n\)*'
									\ contains=quicktaskMarker,quicktaskTicket,@Spell,quicktaskConstant,quicktaskDatestamp,quicktaskTimestamp,quicktaskSnip

" Highlight keywords in todo items and notes:
" TODO, FIXME, NOTE, WTF are self-explanatory.
" AFB = Awaiting Feedback, ENH = Enhancement
syn keyword	quicktaskMarker			contained TODO FIXME NOTE ENH WTF AFB ???
syn keyword	quicktaskDone			contained DONE WATCH HELD

" Dates and times
syn match	quicktaskDatestamp		display '\[... \d\d\d\d-\d\d-\d\d\]'
syn match	quicktaskTimestamp		'\[\d\d:\d\d\]'
syn match	quicktaskIncomplete		display '\* Start\s\[\w\w\w\s\d\d\d\d-\d\d-\d\d\]\s\[\d\d:\d\d\],\@!'hs=s+25
									\ contains=quicktaskDatestamp

" JIRA tickets, e.g. PROJECTNAME-1234
syn match	quicktaskTicket			display '\C[A-Z]\+-[0-9]\+'

" Snips (not currently supported in the official release)
syn match	quicktaskSnip			display '\[\(Snip \|-\|+\)[a-z0-9]\{8}-
									\[a-z0-9]\{4}-[a-z0-9]\{4}-[a-z0-9]\{4}-
									\[a-z0-9]\{12}\]'


syn match	quicktaskConstant		'\<[~yn]\>'
syn keyword	quicktaskConstant		true True TRUE false False FALSE
syn keyword	quicktaskConstant		yes Yes YES no No NO not Not NOT shall Shall SHALL
syn keyword	quicktaskConstant		null Null NULL nil Nil NIL

" 'Real' comments (not often used)
syn match	quicktaskComment		"#.*" contains=@Spell

" Highlight links
hi def link quicktaskSection		Title
hi def link quicktaskTask			Normal
hi def link quicktaskNote			Comment
hi def link quicktaskDone			Constant
hi def link quicktaskMarker			Todo
hi def link quicktaskComment		Comment
hi def link quicktaskSnip			Number
hi def link quicktaskDatestamp		Special
hi def link quicktaskTimestamp		Special
hi def link quicktaskConstant		Constant
hi def link quicktaskIncomplete		Error
hi def link quicktaskTicket			Special

let b:current_syntax = "quicktask"

let &cpo = s:cpo_save
unlet s:cpo_save
