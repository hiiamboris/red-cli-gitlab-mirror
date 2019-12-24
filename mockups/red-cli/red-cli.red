Red []

;; Obviously, I'm a bit fighting here against both Red and CLI designs, trying to find a compromise ☻

#include %../../cli.red

context [															;-- do not add another functions to system/words

	;; this will display help for commands
	red-cli: function ["Multi-command CLI demo" command arguments [block!]] [
		if empty? arguments [										;-- list of all commands
			print cli/version-for/brief Red-CLI
			print {The following commands are supported:^/}
			print form cmds
			print rejoin ["^/Type `" cli/default-exename " help <command>` for a syntax of a specific command"]
			quit/return 0
		]
		if attempt [find cmds command: to word! arguments/1] [		;-- specific command help
			help: cli/help-for/no-help/no-version (command)
			help: change/part help cli/version-for/brief Red-CLI  find/tail help lf
			insert find/tail help "red-cli" rejoin [" " command]
			print head help
			quit/return 0
		]
		set 'system/words/command command							;-- unrecognized; for error display
	]

	if empty? system/options/args [									;-- no arguments case
		print cli/help-for/no-help Red-CLI
		print rejoin ["Tip: type `" cli/default-exename " help` for a list of a list of supported commands"]
		quit/return 0
	]
																	;-- some arguments given...

	;; list available functions as commands
	pos: sws: to block! system/words
	cmds: collect [while [pos: find/tail pos function!] [unless datatype? :pos/-1 [keep to word! :pos/-2]]]
	remove find cmds 'help											;-- help is reserved for the script itself

	;; try to interpret the specific command
	command: first system/options/args
	if attempt [find cmds command: to word! command] [				;-- known command evaluation

		;; CLI complains when it encounters a type(set) that it cannot meaningfully enforce
		;; so, I have to clean up the spec from those
		parse s: spec-of get command [any [
			pos: block! (
																	;-- expand typesets
				repeat i length? pos/1 [if typeset? ts: get pos/1/:i [change/part at pos/1 i to block! ts 1]]
				pos/1: intersect pos/1 to block! cli/supported-set	;-- remove unsupported types
				any [last? pos/1  remove find pos/1 'block!]		;-- remove block! as well, or every value gets wrapped into it
			)
		|	skip
		]]
		probe cli/process-into/args (command) next system/options/args
		quit/return 0
	]

	if "help" = form command [cli/process-into/no-help Red-CLI]		;-- handle `help` command

	print ["Unrecognized command" uppercase form command]			;-- handle errors
	quit/return 1
]