Red [needs: 'view icon: %mpv-document.ico]

#include %setters.red
#include %composite.red
#include %glob.red
#include %cli.red


;-- setup
prints: func [b [block!] s [string!]] [print composite b s]

;-- the final call
play: function [player root vfile afile] [
	vfile: to-local-file vfile
	if afile [afile: to-local-file afile]
	cmd: composite['root] get bind either afile ['avcmd]['vcmd] :a+v

	cwd: what-dir
	change-dir root
	prints['root] {invoking: (cmd)^/from: "(to-local-file what-dir)"}
	call/show/wait/console cmd
	change-dir cwd
	quit
]

;-- the frontend
a+v: function [
	vfile [file!]
	/config conffile [file!]    "default: <exe-name>.conf"
	/player plcmd    [string!]  "default: mpv"
	/avcall avcmd    [string!]  {default: "(player)" "(vfile)" --audio-file "(afile)"}
	/vcall   vcmd    [string!]  {default: "(player)" "(vfile)"}
	/size      query-size      [pair!]    {default: 400x150}
	/font-name query-font-name [string!]
	/font-size query-font-size [integer!] {default: 12}
	/exclude xmasks  [string! block!] {Don't treat files with this mask as audio}
	/x "alias /exclude"
][
	player: plcmd
	default-config: [
		player: "mpv"
		avcmd:  {"(player)" "(vfile)" --audio-file "(afile)"}		;-- call when audio file is found
		vcmd:   {"(player)" "(vfile)"}								;-- call otherwise
		query-size: 400x150
		query-font-size: 12
		xmasks: ["*.ass" "*.ssa" "*.sub" "*.srt" "*.nfo" "*.log" "*.cue" "*.txt"]
		last-index: 1
	]

	set [origin: self:] split-path to-red-file do with system/options [any [script boot]] 
	clear any [find/last self "." ""]
	default conffile: to-red-file #composite %"(origin)(self).conf"

	set [path: vfile:] split-path clean-path to-red-file vfile
	prints['path] "root path: (path)"
	prints['path] "using video file: (vfile)"
	clear find/last vfile-noex: copy vfile "."
	imasks: #composite "(vfile-noex).*"

	;-- read the config
	config: none
	if exists? conffile [
		if error? msg: try/all [
			;-- config should not override command line options
			config: make object default-config load/all conffile
			foreach [name value] to [] config [
				if get bind name 'local [continue]
				set bind name 'local :value
			]
		][
			prints['msg] "error reading the config file: (msg)"
		]
	]

	;-- list possible audio paths
	afiles: system/words/exclude
		glob/limit/from/only/omit 2 path imasks xmasks
		reduce [vfile]

	foreach f afiles [prints['f] "possible audio match: (f)"]
	if empty? afiles [
		print "no external audio track found..."
		play player path vfile none
	]

	;-- offer a choice if applicable
	either single? afiles [
		afile: afiles/1
	][
		qfont: make font! [name: query-font-name size: query-font-size]
		actor: func [face event] [
			if find [#"^M" #" " #[none]] event/key [		;-- none for dbl-click
				if afile: pick afiles last-index: face/selected [unview]
			]
			if #"^[" = event/key [quit]				;-- aborted
		]
		view compose [
			title "Choose the audio track"
			tl: text-list  (query-size)  data afiles  font qfont  focus  select (last-index)
			on-key :actor on-dbl-click :actor
		]
	]

	if afile [
		if config/last-index: last-index [								;-- remember the selection
			save conffile to [] config
		]
		print['afile] "chosen audio track: (afile)"
		play player path vfile afile
	]
]

cli/process-into a+v

