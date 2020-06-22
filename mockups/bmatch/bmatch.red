Red [
	Title:   "CLI Bracket matching detector for Red scripts"
	Purpose: {
		Ever had an error about unclosed bracket in a 1000+ line file?
		This script turns the challenge of finding it into a triviality.
	}
	Author:   @hiiamboris
	License: 'BSD-3
	Usage:   {
		bmatch <filename.red>
	}
]

#include %../../cli.red

; #include %../../../common/tabs.red						;-- these are needed for compilation
; #include %../../../common/composite.red
														;-- these can be used when interpeted
#include https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/tabs.red
#include https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/composite.red

non-space: charset [not " "]
tag-1st:   charset [not " ^-=><[](){};^""]
line: indent: 0x0
pos: map: []

extract-brackets: function [text tab /extern map script] [
	repeat iline length? text [							;-- build a map of brackets: [line-number indent-size brackets.. ...]
		line: detab/size text/:iline tab

		indent1: offset? line any [find line non-space  tail line]
		replace line "|" " "							;-- special case for parse's `| [...` pattern: ignore `|`
		indent2: offset? line any [find line non-space  tail line]
		indent: either indent1 = indent2 [indent1][as-pair indent1 indent2]		;-- allow 2 indent variants

		if indent = length? line [continue]				;-- empty line
		map: insert insert map iline indent

		stack: []										;-- deep strings (for curly braces which count opened/closing markers)
		parse line [collect after map any [
			if (empty? stack) [							;-- inside a block
				keep copy _ ["}" | "[" | "]" | "(" | ")"]
			|	s: any "%" e: keep copy _ "{"
				(append stack level: offset? s e)
			|	";" to end
			|	{"} any [{^^^^} | {^^"} | not {"} skip]
				[{"} | (print #composite "(script): Open string literal at line (iline)")]
			|	{<} tag-1st
				[thru {>} | (print #composite "(script): Open tag at line (iline)")]
			]

		|	[											;-- inside a string
				if (level = 0) [						;-- inside normal curly
					"^^^^" | "^^}" | "^^{"				;-- allow escape chars
				|	keep copy _ "{" (append stack 0)	;-- allow reentry
				]
			|	copy _ "}" level "%" keep (_) (level: take/last stack)
			]

		|	skip
		]]
	]
	map: head map
]

read-until: function [end-marker /local line1 indent1 /extern tol pos script] [
	indent1: indent  line1: line					;-- remember coordinates of the opening bracket
	parse pos [
		while [
			set line integer! set indent [integer! | pair!]
			(if integer? indent [set 'indent indent * 1x1])
		|	"[" pos: (read-until "]") :pos
		|	"(" pos: (read-until ")") :pos
		|	"{" pos: (read-until "}") :pos
		|	end-marker pos:
			(
				found?: yes								;@@ workaround for #4202 - can't `exit`
				if all [
					tol < absolute indent/1 - indent1/1
					tol < absolute indent/1 - indent1/2
					tol < absolute indent/2 - indent1/1
					tol < absolute indent/2 - indent1/2
				][
					print #composite "(script): Unbalanced (end-marker) indentation between lines (line1) and (line)"
				]
			)
			break
		|	pos: skip (print #composite "(script): Unexpected occurrence of (pos/1) on line (line)")
		]
		(unless found? [print #composite "(script): No ending (end-marker) after line (line1)"])
	]
]


bmatch: func [
	"Brackets matching detector"
	script         [file!]    "Filename to scan"
	/tabsize   tab [integer!] "Override tab size (default: 4)"
	/tolerance tol [integer!] "Min. indentation mismatch to report (default: 0)"
][
	tol: max 0 any [tol 0]
	tab: max 0 any [tab 4]

	set 'system/words/tol    tol						;@@ workarounds for compiler not supporting funcs withing funcs
	set 'system/words/script script
	extract-brackets read/lines script tab
	read-until [end]
]

cli/process-into bmatch

