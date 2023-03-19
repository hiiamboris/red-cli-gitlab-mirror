Red [
	Title:   "CLI Screen Grabber Demo"
	Author:   @hiiamboris
	License: 'BSD-3
	TODO: {
		- user clicks on a window, we capture it only (determining other window's coordinates is not portable yet)
		- detect IO redirection and output filename so it can be used in further batch processing (e.g. to upload it)
	}
	Needs:   'View
	Config:  [config-name: 'MSDOS  sub-system: 'console]
]

#include %console-on-demand.red
#include %../../cli.red

dpi: (any [system/view/metrics/dpi 96]) / 96

contrast?: func [c1 [tuple!] c2 [tuple!]] [
	make integer! not all [
		50 >= absolute c1/1 - c2/1
		50 >= absolute c1/2 - c2/2
		50 >= absolute c1/3 - c2/3
	]
]

snap: function [img [image!] xy [pair!]] [
	w:  32
	xy: xy * dpi
	corners: collect [
		repeat y w [
			repeat x w [
				xy': xy - (w / 2) + as-pair x y
				c00: pick img xy'
				c10: pick img xy' + 1x0
				c01: pick img xy' + 0x1
				c11: pick img xy' + 1x1
				unless all [c00 c10 c01 c11] [continue]
				el: contrast? c00 c01
				er: contrast? c10 c11
				et: contrast? c00 c10
				eb: contrast? c01 c11
				edges: reduce [el et er eb]
				corner?: find/only [[1 1 0 0] [0 1 1 0] [0 0 1 1] [1 0 0 1]] edges
				if corner? [
					keep reduce [xy' distance? xy xy']
				]
			]
		]
	]
	if empty? corners [return xy]
	sort/skip/compare corners 2 2
	corners/1
]

crop: function [img [image!] xy1 [pair!] xy2 [pair!]] [
	xy1: also min xy1 xy2  xy2: max xy1 xy2
	xy2: max xy2 xy1 + 1
	draw xy2 - xy1 compose [image img crop (xy1) (xy2 - xy1)]
]

grab: function [
	"Screen grabber demo"
	/offset ofs	[pair!] "Left top corner (default: 0x0)"
	/size sz	[pair!] "Region to capture (default: screen size - offset)"
	/into dir	[file!] "Save image in a directory path (default: current directory)"
	/select				"Interactively select an area (overrides offset and size)"
	/clip				"Copy filename into clipboard as well"
][
	do [
		shot: to-image screen: system/view/screens/1

		ofs: any [ofs 0x0]
		sz:  any [sz shot/size - ofs]
		dir: any [dir what-dir]

		shot: draw sz compose [image shot crop (ofs) (sz)]
		if select [
			redraw: does [if xy2 [image/draw: compose [pen cyan fill-pen off box (xy1 / dpi) (xy2 / dpi + 1)]]]
			ssize: screen/size
			view/tight/options/flags [
				image: image ssize shot all-over focus
				on-key  [if event/key = #"^[" [quit/return 1]]	;-- aborted
				on-down [xy1: xy2: snap shot event/offset redraw]
				on-up   [shot: crop shot xy1 xy2  unview]
				on-over [if xy1 [xy2: snap shot event/offset redraw]]
			] [size: ssize] 'no-border
		]

		dt: now/precise
		foreach x [month day hour minute second] [set x next form 100 + dt/:x]
		clear skip remove skip second 2 3
		name: rejoin [dirize dir %screenshot- dt/year month day '- hour minute second %.png]

		save/as name shot 'png
		; maybe-print to-local-file name
		if clip [write-clipboard as {} name]
	]
]

wrap [cli/process-into grab]
