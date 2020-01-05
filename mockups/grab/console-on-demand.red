Red [
	Title:       "On-demand console for Windows GUI executables"
	Description: "First `print` call finds (or creates) a console to print into"
	Author:      @hiiamboris
	License:     'BSD-3
	Usage: {
		...... using CLI lib: ......
		#include %console-on-demand.red
		#include %cli.red
		wrap [cli/process-into your-function]

		...... or without CLI: ......
		#include %console-on-demand.red
		your code here
	}
]

#either all [rebol system/version/4 = 3] [					;-- test if compiling on Windows
	#system [
	    #if OS = 'Windows [
	        #import [
	            "kernel32.dll" stdcall [
	                AttachConsole:   "AttachConsole" [
	                    processID       [integer!]
	                    return:         [integer!]
	                ]
					AllocConsole: "AllocConsole" [return: [logic!]]
					FreeConsole: "FreeConsole" [return: [logic!]]
					GetLastError: "GetLastError" [return: [integer!]]
	            ]
	        ]
	    ]
	]

	renew-std-handles: routine [] [
		stdin:  win32-startup-ctx/GetStdHandle WIN_STD_INPUT_HANDLE
		stdout: win32-startup-ctx/GetStdHandle WIN_STD_OUTPUT_HANDLE
		stderr: win32-startup-ctx/GetStdHandle WIN_STD_ERROR_HANDLE
	]

	hook-to-parent-console: routine [return: [integer!] /local code er] [
		code: AttachConsole -1								;-- -1 = ATTACH_PARENT_PROCESS
		er: GetLastError
		either any [
			code <> 0										;-- successful attach
			er = 5											;-- already attached (5 = ERROR_ACCESS_DENIED)
		][0][er]
	]

	hook-to-new-console: routine [return: [logic!]] [
		FreeConsole AllocConsole							;-- Alloc may fail if already attached - free first
	]

	is-print-available?: routine [return: [logic!]] [dyn-print/red-cnt > 0]
	unless is-print-available? [alert "`print` is not compiled in! Use -t MSDOS"]

	quit: func [/return][throw 'quit]						;-- we don't want to close that console promptly

	context [
		fresh?: no
		set 'maybe-print :print

		ensure-console: has [er] [							;-- provide console for printing
			do [												;-- do not compile this -- too dynamic
				unless empty? system/options/args [				;-- an option is passed to the program; has to go CLI
					unless 0 = er: hook-to-parent-console [		;-- returns 0 on success
						alert rejoin ["AttachConsole failed! error code=" er]
						fresh?: hook-to-new-console
						print "Oops! Failed to attach to console."
						print "Here's a new one though..."
					]
					prin lf										;-- to start on a new line, otherwise can catch parent in the middle of smth ;)
				]
				renew-std-handles								;-- new console, new handles
			]
		]

		set 'print func [value [any-type!]] [				;-- make `print` spawn consoles
			do [												;-- do not compile this -- too dynamic
				ensure-console
				print: :maybe-print
				prin lf											;-- extra line feed is needed when caret in parent console is not at line beginning
				print :value
			]
		]

		set 'wrap func [code [block!]] [
			catch code
			if fresh? [call/console/shell/wait "pause"]
		]
	]
][
	wrap: func [code [block!]] [do code]
]
