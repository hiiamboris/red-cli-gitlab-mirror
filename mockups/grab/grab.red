Red [
	Title:   "CLI Screen Grabber Demo"
	Author:   @hiiamboris
	License: 'BSD-3
	TODO: {
		- user clicks on a window, we capture it only (determining other window's coordinates is not portable yet)
		- user selects an area, we capture that area (needs main window transparency support or hooks)
		- detect IO redirection and output filename so it can be used in further batch processing (e.g. to upload it)
	}
	Needs:   'View
	Config:  [config-name: 'MSDOS  sub-system: 'console]
]

#include %console-on-demand.red
#include %../../cli.red

grab: function [
	"Screen grabber demo"
	/offset ofs		[pair!] "Left top corner (default: 0x0)"
	/size sz		[pair!] "Region to capture (default: screen size - offset)"
	/into dir		[file!] "Save image in a directory path (default: current directory)"
	/clip					"Copy image into clipboard as well"
][
	do [
		shot: to-image system/view/screens/1

		ofs: any [ofs 0x0]
		sz:  any [sz shot/size - ofs]
		dir: any [dir what-dir]

		shot: draw sz compose [image shot crop (ofs) (sz)]

		dt: now/precise
		foreach x [month day hour minute second] [set x next form 100 + dt/:x]
		clear skip remove skip second 2 3
		name: rejoin [dirize dir %screenshot- dt/year month day '- hour minute second %.png]

		save/as name shot 'png
		; maybe-print to-local-file name
		if clip [write-clipboard shot]
	]
]

wrap [cli/process-into grab]
