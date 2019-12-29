Red [needs: 'view]

#if all [rebol system/version/4 = 3] [					;-- test if compiling on Windows
	#system-global [
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
		code: AttachConsole -1							;-- -1 = ATTACH_PARENT_PROCESS
		er: GetLastError
		either any [
			code <> 0									;-- successful attach
			er = 5										;-- already attached (5 = ERROR_ACCESS_DENIED)
		][0][er]
	]
	hook-to-new-console: routine [return: [logic!]] [
		FreeConsole AllocConsole						;-- Alloc may fail if already attached - free first
	]
]

is-print-available?: routine [return: [logic!]] [dyn-print/red-cnt > 0]
unless is-print-available? [alert "`print` is not compiled in! Use -t MSDOS"]

quit: func [/return][throw 'quit]						;-- we don't want to close that console promptly
#include %../../cli.red

hello-gooey-world: func ["Demo of a GUI program having CLI output at whim"][
	view/options [below
		text "GUI Window"
		area "Check: there should be no console window open^/Run with --help or --version to get console output!"
		button focus "Close it!" [unview]
	] [text: "Gooey demo!"]
]

fresh?: no
#if all [rebol system/version/4 = 3] [					;-- hooks are undefined on other platforms
	unless empty? system/options/args [					;-- an option is passed to the program; has to go CLI
		unless 0 = er: hook-to-parent-console [			;-- returns 0 on success
			alert rejoin ["AttachConsole failed! error code=" er]
			fresh?: hook-to-new-console
			print "Oops! Failed to attach to console."
			print "Here's a new one though..."
		]
		prin lf											;-- to start on a new line, otherwise can catch parent in the middle of smth ;)
	]
	renew-std-handles									;-- new console, new handles
]

catch [													;-- catch our redefined `quit`
	cli/process-into/name hello-gooey-world "^/hello gooey world"	;-- add linefeed before the program name else it starts with console prompt
]
if fresh? [call/console/shell/wait "pause"]				;-- wait for a key press before closing the new console
