Red [
	title:   "Red build tool GUI"
	purpose: "Building the console from sources for newbies"
	author:  @hiiamboris
	license: 'BSD-3
	needs:    View	; CLI
]

#include %redbuildcore.red
#include %../../../common/new-apply.red
system/script/header: []
targets: [
	"Windows"
	"WindowsXP"
	"MSDOS"
	"Linux"
	"Linux-musl"
	"Linux-ARM"
	"RPi"
	"Darwin"
	"macOS"
	"Syllable"
	"FreeBSD"
	"NetBSD"
	"Android"
	"Android-x86"
]

ragequit: func [result msgs] [do make error! msgs]
print: func [value [any-type!]] [
	logs/text: form reduce :value
]
display: does [
	unless any [empty? logs/text logs/size = 320x100] [
		logs/size: 320x100
		logs/parent/size: logs/parent/size + 0x100
		logs/parent/parent/size: logs/parent/parent/size + 0x100
	]
]

save-conf: does [
	save %redbuildgui.conf to block! object [
		console-type: con-type/text
		target-type:  tgt-type/text
		branch-name:  branch/text
		modules-list: modules/text
		debug-flag:   debug?/data
		rebol-path:   reb-path/text
		source-path:  src-path/text
		output-path:  out-path/text
	]
]

load-conf: function [] [
	path: any [system/script/path %.]
	if exists? conf: path/redbuildgui.conf [
		conf: construct load conf
		con-type/text:	conf/console-type 
		tgt-type/text:	conf/target-type  
		branch/text:	conf/branch-name  
		modules/text:	conf/modules-list 
		debug?/data:	conf/debug-flag   
		reb-path/text:	conf/rebol-path   
		src-path/text:	conf/source-path  
		out-path/text:	conf/output-path 
	]
]

view compose/deep [
	title "RedBuildGUI"
	panel 3 [
		text "Console type:"
		con-type: drop-list 200 data ["CLI" "GUI"] select 2 with [text: data/2]	;@@ #5008
		text 10
		
		text "Target platform:"
		tgt-type: drop-down 200 data targets select (i: any [index? find targets form system/platform 1]) with [text: data/:i]	;@@ #5008
		text 10
		
		text "Git branch:"
		branch: drop-down 200 data ["master"] select 1 with [text: data/1]	;@@ #5008
		text 10
		
		text "Modules to add:"
		modules: field 200 ""
		text 10
		
		text 10
		debug?: check "Debug mode?"
		text 10
		
		
		text "Rebol full path:"
		reb-path: field 200 "rebol"
		button 20 "..." [
			if new: request-file/title/file "Locate rebol executable" "rebol*" [
				reb-path/text: to-local-file new
			]
		]
		
		text "Sources path:"
		src-path: field 200 ""
		button 20 "..." [
			if new: request-dir/title/keep "Locate Red sources" [
				src-path/text: to-local-file new
			]
		]
		
		text "Output path:"
		out-path: field 200 ""
		button 20 "..." [
			if new: request-dir/title/keep "Where to place the binary" [
				out-path/text: to-local-file new
			]
		]
		
		text 10
		button "BUILD" focus [
			error: try [
				apply red-build [
					console: pick con-type/data con-type/selected
					target:  yes tname: tgt-type/text
					debug:   debug?/data
					branch:  yes bname: branch/text
					sources: yes spath: clean-path to-red-file src-path/text
					output:  yes opath: clean-path to-red-file out-path/text
					module:  yes mname: when not empty? modules/text ([(split trim/lines modules/text " ")])
				]
			]
			if error? error [print error]
		]
		text 10
		
		logs: text 0x0 react [display face/text]
	] on-created [load-conf]
]
save-conf