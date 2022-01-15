Red [
	title: "Map & construction syntax converter"
	purpose: "Convert old #() into new #[] map syntax and vice versa" 
]

; no idea how can one possibly compile this mess of Red & R/S dependencies:
; #include %/d/devel/red/red-src/red/environment/console/cli/input.red

do [


; TODO: an option not to follow symlinks, somehow?
; TODO: allow time! as /limit ? like, abort if takes too long..
; TODO: asynchronous/concurrent listing (esp. of different physical devices)

; BUG: in Windows some masks have special meaning (8.3 filenames legacy)
;      these special cases are not replicated in `glob`:
;  "*.*" is an equivalent of "*" 
;     use "*" instead or better leave out the /only refinement
;  "*." historically meant any name with no extension, but now also matches filenames ending in a period
;     use `/omit "*.?*"` instead of it
;  "name?" matches "name1", "name2" ... but also "name"
;     use ["name" "name?"] set instead

context [
	set 'glob function [
		"Recursively list all files"
		/from "starting from a given path"
			root [file!] "CWD by default"
		/limit "recursion depth (otherwise limited by the maximum path size)"
			sublevels [integer!] "0 = root directory only"
		/only "include only files matching the mask or block of masks"
			imask [string! block!] "* and ? wildcards are supported"
		/omit "exclude files matching the mask or block of masks"
			xmask [string! block!] "* and ? wildcards are supported"
		/files "list only files, not directories"
	][
		; ^ tip: by binding the func to a context I can use a set of helper funcs
		; without recreating them on each `glob` invocation
		
		prefx: tail root: either from [clean-path dirize to-red-file root][copy %./]
		
		; prep masks for bulk parsing
		if only [imask: compile imask]
		if omit [xmask: compile xmask]
		
		; lessen the number of conditions to check by defaulting sublevels to 1e9
		; with maximum path length about 2**15 it is guaranteed to work
		unless sublevels [sublevels: 1 << 30]
		
		; requested file exclusion conditions:
		; tip: any [] = none, works even if no condition is provided
		excl-conds: compose [
			(either files [ [dir? f] ][ [] ])					;-- it's a dir but only files are requested?
			(either only  [ [not match imask f] ][ [] ])		;-- doesn't match the provided imask?
			(either omit  [ [match xmask f] ][ [] ])			;-- matches the provided xmask?
		]

		r: copy []
		subdirs: append [] %"" 		;-- dirs to list right now
		nextdirs: [] 					;-- will be filled with the next level dirs
		until [
			foreach d subdirs [		;-- list every subdir of this level
				; path structure, in `glob/from /some/path`:
				; /some/path/some/sub-path/files
				; ^=root.....^=prefx
				; `prefx` gets replaced by `d` every time, which is also relative to `root`:
				append clear prefx d
				unless error? fs: try [read root] [		;-- catch I/O (access denied?) errors, ignore silently
					foreach f fs [
						; `f` is only the last path segment
						; but excl-conds should be tested before attaching the prefix to it:
						if dir? f [append nextdirs f]
						unless any excl-conds [append r f]
						; now is able to attach...
						insert f prefx
					]
				]
			]
			; swap the 2 directory sets, also clearing the used one:
			subdirs: also nextdirs  nextdirs: clear subdirs

			any [
				0 > sublevels: sublevels - 1 		;-- exit upon reaching the limit
				0 = length? subdirs					;-- exit when nothing more to list
			]
		]
		clear subdirs		;-- cleanup
		r
	]

	;; --- helper funcs ---

	; test if file matches a mask (any of)
	match: func [mask [block!] file /local end] [
		; shouldn't try to match against the trailing slash:
		{end: skip  tail file  pick [-1 0] dir? file
		forall mask [if parse/part file mask/1 end [return yes]]
		no}
		; (parse/part is buggy, have to modify the file)
		end: either dir? file [take/last file][""]
		; do [...] is for the buggy compiler only
		also do [forall mask [if parse file mask/1 [break/return yes] no]]
			append file end
	]

	; compile single/multiple masks
	compile: func [mask [string! block!]] [
		either string? mask [reduce [compile1 mask]] [
			also mask: copy/deep mask
			forall mask [mask/1: compile1 mask/1]
		]
	]

	; compiles a wildcard-based mask into a parse dialect block
	compile1: func [mask [string!] /local rule] [
		parse mask rule: [ collect [any [
			keep some non-wild
		|	#"?" keep ('skip)
		|	#"*" keep ('thru) [
				; "*" is a backtracking wildcard
				; to support it we have to wrap the whole next expr in a `thru [...]`
				mask: keep (parse mask rule) thru end
			]
		] end keep ('end)] ]
	]
	non-wild: charset [not "*?"]
]







; #do [
; 	included: 1 + either all [value? 'included integer? :included] [included][0]
; 	print ["including assert.red" included "th time"]
; ]

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#do [unless value? 'assertions [assertions: on]]		;-- only reset it on first include

#macro [#assert block!] func [[manual] s e] [			;-- allow macros within assert block!
	either assertions [
		change s 'assert
	][
		remove/part s e
	]
]

context [
	next-newline?: function [b [block!]] [
		b: next b
		forall b [if new-line? b [return b]]
		tail b
	]

	set 'assert function [
		"Evaluate a set of test expressions, showing a backtrace if any of them fail"
		tests [block!] "Delimited by new-line, optionally followed by an error message"
		/local result
	][
		copied: copy/deep tests							;-- save unmodified code ;@@ this is buggy for maps: #2167
		while [not tail? tests] [
			set/any 'result do/next bgn: tests 'tests
			if all [
				:result
				any [new-line? tests  tail? tests]
			] [continue]								;-- total success, skip to the next test

			end: next-newline? bgn
			if 0 <> left: offset? tests end [			;-- check assertion alignment
				if any [
					left < 0							;-- code ends after newline
					left > 1							;-- more than one free token before the newline
					not string? :tests/1				;-- not a message between code and newline
				][
					do make error! form reduce [
						"Assertion is not new-line-aligned at:"
						mold/part at copied index? bgn 100		;-- mold the original code
					]
				]
				tests: end								;-- skip the message
			]

			unless :result [							;-- test fails, need to repeat it step by step
				msg: either left = 1 [first end: back end][""]
				prin ["ASSERTION FAILED!" msg "^/"]
				expect copy/part at copied index? bgn at copied index? end		;-- expects single expression, or will report no error
				;-- no error thrown, to run other assertions
			]
		]
		()												;-- no return value
	]
]

;@@ `expect` includes trace-deep which has assertions, so must be included after defining 'assert'
;@@ watch out that `expect` itself does not include code that includes `assert`, or it'll crash






context [
	eval-types: make typeset! reduce [		;-- value types that should be traced
		paren!		;-- recurse into it

		; block!	-- never known if it's data or code argument - can't recurse into it
		; set-word!	-- ignore it, as it's previous value is not used
		; set-path!	-- ditto

		word!		;-- function call or value acquisition - we wanna know the value
		path!		;-- ditto

		get-word!	;-- value acquisition - wanna know it
		get-path!	;-- ditto

		native!		;-- literal functions should be evaluated but no need to display their source; only result
		action!		;-- ditto
		routine!	;-- ditto
		op!			;-- ditto
		function!	;-- ditto
	]

	;; this is used to prevent double evaluation of arguments and their results
	;@@ TODO: remove this once we have `apply` native
	wrap: func [x [any-type!]] [
		if any [										;-- quote non-final values (that do not evaluate to themselves)
			any-word? :x
			any-path? :x
			any-function? :x
			paren? :x
		][
			return as paren! reduce ['quote :x]
		]
		:x												;-- other values return as is
	]

	;; reduces each expression in a chain
	rewrite: func [code inspect preview] [
		code: copy code									;-- will be modified in place; but /deep isn't applicable as we want side effects
		while [not empty? code] [code: rewrite-next code :inspect :preview]
		head code										;-- needed by `trace-deep`
	]
	
	;; fully reduces a single value, triggering a callback
	rewrite-atom: function [code inspect preview] [
		if find eval-types type: type? :code/1 [
			to-eval:   copy/part      code 1			;-- have to separate it from the rest, to stop ops from being evaluated
			to-report: copy/deep/part code 1			;-- report an unchanged (by evaluation) expr to `inspect` (here: can be a paren with blocks inside)
			change/only code
				either type == paren! [
					as paren! rewrite as block! code/1 :inspect :preview
				][
					preview to-report
					wrap inspect to-report do to-eval
				]
		]
	]

	;; rewrites an operator application, e.g. `1 + f x`
	;; makes a deep copy of each code part in case a value gets modified by the code
	rewrite-op-chain: function [code inspect preview] [
		until [
			rewrite-next/no-op skip code 2 :inspect :preview	;-- reduce the right value to a final, but not any subsequent ops
			to-eval:   copy/part      code 3			;-- have to separate it from the rest, to stop ops from being evaluated
			to-report: copy/deep/part code 3			;-- report an unchanged (by evaluation) expr to `inspect`
			preview to-report
			change/part/only code wrap inspect to-report do to-eval 3
			not all [									;-- repeat until the whole chain is reduced
				word? :code/2
				op! = type? get/any :code/2
			]
		]
	]

	;; deeply reduces a single expression, recursing into subexpressions
	rewrite-next: function [code inspect preview /no-op /local end' r] [
		;; determine expression bounds & skip set-words/set-paths - not interested in them
		start: code
		while [any [set-path? :start/1 set-word? :start/1]] [start: next start]		;@@ optimally this needs `find` to support typesets
		if empty? start [do make error! rejoin ["Unfinished expression: " mold/flat skip start -10]]
		end: preprocessor/fetch-next start
		no-op: all [no-op  start =? code]				;-- reset no-op flag if we encounter set-words/set-paths, as those ops form a new chain

		set/any [v1: v2:] start							;-- analyze first 2 values
		rewrite?: yes									;-- `yes` to rewrite the current expression and call a callback
		case [											;-- priority order: op (v2), any-func (v1), everything else (v1)
			all [											;-- operator - recurse into it's right part
				word? :v2
				op! = type? get/any v2
			][
				rewrite-atom start :inspect :preview		;-- rewrite the left part
				if no-op [return next start]				;-- don't go past the op if we aren't allowed
				rewrite-op-chain start :inspect :preview	;-- rewrite the whole chain of operators
				rewrite?: no								;-- final value; but still may need to reduce set-words/set-ops
			]

			all [										;-- a function call - recurse into it
				any [
					word? :v1
					all [									;-- get the path in objects/blocks.. without refinements
						path? :v1
						also set/any [v1: _:] preprocessor/value-path? v1
							if single? v1 [v1: :v1/1]		;-- turn single path into word
					]
				]
				find [native! action! function! routine!] type?/word get/any v1
			][
				arity: either path? v2: get v1 [
					preprocessor/func-arity?/with spec-of :v2 v1
				][	preprocessor/func-arity?      spec-of :v2
				]
				end: next start
				loop arity [end: rewrite-next end :inspect :preview]	;-- rewrite all arguments before the call, end points past the last arg
			]

			paren? :v1 [								;-- recurse into paren; after that still `do` it as a whole
				change/only start as paren! rewrite as block! v1 :inspect :preview
			]

			'else [										;-- other cases
				rewrite-atom start :inspect :preview
				rewrite?: no								;-- final value
			]
		]

		if any [
			rewrite?									;-- a function call or a paren to reduce
			not start =? code							;-- or there are set-words/set-paths, so we have to actually set them
		][
			preview copy/deep/part code end
			set/any 'r either rewrite? [
				to-report: copy/deep/part code end
				inspect to-report do/next code 'end'
			][
				do/next code 'end'
			]
			;; should not matter - do (copy start end) or do/next, if preprocessor is correct
			unless end =? end' [
				do make error! rejoin [
					"Miscalculated expression bounds detected at "
					mold/flat copy/part code end
				]
			]
			change/part/only code wrap :r end
		]
		return next code
	]

	set 'trace-deep function [
		"Deeply trace a set of expressions"				;@@ TODO: remove `quote` once apply is available
		inspect	[function!] "func [expr [block!] result [any-type!]]"
		code	[block!]	"If empty, still evaluated once"
		/preview
			pfunc [function! none!] "func [expr [block!]] - called before evaluation"
	][
		do rewrite code :inspect :pfunc					;-- `do` will process `quote`s and return the last result
	]
]

; inspect: func [e [block!] r [any-type!]] [print [pad mold/part/flat/only e 20 20 " => " mold/part/flat :r 40] :r]

; #include %assert.red			;@@ assert uses this file; cyclic inclusion = crash

; 	() = trace-deep :inspect []
; #assert [() = trace-deep :inspect [()]]
; #assert [() = trace-deep :inspect [1 ()]]
; #assert [3  = trace-deep :inspect [1 + 2]]
; #assert [9  = trace-deep :inspect [1 + 2 * 3]]
; #assert [4  = trace-deep :inspect [x: y: 2 x + y]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] g: f 1 g * 2]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] (g: f (1)) ((g) * 2)]]


#localize []

expect: function [
	"Test a condition, showing full backtrace when it fails; return true/false"
	expr [block!] "Falsey results: false, none and unset!"
	/buffer buf [string!] "Print into the provided buffer rather than the console"
	/local r
][
	orig: copy/deep expr								;-- preserve the original code in case it changes during execution
	red-log: make block! 20								;-- accumulate the reduction log here
	err: try/all [										;-- try/all as we don't want any returns/breaks inside `expect`
		set/any 'r trace-deep
			func [expr [block!] rslt [any-type!]] [
				repend red-log [expr :rslt]
				:rslt
			]
			expr
		'ok
	]

	if all [value? 'r  :r] [							;-- `value?` if not unset, `:r` if not false/none (or error=none)
		return yes
	]

	;; now that we have a failure, let's report
	buf: any [buf make string! 200]
	append buf form reduce [
		"ERROR:" mold/flat/part expr 100
		either error? err [
			reduce ["errored out with^/" err]
		][	reduce ["check failed with" mold/flat/part :r 100]
		]
		"^/  Reduction log:^/"
	]
	foreach [expr rslt] red-log [
		append buf form reduce [
			"   " pad mold/part/flat/only expr 30 30
			"=>" mold/part/flat :rslt 50 "^/"
		]
	]
	unless buffer [prin buf]
	no
]


; #include %localize-macro.red
; #localize [#assert [
; 	a: 123
; 	not none? find/only [1 [1] 1] [1]
; 	1 = 1
; 	100
; 	1 = 2
; 	; 3 = 2 4
; 	2 = (2 + 1) "Message"
; 	3 + 0 = 3

; 	2							;-- valid multiline assertion
; 	-
; 	1
; 	=
; 	1
; ]]







#macro [#localize block!] func [[manual] s e] [			;-- allow macros within local block!
	remove/part insert s compose/deep/only [do reduce [function [] (s/2)]] 2
	s													;-- reprocess
]





with: func [
	"Bind CODE to a given context CTX"
	ctx [any-object! function! any-word! block!]
		"Block [x: ...] is converted into a context, [x 'x ...] is used as a list of contexts"
	code [block!]
][
	case [
		not block? :ctx  [bind code :ctx]
		set-word? :ctx/1 [bind code context ctx]
		'otherwise       [foreach ctx ctx [bind code do :ctx]  code]		;-- `do` decays lit-words and evals words, but doesn't allow expressions
		; 'otherwise       [while [not tail? ctx] [bind code do/next ctx 'ctx]  code]		;-- allows expressions
		; 'otherwise       [foreach ctx reduce ctx [bind code :ctx]  code]	;-- `reduce` is an extra allocation
	]
]

#localize []
			;-- used by composite func to bind exprs




context [
	with-thrown: func [code [block!] /thrown] [			;-- needed to be able to get thrown from both *catch funcs
		do code
	]

	;-- this design allows to avoid runtime binding of filters
	;@@ should it be just :thrown or attempt [:thrown] (to avoid context not available error, but slower)?
	set 'thrown func ["Value of the last THROW from FCATCH or PCATCH"] bind [:thrown] :with-thrown

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			;-- the rest mimicks `case append cases [true [throw thrown]]` behavior but without allocations
			forall cases [if do/next cases 'cases [break]]	;-- will reset cases to head if no conditions succeed
			if head? cases [throw :thrown]					;-- outside of `catch` for `throw thrown` to work
			do cases/1										;-- evaluates the block after true condition
		]
	] :with-thrown
	;-- bind above binds `thrown` and `code` but latter is rebound on func construction
	;-- as a bonus, `thrown` points to a value, not to a function, so a bit faster

	set 'fcatch function [
		"Eval CODE and catch a throw from it when FILTER returns a truthy value"
		filter [block!] "Filter block with word THROWN set to the thrown value"
		code   [block!] "Code to evaluate"
		/handler        "Specify a handler to be called on successful catch"
			on-throw [block!] "Has word THROWN set to the thrown value"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			unless do filter [throw :thrown]
			either handler [do on-throw][:thrown]
		]
	] :with-thrown

	set 'trap function [					;-- backward-compatible with native try, but traps return & exit, so can't override
		"Try to DO a block and return its value or an error"
		code [block!]
		/all   "Catch also BREAK, CONTINUE, RETURN, EXIT and THROW exceptions"
		/catch "If provided, called upon exceptiontion and handler's value is returned"
			handler [block! function!] "func [error][] or block that uses THROWN"
			;@@ maybe also none! to mark a default handler that just prints the error?
		/local result
	] bind [
		with-thrown [
			plan: [set/any 'result do code  'ok]
			set 'thrown either all [					;-- returns 'ok or error object ;@@ use `apply`
				try/all plan
			][	try     plan
			]
			case [
				thrown == 'ok   [:result]
				block? :handler [do handler]
				'else           [handler thrown]		;-- if no handler is provided - this returns the error
			]
		]
	] :with-thrown

]


attempt: func [
	"Tries to evaluate a block and returns result or NONE on error"
	code [block!]
	/safer "Capture all possible errors and exceptions"
][
	either safer [
		trap/all/catch code [none]
	][
		try [return do code] none						;-- faster than trap
	]
]




{
	;-- this version is simpler but requires explicit `true [throw thrown]` to rethrow values that fail all case tests
	;-- and that I consider a bad thing

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			case cases									;-- case is outside of catch for `throw thrown` to work
		]
	] :with-thrown
}
		;-- used by composite func to trap errors


context [
	non-paren: charset [not #"("]

	trap-error: function [on-err [function! string!] :code [paren!]] [
		trap/catch
			as [] code
			pick [ [on-err thrown] [on-err] ] function? :on-err
	]

	set 'composite function [
		"Return STR with parenthesized expressions evaluated and formed"
		ctx [block!] "Bind expressions to CTX - in any format accepted by WITH function"
		str [any-string!] "String to interpolate"
		/trap "Trap evaluation errors and insert text instead"	;-- not load errors!
			on-err [function! string!] "string or function [error [error!]]"
	][
		s: as string! str
		b: with ctx parse s [collect [
			keep ("")									;-- ensures the output of rejoin is string, not block
			any [
				keep copy some non-paren				;-- text part
			|	keep [#"(" ahead #"\"] skip				;-- escaped opening paren
			|	s: (set [v: e:] transcode/next s) :e	;-- paren expression
				keep (:v)
			]
		]]

		if trap [										;-- each result has to be evaluated separately
			forall b [
				if paren? b/1 [b: insert b [trap-error :on-err]]
			]
			;@@ use map-each when it becomes native
			; b: map-each/eval [p [paren!]] b [['trap-error quote :on-err p]]
		]
		as str rejoin b
		; as str rejoin expand-directives b		-- expansion disabled by design for performance reasons
	]
]


;; has to be both Red & R2-compatible
;; any-string! for composing files, urls, tags
;; load errors are reported at expand time by design
#macro [#composite any-string! | '` any-string! '`] func [[manual] ss ee /local r e s type load-expr wrap keep] [
	set/any 'error try [								;-- display errors rather than cryptic "error in macro!"
		s: ss/2
		r: copy []
		type: type? s
		s: to string! s									;-- use "string": load %file/url:// does something else entirely, <tags> get appended with <>

		;; loads "(expression)..and leaves the rest untouched"
		load-expr: has [rest val] [						;-- s should be at "("
			rest: s
			either rebol
				[ set [val rest] load/next rest ]
				[ val: load/next rest 'rest ]
			e: rest										;-- update the end-position
			val
		]

		;; removes unnecesary parens in obvious cases (to win some runtime performance)
		;; 2 or more tokens should remain parenthesized, so that only the last value is rejoin-ed
		;; forbidden _loadable_ types should also remain parenthesized:
		;;   - word/path (can be a function)
		;;   - set-word/set-path (would eat strings otherwise)
		;@@ TODO: to be extended once we're able to load functions/natives/actions/ops/unsets
		wrap: func [blk] [					
			all [								
				1 = length? blk
				not find [word! path! set-word! set-path!] type?/word first blk
				return first blk
			]
			to paren! blk
		]

		;; filter out empty strings for less runtime load (except for the 1st string - it determines result type)
		keep: func [x][
			if any [
				empty? r
				not any-string? x
				not empty? x
			][
				if empty? r [x: to type x]				;-- make rejoin's result of the same type as the template
				append/only r x
			]
		]

		marker: to char! 40								;@@ = #"(": workaround for #4534
		do compose [
			(pick [parse/all parse] object? rebol) s [
				any [
					s: to marker e: (keep copy/part s e)
					[
						"(\" (append last r marker)
					|	s: (keep wrap load-expr) :e
					]
				]
				s: to end (keep copy s)
			]
		]
		;; change/part is different between red & R2, so: remove+insert
		remove/part ss ee
		insert ss reduce ['rejoin r]
		return next ss									;-- expand block further but not rejoin
	]
	print ["***** ERROR in #COMPOSITE *****^/" :error]
	ee													;-- don't expand failed macro anymore - or will deadlock
]







;-- -- -- -- -- -- -- -- -- -- -- -- -- -- TESTS -- -- -- -- -- -- -- -- -- -- -- -- -- --








; #assert [			;-- this is unloadable because of tag limitations
; 	[#composite <tag flag="(form 1 + 2)">] == [
; 		rejoin [
; 			<tag flag=">	;-- result is a <tag>
; 			(form 3)
; 			{"}				;-- other strings should be normal strings, or we'll have <<">> result
; 		]
; 	]
; ]














									;-- doesn't make sense to include this file without #composite also

;; I'm intentionally not naming it `#error` or the macro may be silently ignored if it's not expanded
;; (due to many issues with the preprocessor)
#macro [
	p: 'ERROR
	(either "ERROR" == mold p/1 [p: []][p: [end skip]]) p		;@@ this idiocy is to make R2 accept only uppercase ERROR
	skip
] func [[manual] ss ee] [
	unless string? ss/2 [
		print form make error! form reduce [
			"ERROR macro expects a string! argument, not" mold copy/part ss/2 50
		]
	]
	remove ss
	insert ss [do make error! #composite]
	ss		;-- reprocess it again so it expands #composite
]



;@@ TODO: automatically set refinement to true if any of it's arguments are provided?
apply: function [
	"Call a function NAME with a set of arguments ARGS"
	;@@ support path here or `(in obj 'name)` will be enough?
	;@@ operators should be supported too
	'name [word! function! action! native!] "Function name or literal"
	args [block! function! object! word!] "Block of [arg: expr ..], or a context to get values from"
	/verb "Do not evaluate expressions in the ARGS block, use them verbatim"
	/local value
][
	if word? :args [args: context? args]
	if all [not verb  block? :args] [					;-- evaluate expressions
		buf: clear copy args
		pos: args
	 	while [not tail? bgn: pos] [
	 		unless set-word? :pos/1 [ERROR "Expected set-word at (mold/part args 30)"]
	 		while [set-word? first pos: next pos][]		;-- skip 1 or more set-words
	 		set/any 'value do/next end: pos 'pos
	 		repeat i offset? bgn end [repend buf [bgn/:i :value]]
	 	]
	 	args: buf
	 	; ? args
	]
	
	;@@ TODO: hopefully in args=block case we'll be able to make it O(n)
	;@@ by having O(1) lookups of all set-words into some argument array specific to each particular function
	;@@ this implementation for now just uses `find` within args block, which makes it O(n^2)
	
	;@@ won't be needed in R/S
	call: reduce [path: as path! reduce [:name]]		;@@ in Red - impossible to add refinements to function literal
	
	either word? :name [
		set/any 'fun get/any name
		unless any-function? :fun [ERROR "NAME argument (name) does not refer to a function"]
	][
		fun: :name
		name: none
	]

	get-value: [
		either block? :args [
			select/skip args to set-word! word 2
		][
			w1: to word! word
			all [
				not w1 =? w2: bind w1 :args				;-- if we don't check it, binds to global ctx
				get/any w2
			]
		]
	]

	use-words?: yes
	foreach word spec-of :fun [
		;@@ the below part will be totally different in R/S,
		;@@ hopefully just setting values at corresponding offsets
		type: type? word
		case [
			type = refinement! [
				if set/any 'use-words? do get-value [append path to word! word]
			]
			not use-words? []							;-- refinement is not set, ignore words
			type = word!     [repend call ['quote do get-value]]
			;@@ extra work that won't be needed in R/S:
			type = lit-word! [append call as paren! reduce [do get-value]]
			type = get-word! [repend call [do get-value]]
			;@@ type checking - where? should interpreter do it for us?
		]
	]
	; print ["Constructed call:" mold call]
	do call
]

#localize []

; value: "d"
; probe apply find [series: "abcdef" value: value only: case: yes]

; probe apply find object [series: "abcde" value: "d" only: case: yes]

; my-find: function spec-of :find [
; 	case: yes
; 	only: no
; 	apply find 'only
; ]
; probe my-find/only "abcd" "c"


count: function [
	"Count occurrences of VALUE in SERIES (using `=` by default)"
	series [series!]
	value  [any-type!]
	/case "Use strict comparison (`==`)"
	/same "Use sameness comparison (`=?`)"
	/only "Treat series and typesets as single values"
	/head "Count the number of subsequent values at series' head"
	/tail "Count the number of subsequent values at series' tail"	;@@ doesn't work for strings! #3339
][
    match: head or tail
    unless tail: not reverse: tail [series: system/words/tail series]
	n: 0 while [series: apply find 'local] [n: n + 1]
    n
]

{
	Toomas's version without apply: (and /case /same)

count: func [series item /only /head /tail /local cnt pos with-only without][
    cnt: 0
    set [       with-only                             without                  ] case [
        tail [[[find/reverse/match/only series item] [find/reverse/match series item]]]
        head [[[find/match/tail/only    series item] [find/match/tail    series item]]]
        true [[[find/tail/only          series item] [find/tail          series item]]]
    ]
    if tail [series: system/words/tail series]
    while [all [pos: either only with-only without series: pos]] [cnt: cnt + 1]
    cnt
]	
}

; probe count/head "aaabbc" "a"
; probe count/head "aaabbc" "aa"
; probe count/head "aaabbc" "aaa"
; probe count/tail [1 2 2 3 3 3] 3

comment {
	;; limited and ugly but fast version
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
	    n: 0
	    system/words/case [
	        same [while [s: find/tail/same s :x][n: n + 1]]
	        case [while [s: find/tail/case s :x][n: n + 1]]
	        true [while [s: find/tail      s :x][n: n + 1]]
	    ]
	    n 
    ] 

	;; `compose` involves too much memory pressure
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		cmp: pick pick [[find/tail/same find/tail/same] [find/tail/case find/tail]] same case
		r: 0
		while compose [s: (cmp) s :x] [r: r + 1]
		r
	]

	;; slow version
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		cmp: pick pick [[=? =?] [== =]] same case
		r: 0
		foreach y s compose [if :x (cmp) :y [r: r + 1]]
		r
	]

	;; parse-version - not better; can't support `same?` without extra checks
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		r: 0
		parse s [any thru [x (r: r + 1)]]
		r
	]

	;; test code
	#include %clock-each.red
	recycle/off
	clock-each/times [
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] 1
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] 1
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] "c"
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] "c"
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] number!
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] number!
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] integer!
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] integer!
	] 50000

}
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