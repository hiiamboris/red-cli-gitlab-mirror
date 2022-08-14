Red [
	title:   "Red download tool"
	purpose: "Automate fetching Red binaries from the web"
	author:  @hiiamboris
	license: 'BSD-3
	; needs:    CLI
]

#include %../../cli.red
#include %../../../common/setters.red
#include %../../../common/mapparse.red
#include %../../../common/composite.red
system/script/header: []

retry: function [code [block!]] [
	loop 3 [unless error? r: try code [break]]
	if error? r [print r]
	r
]

require: func [value] [if error? value [quit/return 1]]

reddl: function [
	"Automate Red downloads"
	/gui           guiname       "Download GUI console and make a shortcut (e.g. redgui)"
	/cli           cliname       "Download CLI console and make a shortcut (e.g. red)"
	/comp          compname      "Download compiler and make a shortcut (e.g. redc)"
	/platform      pname         "Specify the platform (Windows, Linux, macOS, Raspberry Pi)"
	/archive-path  apath [file!] "Specify directory where to save the files"
	/binary-path   bpath [file!] "Specify directory where to save the shortcuts"
	/p "alias /platform"
	/a "alias /archive-path"
	/b "alias /binary-path"
][
	unless any [gui cli comp] [
		print "No download was specified. Defaulting to GUI console."
		gui: on
	]
	home: https://static.red-lang.org/
	require page: retry [read home/download.html?reload=true]
	page: find page <table class="download">
	mapparse ["<" not "a href" thru ">"] page [""]
	default pname: form system/platform
	unless parse page [thru pname thru "[History]" page: to end] [
		print `"Unable to detect binaries for platform '(pname)'"`
		quit/return 1
	]
	clear find page "[History]"
	default guiname:  "redgui"
	default cliname:  "red"
	default compname: "redc"
	links: reduce [
		'gui  "GUI Red"       guiname 
		'cli  "CLI Red"       cliname 
		'comp "Red Toolchain" compname
	]
	
	default apath: %.
	default bpath: %.
	foreach [type flag name] links [
		unless get type [continue]
		unless parse page [thru flag thru {<a href="} copy link to {">} to end] [
			print `"Unable to find URL for '(flag)' on the page."`
			continue
		]
		link: home/:link
		file: to file! find/last/tail link "/"
		file: apath/:file
		either exists? file [
			bin: read/binary file
			print `"Skipped existing (file)"`
		][
			bin: retry [read/binary link]
			if error? bin [continue]
			write/binary file bin
			print `"Saved (link) as (file)"`
		]
		if all [suffix? file  not suffix? name] [append name suffix? file]
		name: bpath/:name
		write/binary name bin
		print `"Saved (file) as (name)"`
	]
]

cli/process-into reddl
