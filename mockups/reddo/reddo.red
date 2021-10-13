Red [
	title: "RedDo: eval Red code from the command line"
	needs: 'view										;-- needed to be able to show GUIs
]

#include %../../cli.red
reddo: func ["Execute Red code from command line" code [block! string!]] [
	do/expand load/all system/script/args				;-- accepts args to show help, but uses raw cmdline instead for dblquotes
]
cli/process-into reddo