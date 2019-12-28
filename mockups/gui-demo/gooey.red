Red [needs: 'view config: [sub-system: 'GUI]]

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
					GetLastError: "GetLastError" [
						return:             [integer!]
					]
	            ]
	        ]
	    ]
	]

	hook-to-parent-console: routine [return: [logic!] /local code] [
		code: AttachConsole -1							;-- -1 = ATTACH_PARENT_PROCESS
		any [
			code <> 0									;-- successful attach
			GetLastError = 5							;-- already attached (5 = ERROR_ACCESS_DENIED)
		]
	]
	hook-to-new-console: routine [return: [logic!]] [
		FreeConsole AllocConsole						;-- Alloc may fail if already attached - free first
	]
]

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
		unless hook-to-parent-console [
			fresh?: hook-to-new-console
			print "Oops! Failed to attach to console."
			print "Here's a new one though..."
		]
		prin lf											;-- to start on a new line, otherwise can catch parent in the middle of smth ;)
	]
]

catch [cli/process-into hello-gooey-world]
if fresh? [call/console/shell/wait "pause"]				;-- wait for a key press before closing the new console
