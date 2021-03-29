Red [
	title: "Parse tool"
	purpose: "Use Parse power from command line"
	author: @hiiamboris
	license: BSD-3
]

#include %../../cli.red

bin2str: func [x] [		;@@ ideally should not be needed, but binary mode allows parsing by datatype, which is cool
	case [
		any-block? :x [forall x [change/only x bin2str :x/1] x]
		binary?    :x [to "" x]
		'else         [:x]
	]
]

;@@ TODO: "-" for stdin? not possible until ports though
parse-tool: function [
	{- Process input using Parse commands -}
	input [file!]   "File to parse"
	rule  [string!] "Rule to match against, written in Red PARSE dialect"
	/lines   "Parse input line-by-line (default: as a single string)"
	/enum    "Display line numbers together with the text (implies /lines)"
	; /case    "Use case-sensitive comparison"	;@@ BUG: always applies - #4862
	/collect "Collect matches and print to the console"
	/write   "Write the contents back (incompatible with --collect)"
	/verbose "Verbose output"
	/l "alias /lines"
	/e "alias /enum"
	/c "alias /collect"
	/v "alias /verbose"
	/w "alias /write"
][
	if error? e: try [
		if all [write collect] [do make error! "--collect and --write options are mutually exclusive"]
		rule: load/all rule
		data: read/binary input
		if enum [lines: true]
		if collect [rule: compose/only [collect (rule)]]
		if verbose [print ["File:" to-local-file input]]
		if verbose [print ["Using rule:" mold rule]]
		if lines [
			nl: [opt #"^M" #"^/" marker:]
			lines: parse data [collect [any [keep copy _ to [nl | end] opt nl]]]
			if verbose [print ["Applying rule to" length? lines "lines"]]
			marker: either all [marker marker/-2 = "#^M"] ["^M^/"]["^/"]	;-- determine the type of new-lines used
		]
		result: []
		either lines [
			repeat i length? lines [
				line: lines/:i
				set 'line-number i							;-- expose line-number to rule (e.g. `keep (line-number)`)
				either collect [
					append result parse line rule
				][
					parse line [(ok?: no) rule (ok?: yes)]
					if ok? [
						unless write [
							if enum [prin line-number prin "^-"]
							print to "" line
						]
					]
				]
			]
			if collect [probe new-line/all bin2str result yes]
			if write [										;-- reconstruct the file contents
				new: #{}
				foreach line lines [append append new line marker]
				unless #"^/" = last data [take/last new]
				unless new == data [
					if verbose [print "Contents have changed. Writing back."]
					system/words/write/binary input new
				]
			]
		][
			if write [old: copy data]
			result: parse data [rule (ok?: yes)]
			if collect [probe new-line/all bin2str result yes]
			if all [write  not old == data] [
				if verbose [print "Contents have changed. Writing back."]
				system/words/write/binary input data
			]
			if verbose [print ["Parsing result:" pick ["success" "failure"] ok? = yes]]
			unless ok? [quit/return 1]
		]
		quit/return 0
	][
		print e
		quit/return 999
	]
]

cli/process-into/name/post-scriptum parse-tool "Parse tool"			;-- use uppercased name
{
Parse tool works in 2 modes: LINE mode and FILE mode

1. In FILE mode, it matches full file text against the RULE
   and returns 0 if RULE fully covers the file, or 1 if not.
   (useful to check if file follows a certain structure)

   If COLLECT option is provided, collected tokens (if any)
   are also printed to the console.
   (useful to gather info from the file)

   If WRITE option is provided, and RULE changes the input,
   file contents is also written back to the file.
   (useful to modify the file)

2. In LINE mode, it splits text into lines, then matches RULE against every line.

   If COLLECT option is provided, it prints result collected from ALL lines.
   (useful to gather info from a file that is line-oriented)

   If WRITE option is provided, and RULE changes at least one line,
   file contents is written back to the file and no output is made.
   (useful to modify a file that is line-oriented)

   Otherwise, it prints each line that matches the RULE.
   (useful to filter the lines)

Examples:

   Displaying all lines containing 2 consecutive vowels:
parse -e FILE "(cs: charset {AEIOUaeiou}) to 2 cs"

   List what datatypes a file contains:
for %%i in (integer! float! tuple! string! file!) do (
    parse FILE "to %%i"
    if not errorlevel 1 echo Contains %%i
)	

   Collect all mixed-case words:
parse -c FILE "any [thru [any { } copy w word!] (w: to string! w) opt [if (not any [w == uppercase copy w  w == lowercase copy w]) keep (transcode/one w)]]"

   Extract columns 8-15 from the text
parse -c -l FILE "0 8 skip keep copy _ 0 8 skip"

   Extract all line comments from the script:
parse -c -l parse.red "to {;} keep to end"
}
