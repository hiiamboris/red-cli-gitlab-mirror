Red []

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#assert on

#macro [#assert block!] func [s e] [
	either assertions [ reduce ['assert s/2] ][ [] ]
]

assert: function [contract [block!]][
	set [cond msg] reduce contract
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
