Red [
	Title:		"Simple & powerful command line argument validation system"
	Author: 	@hiiamboris
	File: 		%cli.red
	Version:	20/01/2020
	Tabs:		4
	Rights:		"Copyright (C) 2011-2020 Red Foundation. All rights reserved."
	Homepage:	https://gitlab.com/hiiamboris/red-cli
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
	Bugs: {
		- Red does not support system/script/header, so
		  don't expect values from it to be automatically fetched yet
		  unless you make this object yourself
		- When compiled, words lose their case info, so
		  if program name is generated from a word, it will always be in lower case
	}
	Usage: {
		my-program: function [operands .. /switches /options arguments] [code]
		cli/process-into my-program
	}
]


;; ████████████  DEBUGGING FACILITIES  ████████████

#macro [#debug 'on]  func [s e] [debug: on  []]
#macro [#debug 'off] func [s e] [debug: off []]
#macro [#debug block!] func [s e] [either debug [ s/2 ][ [] ]]
#debug off

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#assert off

#macro [#assert block!] func [s e] [
	either assertions [ reduce ['assert s/2] ][ [] ]
]


;-- comment these out to disable self-testing

; #debug on
; #assert on


; do expand-directives [									;-- boring workaround for #4128
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
	ER_OPT:    'ER_OPT			;-- unknown option
	ER_FORMAT: 'ER_FORMAT		;-- unknown option format
	ER_CHAR:   'ER_CHAR			;-- unsupported char in option name

	;-- supported argument FORMAT TYPES
	loadable-set: make typeset! [integer! float! percent! logic! url! email! tag! issue! time! date! pair!]
	supported-set: union loadable-set make typeset! [string! file! block!]


	;-- used to signal an error in supplied command line
	complain: func [about [block!]] [
		;@@ TODO: print to stderr instead (not supported by Red yet)
		#assert [word? first about]
		throw/name reduce about 'complaint
	]

	else: make op! func [truth e [string!]] [unless truth [do make error! e]]


	option?: func [
		"Check if ARG is an option name"
		arg			[string!]
		/options				"(placeholder for future expansion)"
			opts	[block! none!]
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
		#assert [word? s]
		to refinement! s
	]

	#assert [/x = str-to-ref "x"]

	find-refinement: function [
		"Return SPEC at block containing /ref, or none if not found"
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


	default: func [:w [set-word!] v] [unless get/any :w [set :w v]]

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
		=ref=: [									;-- option (refinement)
			any [/local to [refinement! | end]]			;-- skip /locals (/externs are never present in the spec)
			set name    refinement!
			set doc opt string!     (default doc: copy "")
			(										;-- check the docstring for an alias definition
				either force-nullary?: target: find/match doc "alias "	;-- alias? allow no arguments to it
					[ repend aliases [name target] ]
					[ repend r [to block! name  doc  none] ]
			)
		]
		force-nullary?: no  aliases: copy []  r: copy []
		parse spec [any string! any [=arg= | =ref=]]
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

	#assert [ (reduce ['x        "" make typeset! [string!] ]) = prep-spec [x] ]
	#assert [ (reduce ['x     "doc" make typeset! [integer!]]) = prep-spec [x [integer!] "doc"] ]
	#assert [ (reduce [[/x /y]   "" none                    ]) = prep-spec [/x /y "alias x"] ]
	#assert [ (reduce [[/x /y]   "" none                    ]) = prep-spec [/y "alias x"       /x] ]
	#assert [ (reduce [[/x /y]   "" none                    ]) = prep-spec [/y "alias /x"      /x] ]
	#assert [
		(reduce [
			[/x /y] "doc1" none
			'z      "doc2" make typeset! [integer! block!]
		]) = prep-spec [/x "doc1" z [integer! block!] "doc2" /y "alias x"]
	]
	#assert [ error? try [prep-spec [/x y /z "alias x" w]] ]
	#assert [ error? try [prep-spec [/z "alias x" w]] ]


	supported?: function [
		"Check if option R is supported by F"
		f [function!] r [string!]
	][
		not none? find-refinement prep-spec :f str-to-ref r
	]

	#assert [    supported? func [/x][]     "x"]
	#assert [    supported? func [a /x y][] "x"]
	#assert [not supported? func [a /x y][] "y"]
	#assert [not supported? func [a /x y][] "a"]
	#assert [not supported? func [a /x y][] "b"]


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

	#assert [    unary? func [/x y][]   "x"]
	#assert [not unary? func [/x y z][] "x"]
	#assert [not unary? func [/x][]     "x"]

	
	check-value: function [
		"Typecheck value V against a set of TYPES"
		v			[string!]
		types		[typeset! block!]
		/options				"(placeholder for future expansion)"
			opts	[block! none!]
	][
		if block? types [types: make typeset! types]
		#assert [not empty? to block! types]

		unsupp: to block! exclude types supported-set
		(empty? unsupp) else form reduce ["Unsupported types in" types "typeset:" unsupp]
		
		loadable: intersect types loadable-set
		case/all [
			loadable <> make typeset! [] [				;-- contains a loadable type?
				try [x: load v]
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

	#assert [1   = check-value "1" [ integer! ]]
	#assert [1   = check-value "1" [ string! integer! ]]
	#assert ["1" = check-value "1" [ string! ]]
	#assert [%1  = check-value "1" [ file! ]]
	#assert [%1  = check-value "1" [ string! file! ]]
	#assert [error? try     [check-value "1"   [typeset!]]]
	#assert [error? try/all [check-value "1 2" [integer!]]]
	#assert [error? try/all [check-value "1 2" [integer! block!]]]
	#assert [error? try/all [check-value "1"   [date!]]]
	#assert [error? try/all [check-value ")#!" [date!]]]



	;; ████████████  /OPTIONS BLOCK SUPPORT  ████████████

	;-- NOTE: options and their argument names should be consistent across all CLI funcs to work properly
	;--       otherwise one option will do different things in different funcs that use `apply-options`


	find-option?: function [
		"Find an option O in F's spec, return a block [option argument arg-types], or none if not found"
		f [function!] o [any-word!]
	][
		all [
			pos: find/tail copy spec-of :f o			;-- found o
			refinement? pos/-1							;-- it's an /o
			(
				clear find pos refinement!				;-- look no further than next /ref
				pos: find pos word!						;-- find an argument after
				reduce [
					bind o :f
					all [pos bind pos/1 :f]
					all [pos either block? pos/2 [ pos/2 ][ copy [default!] ]]
				]
			)
		]
	]

	apply-options: function [
		"Populate refinements of the CALLER from an OPTIONS block (does not override those already set)"
		caller [function!]
		options [block! none!]
		/local opt arg types
	][
		unless options [exit]									;-- no options were provided initially
		spec: spec-of :caller
		foreach [opt val] options [
			if all [
				set [opt arg types] find-option? :caller opt	;-- option is supported by the caller
				not get/any opt									;-- it wasn't explicitly provided (tip: `opt` is bound to :caller)
			][
				if arg [
					if none? :val [continue]					;-- no need to set to `none` (none is rarely in the accepted typeset)
					unless find types type: type?/word :val [	;-- check the supplied value type
						if word? :val [set/any 'val get/any val]
						(find types type: type?/word :val)		;-- try also with word's value
						else form reduce [
							mold/part :caller 50 "does not accept" opt "of type" type
							"^/Options: " mold options
						]
					]
					set arg :val
				]
				set opt to logic! :val
			]
		]
	]

	fill-options: function [
		"Build an options block from CALLER's spec that can be passed to other funcs"
		caller [function!]
	][
		r: make block! 20
		pos: spec-of :caller
		while [pos: find/tail pos refinement!] [
			set [opt arg types] find-option? :caller to word! pos/-1
			#assert [opt]
			repend r [
				to set-word! opt
				get/any any [arg opt]
			]
		]
		all [									;-- unify the result with caller's own `opts` block
			set [opt arg types] find-option? :caller 'options		;-- has /options
			arg = 'opts							;-- it's valid `/options opts`
			block? get/any arg					;-- opts is set to a block
			r: union/skip r get arg	2			;-- first arg `r` gets priority
		]
		r
	]

	#assert [[a: b] = union/skip [a: b] [a: c] 2]


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
			opts	[block! none!]
	][
		ref: str-to-ref name
		spec: find-refinement prep-spec :prog ref
		refs: first spec
		#assert [not empty? refs]
		
		either pos: find/tail call/3 ref [				;-- are refinements already added?
			pos: find pos block!							;-- jump to values
		][												;-- otherwise
			append call/3 refs								;-- list all aliases
			pos: tail call/3
			append/only call/3 copy []						;-- create a block to hold values
		]
		#assert [(unary? :prog name) <> (none? value)]	;-- match provided arity with expected one

		if unary? :prog name [							;-- check & add the value
			types: pick spec 6								;-- 3rd is none, 6th is argument's typeset
			value: check-value/options value types opts
			append pos/1 value
		]
		call
	]

	#assert [ [f   [1 2] [/x []    ]] = add-refinements [f   [1 2] [      ]] func [/x /y z [integer!]][] "x" "0" ]
	#assert [ [f   [1 2] [/y [3]   ]] = add-refinements [f   [1 2] [      ]] func [/x /y z [integer!]][] "y" "3" ]
	#assert [ [y/y [1 2] [/y [3]   ]] = add-refinements [y/y [1 2] [      ]] func [/x /y z [integer!]][] "y" "3" ]
	#assert [ [y/y [1 2] [/y [3 4] ]] = add-refinements [y/y [1 2] [/y [3]]] func [/x /y z [integer!]][] "y" "4" ]
	#assert [ [y/y [1 2] [/y /z [3]]] = add-refinements [y/y [1 2] [      ]] func [/x /y q [integer!] /z "alias y"][] "z" "3" ]


	add-operand: function [
		"Append an operand's VALUE to the internal CALL block"
		call		[block!]
		prog		[function!]
		value		[string!]
		/options				"(placeholder for future expansion)"
			opts	[block! none!]
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
		#assert [word? first spec]
		#assert [typeset? third spec]
		value: check-value/options value third spec opts
		append call/2 value
		call
	]

	#assert [ [f [1]     []] = add-operand [f []    []] func [a [integer!] b [integer!] /x /y z][] "1" ]
	#assert [ [f [1 2]   []] = add-operand [f [1]   []] func [a [integer!] b [integer!] /x /y z][] "2" ]
	#assert [ [f [1 2 3] []] = add-operand [f [1 2] []] func [a [integer!] b [integer!] /x /y z][] "3" ]


	prep-call: function [
		"Convert internal CALL block into a PROGRAM Red function call"
		call		[block!]
		program		[function!]
		/options				"(placeholder for future expansion)"
			opts	[block! none!]
	][
		spec: prep-spec :program
		r: reduce [call/1]
														;-- add mandatory arguments
		foreach arg call/2 [
			either word? spec/1 [							;-- pass single argument normally
				#assert [typeset? spec/3]
				if find spec/3 block! [arg: reduce [arg]]
				append/only r arg
				spec: skip spec 3
			][												;-- collect all other arguments into the last block
				unless block? last r [complain [ER_MUCH "Extra operands given"]]
				#assert [block? last r]
				append last r arg
			]
		]

		if find spec/3 block! [append/only r []]		;-- if block is accepted, provide an empty one in absence of arguments

		arity: preprocessor/func-arity? spec-of :program
		if 1 + arity > length? r [complain [ER_FEW "Not enough operands given"]]

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
							#assert [not empty? x]
							append r last x					;-- last value replaces prior ones
						]
						types: none
					]
				]
			]
		]
		r
	]

	#assert [ [y/y/x       ] = prep-call [y/y [] [/x    [0]]] func [/x /y q /z "alias y"][] ]
	#assert [ [y/y/y/z 3   ] = prep-call [y/y [] [/y /z [3]]] func [/x /y q [integer!] /z "alias /y"][] ]
	#assert [ [y/y/y/z [3] ] = prep-call [y/y [] [/y /z [3]]] func [/x /y q [integer! block!] /z "alias y"][] ]
	#assert [ [y/y 1 2     ] = prep-call [y/y [1 2] []      ] func [a [integer!] b [integer!] /x /z "alias /x"][] ]
	#assert [ [y/y 1 [2]   ] = prep-call [y/y [1 2] []      ] func [a [integer!] b [integer! block!] /x /z "alias x"][] ]
	#assert [ [y/y 1 [2 3] ] = prep-call [y/y [1 2 3] []    ] func [a [integer!] b [integer! block!] /x /z "alias /x"][] ]



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
			opts	[block! none!]
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

		do [											;@@ DO for compiler
			help-version-quit?: has [msg] [					;-- default -h / --version handler
				if msg: case [									;-- two special cases apply
					all [not no-help     find ["h" "help"] arg-name]
						[ help-for/options (program) opts ]
					all [not no-version  arg-name = "version"]
						[ version-for/options (program) opts ]
				][
					print msg
					quit/return 0
				]
			]
		]

		allow-options?: yes								;-- will be switched off by `--`
		r: make block! 20
		forall args [
			arg: :args/1
			unless string? :arg [arg: form :arg]		;-- should never happen?

			either not all [allow-options?  option?/options arg opts] [
				either all [arg == "--" allow-options?]
					[ allow-options?: no ]
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
						do [help-version-quit?]								;-- try default handlers when not handled by the program ;@@ DO for compiler
						complain [ER_OPT "Unsupported option:" arg]
					])
					[	if (unary? get/any program arg-name)			;-- read the value (if required)
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
	];; for-args: function


	;; ████████████  DEFAULT FORMATTERS  ████████████


	version-for: function [
		"Returns version text for the PROGRAM"
		'program	[word! path!]
		/name					"Overrides program name"
			pname	[string!]
		/exename				"Overrides executable name"
			xname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]
		/brief					"Include only the essential info"
		/options				"Specify all the above options as a block"
			opts	[block! none!]
	][
		apply-options context? 'opts opts

		r: make string! 100

		standalone?: none? system/options/script		;@@ is there a better way to check?

		do [dehyphenize: func [x] [replace/all form x #"-" #" "]]	;@@ DO for compiler
		pname: form any [
			pname										;-- when explicitly provided
			attempt [system/script/title]
			attempt [system/script/header/title]
			attempt [dehyphenize last program]			;-- last item in the path: obj/program
			do [dehyphenize program]					;-- the word itself ;@@ DO for compiler
			;-- reminder: do not use exe name as program name (it can be renamed easily by the user)
		]

		ver: form any [
			ver											;-- explicitly provided
			attempt [system/script/header/version]		;-- from the header
			attempt [first query system/options/script]	;-- script modification date if interpreted
			#do keep [now/date]							;-- compilation date otherwise
		]

		desc: first spec-of get/any program
		unless string? desc [desc: none]

		author:  attempt [system/script/header/author]	;@@ TODO: join multiple authors with comma or ampersand?
		rights:  attempt [system/script/header/rights]
		license: attempt [system/script/header/license]

		append r form compose [
			(pname) (ver)								;-- "Program 1.2.3"
			(any [desc ()])								;-- "long description ..."
			(either author [rejoin ["by "author]][()])	;-- "by Yours Truly"
			#"^/"
		]
		if rights  [repend r [rights #"^/"]]			;-- "(C) Copyrights..."

		unless brief [									;-- add detailed info
			commit: attempt [mold/part system/build/git/commit 8]
			#assert [system/version]
			#assert [system/platform]
			repend r [									;-- Red version
				pick ["Built with" "Using"] standalone?
				" Red " system/version
				either commit [ rejoin [" (" commit ")"] ][ "" ]
				" for " system/platform
				#"^/"
			]
			if standalone? [repend r ["Build timestamp: "#do keep [now]]]

			if license [repend r [license #"^/"]]		;-- "License text..."
		]

		r
	]

	syntax-for: function [
		"Returns usage text for the PROGRAM"
		'program	[word! path!]
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/columns				"Specify widths of columns: indent, short option, long option, argument, description"
			cols	[block!]
		/options				"Specify all the above options as a block"
			opts	[block! none!]
	][
		apply-options context? 'opts opts
		opts: fill-options context? 'opts
		
		spec: prep-spec get/any program
		unless no-version [repend spec [ [/version] "Display program version and exit" none ]]
		unless no-help    [repend spec [ [/h /help] "Display this help text and exit"  none ]]

		r: make string! 500

		do [											;@@ DO for compiler
			decorate: func [x types] [					;-- x -> "<x>" or "[x]"
				mold/flat to either find types block! [block!][tag!] x
			]
		]

		xname: form any [
			xname										;-- when explicitly provided
			default-exename								;-- try to infer it otherwise
		]

		repend r ["^/Syntax: " xname]					;-- "Syntax: program"
		if find spec none [append r " [options]"]		;-- add [options] if at least one option is supported
		foreach [name doc types] spec [					;-- list operands:
			if none? types [break]							;-- stop right after the last operand
			repend r [" " do [decorate name types]]			;-- append every operand as "<name>" ;@@ DO for compiler
		]
		append r "^/^/"

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
						-1 + index? find/last/tail copy/part s-doc/1 cols/5 #" "
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
			#assert [string? doc]
			either none? types [						;-- options
				#assert [not empty? names]

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
				#assert [word? names]
				either committed? [						;-- an operand?
					if empty? doc [continue]				;-- skip operands without description
					s-opts: copy ""							;-- leave "--flag" column empty
					s-arg: do [decorate names types]		;-- "<name>" or "[name]" ;@@ DO for compiler
				][										;-- an option then ("--flag" part was filled above)
					s-arg: do [decorate names none]			;-- always as "<name>" ;@@ DO for compiler
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
		r
	];; syntax-for: function


	help-for: function [
		"Returns help text for the PROGRAM"
		'program	[word! path!]
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/name					"Overrides program name"
			pname	[string!]
		/exename				"Overrides executable name"
			xname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]					;@@ TODO: add float? for 1.0 etc
		/columns				"Specify widths of columns: indent, short option, long option, argument, description"
			cols	[block!]
		/options				"Specify all the above options as a block"
			opts	[block! none!]
	][
		apply-options context? 'opts opts
		opts: fill-options context? 'opts
		rejoin [
			version-for/brief/options (program) opts
			syntax-for/options (program) opts
		]
	]



	;; ████████████  MAIN INTEFACE TO CLI ;)  ████████████


	process-into: function [
		"Calls PROGRAM with arguments read from the command line. Passes through the returned value"
		'program	[word! path!]						;-- can't support `function!` here cause can't add refinements to a function! literal
		/no-version				"Suppress automatic creation of --version argument"
		/no-help				"Suppress automatic creation of --help and -h arguments"
		/name					"Overrides program name"
			pname	[string!]
		/exename				"Overrides executable name"
			xname	[string!]
		/version				"Overrides version"
			ver		[tuple! string!]
		/args					"Overrides system/options/args"
			arg-blk	[block!]
		/on-error				"Custom error handler: func [error [block!]] [...]"
			handler [function!]
			;-- handler should accept a block: [error-code reduced values that constitute the error message]
			;;  error-codes are words: ER_FEW ER_MUCH ER_LOAD ER_TYPE ER_OPT ER_CHAR ER_EMPTY ER_VAL ER_FORMAT
			;;  value returned by handler on error is passed through by process-into
		/options				"Specify all the above options as a block"
			opts	[block!]
		/local opt val r ok?
	][
		err: catch/name [								;-- catch processing errors only
			apply-options context? 'opts opts				;-- args preference: /args, then /options, then system/options/args
			unless arg-blk [arg-blk: system/options/args]
			opts: fill-options context? 'opts

			call: copy/deep [ [] [] [] ]					;-- where to collect processed args
			change/only call program

			arg-blk: extract-args/options arg-blk (program) opts
			foreach [name value] arg-blk [					;-- do processing
				either name										;-- none if operand
					[ add-refinements/options call get/any program name value opts ]
					[ add-operand/options     call get/any program value opts ]
			]
														;-- call the function, return it's value
			set/any 'r do prep-call/options call get/any program opts
			ok?: yes									;@@ can't `return :r` here, compiler bug 
		] 'complaint
		if ok? [return :r]
														;-- so, there was a processing error!
		if :handler [return do [handler err]]			;-- pass handler's return through, if any ;@@ DO for compiler

		print next err									;@@ TODO: output to stderr (not yet in Red)
		quit/return 1
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

		test-ok-1: function [result [block!] args [block!]] [
			got: process-into/options test-prog-1 [args: args]
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
		assert [(version-for/exename    test-prog-1 "no name!"  ) = (version-for/options test-prog-1 [exename: "no name!"]  )]
		assert [(version-for/version    test-prog-1 "custom"    ) = (version-for/options test-prog-1 [version: "custom"]    )]
		assert [(version-for/brief      test-prog-1             ) = (version-for/options test-prog-1 [brief: yes]           )]

		; print help-for test-prog-2
		; process-into/options test-prog-2 [args: ["-1" "2" "3"]]

		; print version-for test-prog-1

		; print help-for/columns test-prog-1 [1 3 6 8 10]
		print ["CLI self-test:" assertions-run "assertions evaluated"]

	];; #debug

];; cli: context
; ];; do expand-directives
