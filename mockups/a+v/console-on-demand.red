Red [
	Title:       "On-demand console for Windows GUI executables"
	Description: "First `print` call finds (or creates) a console to print into"
	Author:      @hiiamboris
	License:     'BSD-3
	Usage: {
		1. Include this file
			...... using CLI lib: ......
			#include %console-on-demand.red
			#include %cli.red
			..definitions..
			wrap [cli/process-into your-function]

			...... or without CLI lib: ......
			#include %console-on-demand.red
			wrap [..all your code here..]

			...... or if you'd rather avoid wrap so your code is compiled ......
			#include %console-on-demand.red
			..lots of code and prints..
			pause-console

		2. Compile your program with `-t MSDOS` flag (`print` won't be compiled with -t Windows!)

		3. Turn it into a GUI program with the command (from Red console):
			flip-exe-flag %full-path-name-of-the-compiled-program.exe
		(you can use `reddo` to automate this in your build script)
		This will stop Windows from *automatically* showing a console for it.


		NOTE: `wrap` is used to catch `quit` and delay new console destruction (so user can read printed messages).
		If you're not using `quit`, you can just call `pause-console` at the end of the program.
		If you don't care if your messages are read, these functions are not needed.

		NOTE: `print` and `prin` are dynamically redefined, but compiler can't see that.
		It is better to wrap print statements into `wrap` or `do`, or use `-d` flag.
		But design is pretty forgiving about it, so it's not a strict requirement.
		You'll get extra WINAPI calls in the worst case.
	}
]

#either all [rebol config/OS = 'Windows] [				;-- test if compiling FOR Windows
	#if config/sub-system = 'GUI [
		#do [print "*** WARNING! Print won't work! Use -t MSDOS flag! ***"]
	]

	#system [
        #import [
            "kernel32.dll" stdcall [
                AttachConsole:   "AttachConsole" [
                    processID       [integer!]
                    return:         [integer!]
                ]
				AllocConsole:     "AllocConsole"     [return: [logic!]]
				FreeConsole:      "FreeConsole"      [return: [logic!]]
				GetLastError:     "GetLastError"     [return: [integer!]]
				GetConsoleWindow: "GetConsoleWindow" [return: [integer!]]
            ]
        ]
	]

	console-attached?: routine [return: [logic!]] [
		0 <> GetConsoleWindow
	]

	renew-std-handles: routine [] [						;-- required after switching to a new console buffer
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
		][0][er]										;-- returns 0 on success, error code otherwise
	]

	hook-to-new-console: routine [return: [logic!]] [
		FreeConsole AllocConsole						;-- Alloc may fail if already attached - free first
	]

	is-print-available?: routine [return: [logic!]] [dyn-print/red-cnt > 0]
	unless is-print-available? [alert "`print` is not compiled in! Use -t MSDOS"]	;-- an extra sanity check

	quit: func [/return code [integer!]][				;-- we don't want to close that console promptly
		throw/name any [code 0] 'quit
	]

	context [
		fresh?: no										;-- will become true after creating a new console window
		native-print: :print
		native-prin:  :prin

		ensure-console: does [							;-- provide a console for printing
			unless console-attached? [
				if 0 <> hook-to-parent-console [		;-- returns 0 on success
					fresh?: hook-to-new-console			;-- this isn't expected to fail though
				]
				renew-std-handles						;-- new console, new handles
			]
			do [										;-- dynamic code, can't be compiled
				print: :native-print					;-- restore native print after we have console
				prin:  :native-prin
				unless fresh? [prin "^/"]				;-- start on a new line, otherwise can catch parent in the middle of smth ;)
				ensure-console: does []					;-- no more need in this function
			]
		]

		set 'print func [value [any-type!]] [			;-- make `print` spawn consoles
			do [ensure-console print :value]			;-- do not compile this -- too dynamic
		]

		set 'prin func [value [any-type!]] [			;-- make `prin` spawn consoles too
			do [ensure-console prin :value]				;-- do not compile this -- too dynamic
		]

		set 'pause-console does [						;-- wait a key press if it's a new terminal
			if fresh? [call/console/shell/wait "pause"]
		]

		set 'wrap func [code [block!] /local r] [		;-- used to catch `quit`
			code: catch/name [set/any 'r do code  'ok] 'quit
			pause-console
			if code <> 'ok [quit-return :code]
			:r
		]
	]
][
	wrap: :do
	pause-console: does []
]
