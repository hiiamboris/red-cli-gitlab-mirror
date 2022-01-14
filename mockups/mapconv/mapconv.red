Red [
	title: "Map & construction syntax converter"
	purpose: "Convert old #() into new #[] map syntax and vice versa" 
]

; no idea how can one possibly compile this mess of Red & R/S dependencies:
; #include %/d/devel/red/red-src/red/environment/console/cli/input.red

do [
#include %/d/devel/red/common/glob.red
#include %/d/devel/red/common/composite.red
#include %/d/devel/red/common/count.red
#include %/d/devel/red/cli/cli.red

data: []
total: 0x0

is-dir?: func [file [file!]] [none <> query dirize file]

map+datatype!: make typeset! [map! datatype!]
open: []
tracer: function [
    event [word!]
    input [string! binary!]
    type  [datatype! word!]
    line  [integer!]
    token [any-type!]
][
	[prescan open close error]
	switch event [
		prescan [
			if all [datatype? type  find map+datatype! type] [		;-- both #() and #[] here
				input: next input
				return no								;-- skip '#', load paren/block
			]
		]
		open [
			if all [datatype? type  find any-list! type] [append open index? input]
		]
		close [
			if all [datatype? type  find any-list! type] [
				s: take/last open  e: index? input
				p: at head input s
				if #"#" = p/-1 [
					repend last data [line  to char! p/1  s  e]
				]
			]
		]
		error [
			change skip tail data -2 yes
			input: next input
			return no									;-- needed for lexer regressions
		]
	]
	true
]

display: function [] [
	foreach [file errors? match] data [
		if empty? match [continue]
		blocks: count match #"["
		parens: count match #"("
		set 'total total + as-pair blocks parens
		errors?: pick [" WARNING: HAS LOADING ERRORS!" ""] errors?
		print `"(to-local-file file): #[(blocks)] #(\(parens))(errors?)"`
	]
	n: (length? data) / 3
	print `"Total: #[(total/1)] #(\(total/2)) across (n) files"`
]

swap: function [] [
	modified: 0
	foreach [file errors? match] data [
		if empty? match [continue]
		bin: read/binary file
		foreach [_ _ s e] match [
			change at bin s select "[([" to char! bin/:s
			change at bin e select "])]" to char! bin/:e
		] 
		errors?: pick [" WARNING: HAS LOADING ERRORS!" ""] errors?
		print `"written (to-local-file file)(errors?)"`
		write/binary file bin
		modified: modified + 1
	]
	n: (length? data) / 3
	print `"Written total (modified) of (n) files"`
]

mapconv: function [
	"Analyze & convert #() and #[] syntax constructs"
	root [file!] "File, mask or directory"
	/analyze "Only count occurrences & show (default)"
	/convert "Swap #() and #[] syntax in files"
	/a "alias /analyze"
	/c "alias /convert" 
][
	either is-dir? root [
		mask: "*.red"
	][
		set [root mask] split-path root					;-- e.g. /path/*.xyz
	]
	files: glob/files/from/only root as {} mask
	saved-dir: what-dir
	change-dir root
	
	foreach file files [
		repend data [file no copy []]
		clear open
		transcode/trace read/binary file :tracer
	]
	
	unless convert [display]
	; unless any [analyze convert 0x0 = total] [
		; answer: ask "Proceed with conversion? (y/N) "
		; if find ["y" "yes"] answer [convert: yes]
	; ]
	if convert [swap]
	
	change-dir saved-dir
]

cli/process-into mapconv
]