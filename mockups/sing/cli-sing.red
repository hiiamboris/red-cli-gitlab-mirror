Red []

#include %../../cli.red
do load %sing-drinking-song.red   ; it has no header

context [
	sing: func spec-of :system/words/sing [
		system/words/sing to block! load input
	]
	cli/process-into sing
]