Red []

#include %../../cli.red
do %profile-gab.red 	;-- it doesn't compile because of the `loop` thing :(

context [
	profile: func spec-of :system/words/profile [
		forall blocks [blocks/1: to block! load blocks/1]	;-- we have to prepare the input block: load every string in it
		call: reduce ['system/words/profile blocks]			;-- then we have to reinvent `apply`
		if accuracy [append call/1 'accuracy  append call run-time]
		if show     [append call/1 'show]
		do call
	]
	probe cli/process-into profile
]
