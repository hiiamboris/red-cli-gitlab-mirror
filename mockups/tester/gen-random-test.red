Red [
	Title:		"Random test generator for CLI system "
	Author: 	@hiiamboris
	File: 		%gen-random-test.red
	Tabs:		4
	Rights:		"Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %../../cli.red

random/seed now/time/precise

selective-catch: func [code type id /local e] [
	all [
		error? set/any 'e try/all code
		any [e/type <> type  e/id <> id  exit]			;-- muffle the selected error
		do e
	]
	:e
]
catch-a-break:  func [code] [selective-catch code 'throw 'break]
catch-continue: func [code] [selective-catch code 'throw 'continue]
forparse: func [spec srs body] [catch-a-break [parse srs [any [spec (catch-continue body) | skip]]]]
find-parse: func [srs ptrn] [unless forparse [pos: ptrn] srs [break] [do make error! "not found"] :pos]

gen-random-test: function [
	program [file!] "test subject"
][
	unless exists? program [do make error! "not found"]
	program: load/all program
	forall program [
		if attempt [find/match :program/1 'cli/process-into] [
			entry: second program
			program: head program
			break
		]
	]
	unless entry [do make error! "not found"]
	print ["Found entry point:" entry]			;@@ TODO: look in contexts as well

	find-parse program [set w entry if (set-word? w) ['func | 'function] set spec block!] program
	print ["Found spec:" mold spec]
	
	program-options: copy ["--help" "--version"]
	forparse [refinement! (break) | set oper word!] spec [
		print ["Found operand:" oper]
		loop random 3 [append program-options rejoin [random first random ["1234" "123.45" "ABCD"]]]	;@@ TODO: more types
	]
	forparse [
		set opt refinement!
		set doc opt string!
		set arg opt word!
	] spec [
		print ["Found option:" opt arg doc]
		if find/match doc "alias" [arg: yes]
		--:  either single? form opt ["-"]["--"]
		dlm: either single? form opt [" "]["="]
		loop random 3 [
			append program-options rejoin [
				-- opt either arg
					[rejoin [dlm random copy first random ["1234" "123.45" "ABCD"]]]
					[""]
			]
		]
	]
	print ["Generated program options:" mold program-options]

	processor-options: copy []
	forparse [
		set opt refinement!
		set doc opt string!
		set arg opt word!
	] spec-of :cli/process-into [
		unless find [/options /local /args /on-error] opt [
			append/only processor-options blk: to block! to word! opt
			if arg [append blk random copy "QWE RTY"]
		]
	]
	print ["Generated processor options:" mold/flat processor-options]

	replace program %../../cli.red %../../../cli.red

	scripts: copy []
	make-dir %scripts
	loop 20 [
		probe program-mod: copy/deep program
		call: copy/deep reduce ['cli/process-into entry]
		loop 4 [
			if even? random 2 [
				append call/1 first chosen: random/only processor-options
				unless single? chosen [append call second chosen]
			]
		]
		pos: find/only program-mod 'cli/process-into
		unless pos [do make error! "TBD"]
		change/part pos call 2
		script: rejoin [random "script123456" ".red"]
		append scripts script
		save/all rejoin [%scripts/ script] program-mod
	]
	print ["Generated scripts:" mold scripts]

	tests: copy []
	make-dir %tests
	loop 100 [
		script: random/only scripts
		num: length? program-options
		num: to integer! (random 1.0) ** 2 * num
		test: rejoin [random "test12345678" ".bat"]
		append tests test
		text: reduce ["@red" rejoin [%../scripts/ script]]
		loop num [append text random/only program-options]
		write rejoin [%tests/ test] form text
	]
	print ["Generated tests:" mold tests]
]

cli/process-into gen-random-test