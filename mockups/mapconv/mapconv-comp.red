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



;; ████████████  DEBUGGING FACILITIES  ████████████

#local [												;-- don't override global assert

#macro [#debug 'on]  func [s e] [debug: on  []]
#macro [#debug 'off] func [s e] [debug: off []]
#macro [#debug block!] func [[manual] s e] [remove s either debug [remove insert s s/1][remove s] s]
#debug off

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]


#macro [#assert block!] func [s e] [
	either assertions [ reduce ['assert s/2] ][ [] ]
]


;-- comment these out to disable self-testing

; #debug on
; #assert on

do expand-directives [									;-- boring workaround for #4128
cli: context [

	assertions-run: 0
	assert: function [contract [block!]][
		set [cond msg] reduce contract
		set 'assertions-run assertions-run + 1
		unless cond [
			print ["ASSERTION FAILURE:" mold contract]
			if none? msg [msg: last contract]
			if any-word? msg [
				msg: either function? get msg
				[ rejoin ["" msg " result is unexpected"] ]
				[ rejoin ["" msg " is " mold/part/flat get msg 1024] ]
			]
			do make error! form msg
		]
	]

	comment {
		References:
		[1] "Program Argument Syntax Conventions"
			https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html
		[2] "POSIX Utility Syntax Guidelines"
			https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html#tag_12_02
		[3] "Portable character set"
			https://en.wikipedia.org/wiki/Portable_character_set
		[4] "Learning the Bash. Special Characters and Quoting"
			https://www.oreilly.com/library/view/learning-the-bash/1565923472/ch01s09.html
	}

	;-- ERROR CODES refer to themselves, in case one wants to print them
	ER_FEW:    'ER_FEW			;-- not enough operands
	ER_MUCH:   'ER_MUCH			;-- too many operands
	ER_LOAD:   'ER_LOAD			;-- provided value is invalid
	ER_TYPE:   'ER_TYPE			;-- provided valus is of wrong type
	ER_EMPTY:  'ER_EMPTY		;-- no value provided
	ER_VAL:    'ER_VAL			;-- value provided where no value expected
	ER_CMD:    'ER_CMD			;-- unknown command (during dispatching)
	ER_OPT:    'ER_OPT			;-- unknown option
	ER_FORMAT: 'ER_FORMAT		;-- unknown option format
	ER_CHAR:   'ER_CHAR			;-- unsupported char in option name

	;-- supported argument FORMAT TYPES
	loadable-set: make typeset! [integer! float! percent! logic! url! email! tag! issue! time! date! pair!]
	supported-set: union loadable-set make typeset! [string! file! block!]


	;-- used to signal an error in supplied command line
	complain: func [about [block!]] [
		;@@ TODO: print to stderr instead (not supported by Red yet)
		
		throw/name reduce about 'complaint
	]

	else: make op! func [truth e [string!]] [unless truth [do make error! e]]


	option?: func [
		"Check if ARG is an option name"
		arg			[string!]
		/options				"(placeholder for future expansion)"
			opts	[block! map! none!]
	][
		all [
			#"-" = first arg	;-- [1] Arguments are options if they begin with a hyphen delimiter (‘-’)
			arg <> "-"			;-- [1] A token consisting of a single hyphen character is interpreted as an ordinary non-option argument
			arg <> "--"			;-- [1] The argument ‘--’ terminates all options
		]
	]
	

	;; ████████████  SPEC ANALYSIS  ████████████

	str-to-ref: func [
		{Convert "string" into /refinement}
		s [string!]
	][
		if any [
			error? try [s: load s]						;-- unloadable?
			not word? :s								;-- unsupported spelling?
			; all [not integer? s not word? s]			;@@ TODO: integer options?
		][
			complain [ER_OPT "Unsupported option:" :s]	;-- using get-word for security (one day `load` may support serialized funcs)
		]
		; if integer? s [s: to word! rejoin ["_" s]]
		
		to refinement! s
	]

	

	find-refinement: function [
		"Return internal SPEC at block containing /ref, or none if not found"
		spec [block!]
		ref [refinement!]
	][
		until [
			names: first spec
			if all [block? names  find names ref][return spec]
			empty? spec: skip spec 3
		]
		none
	]


	default: func [:w [set-word!] v] [any [get/any :w  set :w v]]

	prep-spec: function [
		"Converts a function SPEC into internal format used for easier argument processing"
		;-- internal spec format is a block of triplets:
		;; [      name-word          "docstring"  typeset! ]  for operands and option arguments
		;; [ [ /option /alias ... ]  "docstring"  none     ]  for --options themselves
		spec [block! function!]
		/local name target
	][
		if function? :spec [spec: spec-of :spec]
		=arg=: [									;-- operand / argument (word)
			set name      word!
			set types opt block!  (default types: [string!])
			set doc   opt string! (default doc: copy "")
			(
				(not force-nullary?) else {alias refinements cannot have arguments}
				if types = [block!] [append types 'string!]
				repend r [name  doc  make typeset! types]
			)
		]
		=local=: [/local to [refinement! | end]]	;-- skip /locals (/externs are never present in the spec)
		=ref=: [									;-- option (refinement)
			set name    refinement!
			set doc opt string!     (default doc: copy "")
			(										;-- check the docstring for an alias definition
				either force-nullary?: target: find/match/tail doc "alias "	;-- alias? allow no arguments to it
					[ repend aliases [name target] ]
					[ repend r [to block! name  doc  none] ]
			)
		]
		=fail=: [end | p: (do make error! rejoin ["Unsupported token " mold p/1 " in CLI function spec"])]
		force-nullary?: no  aliases: copy []  r: copy []
		parse spec [any string! any [=arg= | =local= | =ref= | =fail=]]
		r: new-line/skip r yes 3
		foreach [alias target] aliases [
			(all [
				attempt [target: load target]
				find [word! refinement!] type?/word :target		;-- using get-word for security (one day `load` may support serialized funcs)
			]) else form rejoin ["Target "target" must be a word or refinement"]
			pos: find-refinement r to refinement! target
			pos else form rejoin ["Target "target" of alias "alias" is not defined"]
			append pos/1 alias
		]
		r
	]

	
	
	
	
	
	
	
	


	supported?: function [
		"Check if option R is supported by F"
		f [function!] r [string!]
	][
		not none? find-refinement prep-spec :f str-to-ref r
	]

	
	
	
	
	


	unary?: function [
		"Check if option R is unary in F's spec"
		f [function!] r [string!]
	][
		r: str-to-ref r
		spec: find-refinement prep-spec :f r
		all [
			word? pick spec 4
			not word? pick spec 7
		]
	]

	
	
	

	
	check-value: function [
		"Typecheck value V against a set of TYPES"
		v			[string!]
		types		[typeset! block!]
		/options				"(placeholder for future expansion)"
			opts	[block! map! none!]
	][
		if block? types [types: make typeset! types]
		

		unsupp: to block! exclude types supported-set
		(empty? unsupp) else form reduce ["Unsupported types in" types "typeset:" unsupp]
		
		loadable: intersect types loadable-set
		case/all [
			loadable <> make typeset! [] [				;-- contains a loadable type?
				set/any 'x try [load v]
			]
			all [										;-- try type conversion
				not error? :x								;-- loaded at all?
				not block? :x								;-- single value?
				any [
					find loadable type? :x					;-- accepted?
					any [									;-- automatic promotion when required
						all [									;-- integer to float
							integer? :x
							find loadable float!
							x: 1.0 * x
						]
						all [									;-- word to logic
							word? :x
							find loadable logic!
							logic? x: get x
						]
					]
				]
			][return x]

			find types file! [return to-red-file v]		;-- try fallbacks: file or string is accepted?
			find types string! [return v]

			error? :x [									;-- load has failed and fallbacks are not applicable
				complain [ER_LOAD "Invalid value format:" v]
			]
		]
														;-- loaded but didn't pass the type check...
		types: to block! exclude types make typeset! [block!]
		a-an: either find "aeiou" first form types/1 ["an"] ["a"]	;-- `a-an` undefined outside of console
		complain compose [								;-- tell which types are accepted
			ER_TYPE
			v "should be" (pick [
				[ a-an types/1 "value"]
				["one of these types:" mold types]
			] last? types)
		]
	]

	
	
	
	
	
	
	
	
	
	



	;; ████████████  /OPTIONS BLOCK SUPPORT  ████████████

	;-- NOTE: refinements and their argument names should be consistent across all CLI funcs to work properly
	;--       otherwise one option will do different things in different funcs that use `sync-arguments`


	arguments-from-block: function [
		"Turn a block (e.g. [args: args]) into an arguments map (e.g. #(arg-blk: [args block]))"
		block [block!] "Non-setwords get reduced and refinements mapped to their respective arguments"
		spec  [block!]
	][
		map: make map! block
		foreach [k v] map [
			if all [
				refinement? first pos: find spec k		;-- if value is assigned to a refinement
				pos: find next pos all-word!			;-- reassign it to it's argument instead
				any-word? first pos
			][
				map/:k: true
				k: to word! pos/1
			]
			map/:k: either any-word? :v [get :v][:v]	;-- reduce words
		]
		map
	]

	sync-arguments: function [
		"Populate OPTS with arguments provided to the function, then back"
		'opts [word!] "A map, block or none"
	][
		spec: spec-of fun: context? opts
		case [
			none? map: get opts [map: copy #()]
			block? map [map: arguments-from-block map spec]	;-- block interpretation is smarter for convenience
		]
		
		set opts map
		parse/case spec [any [
			/local to end
		|	not all-word! skip
		|	set ref opt refinement! set name opt any-word! (
				if name [			;-- get name from arguments, then from map, otherwise set to none
					name: bind to word! name :fun
					set/any 'map/:name
						set/any name
							any [get/any name  :map/:name]
				]
				if ref [			;-- same here but also set to 'true' if name is provided
					ref: bind to word! ref  :fun
					set 'map/:ref
						set ref
							to logic! any [get/any ref  :map/:ref  all [name get/any name]]
				]
			)
		]]
		map
	]

	;; ████████████  INTERNAL CALL BUILDUP  ████████████

	comment {
		Internal call format is used so:
		- we can distinguish between parts of function path and already added refinements
		- we are able to locate every refinement's block of arguments, to add to it

		Format is:
		[
			object/func								-- word or path to function
			[mandatory args ...]					-- block of found operands values, should not contain blocks
			[/ref1 /ref2 [] /ref3 [args] /ref4...]	-- block with so far found options and their arguments
		]
	}

	add-refinements: function [
		"Append to internal CALL block option NAME=VALUE as refinement with all it's aliases"
		call [block!]
		prog [function!]
		name [string!]
		value [string! none!]	;-- none allowed if argument is nullary
		/options				"(placeholder for future expansion)"
			opts	[block! map! none!]
	][
		ref: str-to-ref name
		spec: find-refinement prep-spec :prog ref
		refs: first spec
		
		
		either pos: find/tail call/3 ref [				;-- are refinements already added?
			pos: find pos block!							;-- jump to values
		][												;-- otherwise
			append call/3 refs								;-- list all aliases
			pos: tail call/3
			append/only call/3 copy []						;-- create a block to hold values
		]
			;-- match provided arity with expected one

		if unary? :prog name [							;-- check & add the value
			types: pick spec 6								;-- 3rd is none, 6th is argument's typeset
			value: check-value/options value types opts
			append pos/1 value
		]
		call
	]

	
	
	
	
	


	add-operand: function [
		"Append an operand's VALUE to the internal CALL block"
		call		[block!]
		prog		[function!]
		value		[string!]
		/options				"(placeholder for future expansion)"
			opts	[block! map! none!]
	][
		arity: preprocessor/func-arity? spec-of :prog
		n-args: min arity length? call/2
		spec: skip prep-spec :prog (n-args * 3)
														;-- find the accepted types
		if not word? first spec [						;-- past the arguments already
			if head? spec [									;-- no operands expected at all?
				complain [ER_MUCH "Extra operands given"]	;-- then there's no type to check against
			]
			spec: skip spec -3								;-- use the last argument's typeset
		]
		
		
		value: check-value/options value third spec opts
		append call/2 value
		call
	]

	
	
	


	prep-call: function [
		"Convert internal CALL block into a PROGRAM Red function call"
		call		[block!]
		program		[function!]
		/options				"(placeholder for future expansion)"
			opts	[block! map! none!]
		/local ref
	][
		spec: prep-spec :program
		r: reduce [call/1]
														;-- add mandatory arguments
		foreach arg call/2 [
			either word? spec/1 [							;-- pass single argument normally
				
				if find spec/3 block! [arg: reduce [arg]]
				append/only r arg
				spec: skip spec 3
			][												;-- collect all other arguments into the last block
				unless block? last r [complain [ER_MUCH "Extra operands given"]]
				
				append last r arg
			]
		]

		if find spec/3 block! [append/only r []]		;-- if block is accepted, provide an empty one in absence of arguments

		arity: preprocessor/func-arity? spec-of :program
		need-more: 1 + arity - length? r
		if need-more > 0 [
			present-options: collect [parse call/3 [	;-- find out if a shortcut option is present
				any [set ref refinement! (keep to word! ref) | skip]	;@@ should be `keep-type` here
			]]
			present-shortcuts: intersect present-options opts/s-cuts
			either empty? present-shortcuts [			;-- no shortcuts: fail
				complain [ER_FEW "Not enough operands given"]
			][											;-- shortcut found: provide defaults
				repeat i need-more [
					spec: find/skip spec word! 3
					type: first reduce to [] spec/3		;@@ how else to get a type from typeset?
					append/only r any [					;-- create an argument out of thin air to finish the call
						attempt [make type 0]			;-- for most types
						attempt [make type ""]			;-- for issues
						attempt [make type []]			;-- for dates
					]
					spec: skip spec 3
				] 
			]
		]

		spec: head spec
		unless empty? call/3 [							;-- add options as refinements
			if word? r/1 [ change/only r make path! reduce [r/1] ]	;-- convert word to path
			types: none
			foreach x call/3 [							;-- call/3 is refinements block
				either refinement? x [					;-- /ref
					append r/1 to word! x					;-- add ref to path
					types: pick find-refinement spec x 6	;-- 3rd is none, 6th is argument's typeset (or none if no argument)
				][										;-- [values...]
					if typeset? types [						;-- none if refinement is nullary
						either find types block! [
							append/only r x					;-- add as block of collected values
						][
							
							append r last x					;-- last value replaces prior ones
						]
						types: none
					]
				]
			]
		]
		r
	]

	
	
	
	
	
	



	;; ████████████  ARGUMENTS PARSER  ████████████


	default-exename: function ["Returns the executable/script name without path"] [
		do [											;@@ DO for compiler
			basename?: func [x] [							;-- filename from path w/o extension
				also x: last split-path to-red-file x
					clear find/last x #"."
			]
			any [
				attempt [basename? system/options/script]	;-- when run as `red script.red`
				attempt [basename? system/options/boot]		;-- when run as a compiled exe (options/script = none)
			]
		]
	]


	extract-args: function [
		"Convert CLI args into a block of [name value] according to PROGRAM's spec (name = none for operands)"
		args		[block!]		"block of arguments to process"
		'program	[word! path!]	"function which spec defines the acceptable set of arguments"
		/no-version					"Suppress automatic creation of --version argument"
		/no-help					"Suppress automatic creation of --help and -h arguments"
		/options					"Specify all the above options as a block"
			opts	[block! map! none!]
		/local arg-name
	][
		;-- [1]: Long options consist of ‘--’ followed by a name made of ALPHANUMERIC characters and DASHES
		;-- [2]: Each option name should be a single ALPHANUMERIC character from the PORTABLE character set
		; =optchar=: charset [#"a" - #"z"  #"A" - #"Z"  #"0" - #"9"  "-"]

		;-- relaxed charset on par with Red words
		=optchar=: charset [
			not
			{/\^^,[](){}"#%$@:;}						;-- non-word chars
			" "											;-- whitespace
			#"^(00)" - #"^(1F)"							;-- C0 control codes
			#"^(80)" - #"^(9F)"							;-- C1 control codes
			"="											;-- option/argument delimiter
			"&`'|?*~!<>"								;-- special chars in shell
		]

		is-help-version?: [								;-- use default -h / --version when allowed
			case [
				find ["h" "help"] arg-name [
					unless no-help [arg-name: "help"]	;-- expand -h into --help
				]
				arg-name = "version" [not no-version]
			]
			;; returns none when doesn't handle the argument
		]

		allow-options?: yes								;-- will be switched off by `--`
		r: make block! 20
		forall args [
			arg: :args/1
			unless string? :arg [arg: form :arg]		;-- should never happen?

			got-operand?: any [not allow-options?  not option?/options arg opts]
			default?: no
			either got-operand? [
				;; "-" and "--" go here, since `option?` is false for them
				either all [arg == "--" allow-options?]	;-- subsequent "--"s are operands
					[ allow-options?: no ]				;-- no options after "--"
					[ repend r [none arg] ]
			][
				;-- possible scenarios:
				;; -opqrs (multiple options, not supported by default)
				;; -ofile (not supported by default)
				;; -o file
				;; -o file1 file2 (multi-arg, not supported by default)
				;; -o[file] (optional argument, not supported by default)
				;; /o:file (not supported by default)
				;; /o file (not supported by default)
				;; /o file1 file2 (multi-arg, not supported by default)
				;; -out=file (not supported by default)
				;; -out file (not supported by default)
				;; -out file1 file2 (multi-arg, not supported by default)
				;; --out=file
				;; --out file
				;; --out file1 file2 (multi-arg, not supported by default)
				parse arg [
					[													;-- long or short option?
						"--" copy arg-name [=optchar= some =optchar=]		;-- require 2+ optchars for long names
						(dlms: ["=" | some [#" " | #"^-"] | end])				;-- "=" is allowed to delimit a long option
					|	"-"
						copy arg-name =optchar=
						(dlms: [      some [#" " | #"^-"] | end])				;-- no "=" allowed
						ahead dlms											;-- forbid multiple chars after a single hyphen
					]
					(unless supported? get/any program arg-name [		;-- check the option name
						any [
							default?: do is-help-version?					;-- try default arguments too
							complain [ER_OPT "Unsupported option:" arg]
						]
					])
					[	if (all [
							not default?								;-- disable unary clause for internal help/version
							unary? get/any program arg-name				;-- read the value (if required)
						])
						[	dlms											;-- require a delimiter
						|	pos: (complain [ER_CHAR "Unsupported option character at" pos])
						]
						[	end (											;-- consume the next argument when needed
								args: next args
								if empty? args [complain [ER_EMPTY arg "needs a value"]]
								arg: :args/1
								unless string? :arg [arg: form :arg]		;-- should never happen?
								arg-value: copy arg
							)
						|	copy arg-value [to end]							;-- consume the rest of the same argument
						]
					|													;-- nullary refinement - should end right here
						[ end | (complain [ER_VAL "Option" arg "does not accept a value"]) ]
						(arg-value: none)
					]

					(repend r [arg-name arg-value])

				|	(complain [ER_FORMAT "Unsupported option format:" arg])
				];; parse arg
			];; else: either not all [allow-options?  option?/options arg opts]
		];; forall args
		r
	];; extract-args: function


	;; ████████████  DEFAULT FORMATTERS  ████████████

	dehyphenize: func [x] [replace/all form x #"-" #" "]

	version-for: function [
		"Returns version text for the PROGRAM"
		'program	[word! path!] "May refer to a function or context"
		/name					"Overrides program name"
			pname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]
		/brief					"Include only the essential info"
		/options				"Specify all the above options as a block"
			opts	[block! map! none!]
	][
		sync-arguments opts

		r: make string! 100

		standalone?: none? system/options/script		;@@ is there a better way to check?

		pname: form any [
			pname										;-- when explicitly provided
			attempt [system/script/title]
			attempt [system/script/header/title]
			attempt [dehyphenize first program]			;-- first item in the path: program/command/...
			dehyphenize program							;-- the word itself
			;-- reminder: do not use exe name as program name (it can be renamed easily by the user)
		]

		ver: form any [
			ver											;-- explicitly provided
			attempt [system/script/header/version]		;-- from the header
			attempt [first query system/options/script]	;-- script modification date if interpreted
			#do keep [now/date]							;-- compilation date otherwise
		]

		desc: all [
			function? get/any program
			s: first spec-of get/any program
			string? s
			trim s
		]

		author:  attempt [system/script/header/author]	;@@ TODO: join multiple authors with comma or ampersand?
		rights:  attempt [trim system/script/header/rights]
		license: attempt [trim system/script/header/license]

		append r form compose [
			(pname) (ver)								;-- "Program 1.2.3"
			(any [desc ()])								;-- "long description ..."
			(either author [rejoin ["by "author]][()])	;-- "by Yours Truly"
			#"^/"
		]
		if rights  [repend r [rights #"^/"]]			;-- "(C) Copyrights..."

		unless brief [									;-- add detailed info
			commit: attempt [mold/part system/build/git/commit 8]
			
			
			repend r [									;-- Red version
				pick ["Built with" "Using"] standalone?
				" Red " system/version
				either commit [ rejoin [" (" commit ")"] ][ "" ]
				" for " system/platform
				#"^/"
			]
			if standalone? [repend r ["Build timestamp: " #do keep [now]]]

			if license [repend r [license #"^/"]]		;-- "License text..."
		]

		r
	]

	decorate-operand: func [name types] [				;-- x -> "<x>" or "[x]"
		mold/flat to either find types block! [block!][tag!] name
	]
			
	synopsis-for: function [
		"Returns short synopsis line for the PROGRAM"
		'program	[word! path!] "Must refer to a function"
		/exename				"Overrides executable name"
			xname	[string!]
		/options				"Specify all the above options as a block"
			opts	[block! map! none!]
	][
		sync-arguments opts
		
		(function? get/any program) else form rejoin [program " must refer to a function"]
		spec: prep-spec get/any program
		
		r: make string! 80
		xname: form default xname: default-exename
		append r xname
		if path? program [append r rejoin [" " as [] next program]]	;-- list currently applied commands
		
		options?: any [not opts/no-help  not opts/no-version  find spec none]
		if options? [append r " [options]"]
		
		foreach [name doc types] spec [					;-- list operands:
			if none? types [break]							;-- stop right after the last operand
			repend r [" " decorate-operand name types]		;-- append every operand as "<name>"
		]
		append r "^/"
	]
	
	syntax-for: function [
		"Returns usage text for the PROGRAM"
		'program	[word! path!] "May refer to a function or context"
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/columns				"Specify widths of columns: indent, short option, long option, argument, description"
			cols	[block!]
		/exename				"Overrides executable name"
			xname	[string!]
		/post-scriptum			"Add custom explanation after the syntax"
			pstext	[string!]
		/options				"Specify all the above options as a block"
			opts	[block! map! none!]
	][
		sync-arguments opts
		
		r: make string! 500

		;; given context, just list possible commands
		if object? get/any program [
			list-commands: func [program [word! path!]] [
				foreach word words-of get program [
					path: append to path! program word
					either object? get/any path [
						list-commands path
					][
						repend r ["  " synopsis-for/options (path) opts]
					]
				]
			]
			append r "^/Supported commands:^/"
			list-commands program
			return append r "^/"
		]
		
		spec: prep-spec get/any program
		unless any [no-version  find-refinement spec /version] [
			repend spec [ [/version] "Display program version and exit" none ]
		]
		unless any [no-help     find-refinement spec /help] [
			repend spec [ [/h /help] "Display this help text and exit"  none ]
		]

		repend r ["^/Syntax: " synopsis-for/options (program) opts "^/"]

		;-- OPERANDS & OPTIONS

		;-- "  -o, --long-option  <argument>    Docstring..."
		;;   0 2   6   10   15   20    26  30  34
		;; default paddings:
		;; options: 2 on the left, 20 total
		;; argument: 1 on the left, 14 total
		;; docstring: 1 on the left
		cols: any [cols [2 4 14 14 44]]
		unless all [
			5 = length? cols
			integer? attempt [sum cols]					;-- block of integers only?
		][ cause-error 'script 'expect-val ['five-integers cols] ]
		if cols/5 <= 0 [cols/5: 1'000'000]

		committed?: yes
		header?: no
		commit: [										;-- commits current s-arg, s-opts, s-doc into `r`, forming a column ;@@ as a block for compiler
			unless header? [append r "Options:^/"  header?: yes]

			pad  append cols1-4: s-opts #" "  sum copy/part cols 3
			pad  repend cols1-4 [s-arg #" "]  sum copy/part cols 4
			s-doc: split s-doc #"^/"					;-- split into lines (if any)
			forall s-doc [
				trim/tail s-doc/1
				while [cols/5 < length? s-doc/1] [		;-- split by column width parts
					s-doc: insert  s-doc  take/part s-doc/1 any [
						; find/part/last/tail s-doc/1 #" " cols/5		;@@ find is buggy - #4204
						attempt [-1 + index? find/last/tail copy/part s-doc/1 cols/5 #" "]
						cols/5
					]
				]
			]
			foreach ln s-doc [							;-- output all lines
				repend r [cols1-4 ln #"^/"]
				replace/all cols1-4 [skip] #" "
			]
			committed?: yes
		]

		foreach [names doc types] spec [
			
			either none? types [						;-- options
				

				unless committed? [do commit]

				short: copy ""  long: copy ""
				foreach name names [					;-- form short & long options strings
					either single? form to word! name 
						[ repend short ["-" name ", "] ]
						[ repend long ["--" name ", "] ]
				]
				if empty? take/last/part long 2 [
					take/last/part short 2				;-- leave comma after short part if long one isn't empty
				]

				s-opts: pad copy "" cols/1
				repend s-opts [pad short cols/2  long]

				s-arg: copy ""
				s-doc: copy doc
				committed?: no
			][											;-- operands or option arguments
				
				either committed? [						;-- an operand?
					if empty? doc [continue]				;-- skip operands without description
					s-opts: copy ""							;-- leave "--flag" column empty
					s-arg: decorate-operand names types		;-- "<name>" or "[name]"
				][										;-- an option then ("--flag" part was filled above)
					s-arg: decorate-operand names none		;-- always as "<name>"
				]
				s-doc: case [							;-- combine `doc` with that of `--option` (if any)
					committed? [copy doc]					;-- "      <arg> Arg description"
					empty? doc [s-doc]						;-- "--opt <arg> Opt description"
					empty? s-doc [copy doc]					;-- "--opt <arg> Arg description"
					'else [ rejoin [s-doc "; " doc] ]		;-- "--opt <arg> Opt description; Arg description"
				]
				do commit
			]
		]
		unless committed? [do commit]
		append r "^/"
		if pstext [append r pstext]
		r
	];; syntax-for: function


	help-for: function [
		"Returns help text (version and syntax) for the PROGRAM"
		'program	[word! path!] "May refer to a function or context"
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/name					"Overrides program name"
			pname	[string!]
		/exename				"Overrides executable name"
			xname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]					;@@ TODO: add float? for 1.0 etc
		/post-scriptum			"Add custom explanation after the syntax"
			pstext	[string!]
		/columns				"Specify widths of columns: indent, short option, long option, argument, description"
			cols	[block!]
		/options				"Specify all the above options as a block"
			opts	[block! map! none!]
	][
		sync-arguments opts
		rejoin [
			version-for/brief/options (program) opts
			syntax-for/options (program) opts
		]
	]


	;; when program does not support --help or --version but they are allowed
	;; this handler is fired instead of the program
	handle-special-arg: function [
		"Default special option handler"
		program [word! path!]
		name [string!] "help or version"
		/options opts [block! map! none!]
	][
		switch name [
			"help"    [print help-for/options    (program) opts]
			"version" [print version-for/options (program) opts]
		]
	]

	;; ████████████  MAIN INTEFACE TO CLI ;)  ████████████


	process-into: function [
		"Calls PROGRAM with arguments read from the command line. Passes through the returned value"
		;; can't support `function!` here cause can't add refinements to a function! literal
		'program	[word! path!] "Name of a function, or of a context with functions to dispatch against"
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/name					"Overrides program name"
			pname	[string!]
		/exename				"Overrides executable name"
			xname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]
		/post-scriptum			"Add custom explanation after the syntax in help output"
			pstext	[string!]
		/args					"Overrides system/options/args"
			arg-blk	[block!]
		/on-error				"Custom error handler: func [error [block!]] [...]"
			handler [function!]
			;-- handler should accept a block: [error-code reduced values that constitute the error message]
			;;  error-codes are words: ER_FEW ER_MUCH ER_LOAD ER_TYPE ER_OPT ER_CHAR ER_EMPTY ER_VAL ER_FORMAT
			;;  value returned by handler on error is passed through by process-into
		/shortcuts				"Options (as words) that allow operands to be absent; default: [help h version]"
			s-cuts	[block!]
		/options				"Specify all the above options as a block"
			opts	[block! map! none!]
		/local opt val r ok?
	][
		err: catch/name [								;-- catch processing errors only
			sync-arguments opts											;-- syncs /options with function arguments
			s-cuts: opts/s-cuts: any [									;-- init default shortcuts
				s-cuts
				compose [(pick [[] [help h]] no-help) (pick [[] [version]] no-version)]
			]
			arg-blk: opts/arg-blk: any [arg-blk system/options/args]	;-- args priority: (1) `args` (2) `options/args` (3) `system/options/args`

			while [object? get/any program] [ 							;-- dispatch objects further
				words: words-of get program
				if all [											;-- unsupported command?
					not empty? arg-blk
					word? word: attempt [load :arg-blk/1]
					find words word
				][
					append program: to path! program word
					arg-blk: next arg-blk
					continue
				]
				if any [
					empty? arg-blk
					all [
						not no-help 
						any [
							find arg-blk "--help"
							find arg-blk "-h"
						]
					]
				][
					print help-for/options (program) opts
					throw/name ok?: yes 'complaint
				]
				if all [not no-version  find arg-blk "--version"] [
					print version-for/options (program) opts
					throw/name ok?: yes 'complaint
				]
				complain [ER_CMD "Unknown command:" form word]
			]
			(function? get/any program) else form rejoin [
				"Word " program " must refer to a function, not " type? get/any program
			]

			call: compose/deep [ (program) [] [] ]						;-- where to collect processed args: [path operands options]
			arg-blk: extract-args/options arg-blk (program) opts		;-- turn command line into a block of known format
			foreach [name value] arg-blk [								;-- add options and operands to the `call`
				either name [											;-- name = none if operand, string if option
					unless supported? get/any program name [				;-- help & version special cases
						handle-special-arg/options program name opts
						;; exits as if called the program so it can continue and can control the quit value:
						throw/name ok?: yes 'complaint
					]
					add-refinements/options call get/any program name value opts
				][
					add-operand/options     call get/any program value opts
				]
			]
			call: prep-call/options call get/any program opts			;-- turn `call` block into an actual function call
			set/any 'r do call											;-- call the function
			ok?: yes													;@@ can't `return :r` here, compiler bug #4202
		] 'complaint
		if ok? [return :r]								;-- normal execution ends here
														;-- otherwise, there was a processing error!
		if :handler [return do [handler err]]			;-- pass handler's return through, if any ;@@ DO for compiler
														;-- if no handler, display the error (err = [code message])
		print next err									;@@ TODO: output to stderr (not yet in Red)
		quit/return 1									;-- nonzero code signals failure to scripts running this program
	]


	;; ████████████  EXTRA TESTS  ████████████

	#debug [
		test-prog-1: func [
			a [integer!] b [file!] c [time! date! block!] "docstring of c"
			/x
			/y "docstring of y"
				y1 [float!] "docstring of y1" 
			/y2 "alias y"
			/z "docstring of z"
				z1 [block! date!] "docstring of z1"
			/local q
		][
			compose/only [a: (a) b: (b) c: (c) x: (x) y: (y) y1: (y1) y2: (y2) z: (z) z1: (z1)]
		]

		test-prog-2: func [a b] [
			compose/only [a: (a) b: (b)]
		]

		test-prog-3: func [/a x [logic! block!] /b y [logic!] /c z [logic! string!]] [
			compose/only [a: (a) x: (x) b: (b) y: (y) c: (c) z: (z)]
		]

		test-ok-1: function [result [block!] args [block!] /with opts [block!]] [
			got: process-into/options test-prog-1 compose [args: args (any [opts []])]
			replace/all result 'false false
			replace/all result 'true  true
			replace/all result 'none  none
			assert [result = got]
		]

		test-ok-3: function [result [block!] args [block!]] [
			got: process-into/options test-prog-3 [args: args]
			replace/all result 'false false
			replace/all result 'true  true
			replace/all result 'none  none
			assert [result = got]
		]

		handler: func [er [block!]] [return er/1]

		test-fail-1: function ['code [word!] args [block!]] [
			got: process-into/options test-prog-1 [args: args on-error: handler]
			assert [code = got]
		]

		test-fail-2: function ['code [word!] args [block!]] [
			got: process-into/options test-prog-2 [args: args on-error: handler]
			assert [code = got]
		]

		test-fail-3: function ['code [word!] args [block!]] [
			got: process-into/options test-prog-3 [args: args on-error: handler]
			assert [code = got]
		]

		test-ok-1 
			[a: 1 b: %a.out c: []                   x: false y: false y1: none y2: false z: false z1: none                   ]
			["1" "a.out"]
		test-ok-1 
			[a: 1 b: %-     c: []                   x: false y: false y1: none y2: false z: false z1: none                   ]
			["1" "-"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00]            x: false y: false y1: none y2: false z: false z1: none                   ]
			["1" "a.out" "3:0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: false y: false y1: none y2: false z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: false y1: none y2: false z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y 1.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "--y2" "1.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "--y2 1.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 1.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "--y2=1.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 2.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1.0" "-y" "2.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 2.0  y2: true  z: false z1: none                   ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1.0" "--y2" "2.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 2.0  y2: true  z: true  z1: [1-Jan-2001]           ]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1.0" "-y" "2.0" "-z" "1/1/1"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 2.0  y2: true  z: true  z1: [1-Jan-2001 2-Feb-2002]]
			["1" "a.out" "3:0" "4:5:6" "-x" "-y" "1.0" "-y" "2.0" "-z" "1/1/1" "-z" "2/2/2"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4:05:06]    x: true  y: true  y1: 2.0  y2: true  z: true  z1: [1-Jan-2001 2-Feb-2002]]
			["1" "-z" "1/1/1" "a.out" "-z 2/2/2" "-y" "1.0" "3:0" "4:5:6" "-x" "-y" "2.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4-May-2006] x: true  y: true  y1: 2.0  y2: true  z: true  z1: [1-Jan-2001 2-Feb-2002]]
			["1" "-z 1/1/1" "a.out" "-z 2/2/2" "-y" "1.0" "3:0" "4/5/6" "-x" "-y" "2.0"]
		test-ok-1 
			[a: 1 b: %a.out c: [3:00:00 4-May-2006 4:00:00 5:00:00] x: true  y: true  y1: 2.0  y2: true  z: true  z1: [1-Jan-2001 2-Feb-2002]]
			["1" "-z 1/1/1" "a.out" "-z 2/2/2" "-y" "1.0" "3:0" "4/5/6" "4:0" "5:0:0" "-x" "-y" "2.0"]
		;; shortcut tests
		test-ok-1/with 
			[a: 0 b: %"" c: [] x: false y: false y1: none y2: false z: true z1: [2-Feb-2002]]
			["-z 2/2/2"]
			[shortcuts: [z]]
		test-ok-1/with 
			[a: 0 b: %"" c: [] x: true y: false y1: none y2: false z: false z1: none]
			["-x"]
			[shortcuts: [z x]]
		test-ok-1/with 
			[a: 0 b: %"" c: [] x: true y: false y1: none y2: false z: true z1: [2-Feb-2002]]
			["-z 2/2/2" "-x"]
			[shortcuts: [z]]
		test-ok-1/with 
			[a: 0 b: %"" c: [] x: true y: false y1: none y2: false z: true z1: [2-Feb-2002]]
			["-z 2/2/2" "-x"]
			[shortcuts: [x]]

		test-fail-1 ER_FEW    []
		test-fail-1 ER_FEW    ["1"]
		test-fail-1 ER_TYPE   ["1" "2" "-z 1000"]
		test-fail-1 ER_LOAD   ["1" "2" "-z )&#@"]
		test-fail-1 ER_OPT    ["1" "2" "--unknown-option"]
		test-fail-1 ER_OPT    ["1" "2" "--7x0"]
		test-fail-1 ER_CHAR   ["1" "2" "--y2%bad"]
		test-fail-1 ER_EMPTY  ["1" "2" "-z"]
		test-fail-1 ER_VAL    ["1" "2" "-x 100"]
		test-fail-1 ER_FORMAT ["1" "2" "-zxc"]

		test-fail-2 ER_MUCH   ["1" "2" "3"]

		test-ok-3 [a: false x: none b: true y: true c: false z: none] ["-b" "yes"]
		test-ok-3 [a: false x: none b: true y: true c: false z: none] ["-b" "on"]
		test-ok-3 [a: false x: none b: true y: true c: false z: none] ["-b" "true"]
		test-ok-3 
			compose/deep [a: true x: [(true) (false) (false) (false)] b: false y: none c: false z: none]
			["-a" "yes" "-a" "no" "-a" "false" "-a" "off"]
		test-ok-3 [a: false x: none b: false y: none c: true z: false] ["-c" "no"]
		test-ok-3 [a: false x: none b: false y: none c: true z: true] ["-c" "yes"]

		test-fail-3 ER_TYPE   ["-a" "100"]

		assert [(reduce [none "--" none "-- --"]) = extract-args ["--" "--" "-- --"] test-prog-1]

		assert [(help-for/no-version test-prog-1                ) = (help-for/options test-prog-1 [no-version: yes]         )]
		assert [(help-for/no-help    test-prog-1                ) = (help-for/options test-prog-1 [no-help: yes]            )]
		assert [(help-for/name       test-prog-1 "no name!"     ) = (help-for/options test-prog-1 [name: "no name!"]        )]
		assert [(help-for/exename    test-prog-1 "no name!"     ) = (help-for/options test-prog-1 [exename: "no name!"]     )]
		assert [(help-for/version    test-prog-1 1.2.3.4        ) = (help-for/options test-prog-1 [version: 1.2.3.4]        )]
		assert [(help-for/columns    test-prog-1 [5 10 20 10 30]) = (help-for/options test-prog-1 [columns: [5 10 20 10 30]])]

		assert [(version-for/name       test-prog-1 "no name!"  ) = (version-for/options test-prog-1 [name: "no name!"]     )]
		assert [(version-for/version    test-prog-1 "custom"    ) = (version-for/options test-prog-1 [version: "custom"]    )]
		assert [(version-for/brief      test-prog-1             ) = (version-for/options test-prog-1 [brief: yes]           )]
		assert [(syntax-for/exename     test-prog-1 "no name!"  ) = (syntax-for/options  test-prog-1 [exename: "no name!"]  )]

		; print help-for test-prog-2
		; process-into/options test-prog-2 [args: ["-1" "2" "3"]]

		; print version-for test-prog-1

		; print help-for/columns test-prog-1 [1 3 6 8 10]
		print ["CLI self-test:" assertions-run "assertions evaluated"]

	];; #debug

];; cli: context
];; do expand-directives

];; #local

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