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
;#include %/d/devel/red/cli/cli.red

data: []
total: 0x0
width: 0

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
	on-error: [
		change skip tail data -2 yes
		input: next input
		return no										;-- needed for lexer regressions
	]
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
				unless s on-error						;-- unbalanced brackets or free-form file?
				p: at head input s
				if #"#" = p/-1 [
					repend last data [line  to char! p/1  s  e]
				]
			]
		]
		error [do on-error]
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
		print pad `"(to-local-file file): #[(blocks)] #(\(parens))(errors?)"` width
	]
	n: (length? data) / 3
	print pad `"Total: #[(total/1)] #(\(total/2)) across (n) files"` width
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
		print pad `"written (to-local-file file)(errors?)"` width
		write/binary file bin
		modified: modified + 1
	]
	n: (length? data) / 3
	print pad `"Written total (modified) of (n) files"` width
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
	files: either not empty? intersect "*?" as "" mask [
		glob/files/from/only root as {} mask
	][
		reduce [rejoin [dirize root mask]]				;-- no globbing if a single file
	]
	saved-dir: what-dir
	change-dir root
	
	set 'width any [attempt [system/console/size/x - 1] 80]
	foreach file files [
		prin rejoin [pad rejoin [to-local-file file "..."] width - 3 cr]
		repend data [file no copy []]
		clear open
		bin: read/binary file
		parse bin [to ["Red" any ws block!] bin:]		;-- try to ignore what's before the header, e.g. #/bin/red
		transcode/trace bin :tracer						;-- but still process if no header was found (maybe a headerless script)
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