Red [
	title:   "Red build tool core"
	purpose: "Automate building the console from sources"
	author:  @hiiamboris
	license: 'BSD-3
	; needs:    CLI
]

#include %../../../common/setters.red
#include %../../../common/mapparse.red
#include %../../../common/composite.red
#include %../../../common/new-each.red

retry: function [code [block!]] [
	loop 3 [unless error? r: try code [break]]
	if error? r [print r]
	r
]

ragequit: func [result msgs] [print msgs quit/return result]

require: func [value] [if error? value [ragequit 1 ""]]

only: function [
	"Turn falsy values into empty block (useful for composing Draw code)"
	value [any-type!] "Any truthy value is passed through"
][
	any [:value []]		;-- block is better than unset here because can be used in set-word assignments
]

when: func [
	"If TEST is truthy, return VALUE, otherwise an empty block"
	test   [any-type!]
	:value [any-type!] "Paren is evaluated, block or other value is returned as is"
][
	only if :test [either paren? :value [do value][:value]]
]

red-build: function compose [
	"Build CLI or GUI Red console from sources"
	console "CLI or GUI"
	/target  tname        (`"Specify compilation target (\default: (system/platform))"`)
	/debug                  "Compile in debug mode"
	/sources spath [file!]  "Path to Red sources"
	/output  opath [file!]  "Path where to save compiled binary"
	/branch  bname          "Specify alternate branch (otherwise builds currently active one)"
	/module  mname [block!] "Include given module(s)"
	/shortcut scut [file!]  "Also create a shortcut for everyday usage"
	/t "alias /target"
	/d "alias /debug"
	/s "alias /sources"
	/b "alias /branch"
	/m "alias /module"
	/o "alias /output"
][
	unless find ["cli" "gui"] console [ragequit 1 "CLI or GUI argument expected"]
	uppercase console
	target: any [tname form system/platform]
	;; CLI console won't work without terminal access, so auto correct this:
	if all [target = "windows" console = "cli"] [target: "MSDOS"]
	
	default opath: %.
	default spath: %.
	unless parse gitpath: spath [thru ".git" opt "/" end] [gitpath: gitpath/.git]
	gitcmd: `"git --git-dir (to-local-file gitpath)"`
	
	;; choose branch
	either branch [
		result: call/wait/error `"(gitcmd) checkout (bname)"` msgs: clear {}
		unless zero? result [
			print `"Failed to checkout branch (bname)!"`
			ragequit result msgs
		]
		branch: bname
	][
		result: call/wait/output/error `"(gitcmd) rev-parse --abbrev-ref HEAD"` branch: clear {} msgs: clear {}
		unless zero? result [
			print `"Cannot get branch info!"`
			ragequit result msgs
		]
		trim/lines branch
	]
	
	;; obtain commit info
	hexd: charset "0123456789abcdefABCDEF"
	call/wait/output `"(gitcmd) log -1 --format=%h/%cs"` commit: clear {}
	trim/lines commit
	if find commit "%cs" [
		ragequit 1 "Your git version is too ancient! Please update it"
	]
	unless parse commit [copy hash 7 hexd any hexd "/" copy date to end] [
		ragequit 1 `"Cannot get commit info! Got (commit)"`
	]
	
	;; add modules to the console source
	csrc: either cli?: "cli" = console [%console.red][%gui-console.red]
	cpath: spath/environment/console/:console/:csrc
	unless empty? mname [
		source: load cpath
		insert source/2/needs map-each m mname [to word! m]
		cpath: spath/environment/console/:console/console-being-built.red
		save cpath source
	]
	
	;; build the console
	suffix?:  either find ["Windows" "MSDOS"] target [".exe"][""]
	d?:       when debug "d"
	-d?:      when debug "-d"
	-debug?:  when debug "-debug"
	modules?: when not empty? mname (rejoin map-each m mname [`"+(lowercase m)"`])
	basename: either cli? ["red"]["redgui"]
	exename:  `"(basename)(modules?)(-debug?)-(branch)-(date)-(hash)(suffix?)"`
	exepath:  opath/:exename
	; if scut [scut: `"(basename)(d?)(suffix?)"`  scut: opath/:scut]
	rename?:  when scut (`"write/binary (mold scut) read/binary (mold exepath)"`)
	redr:     spath/red.r
	command: `{rebol --do "do/args (mold redr) {-r (-d?) -t (target) -o (to-local-file exepath) (to-local-file cpath)} (rename?) quit"}`
	print ["Executing:" command]
	call/shell/console command
]
