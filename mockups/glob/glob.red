Red [title: "glob func" author: @hiiamboris version: 0.3.1 license: 'MIT]

; TODO: an option not to follow symlinks, somehow?
; TODO: allow time! as /limit ? like, abort if takes too long..
; TODO: asynchronous/concurrent listing (esp. of different physical devices)

; BUG: in Windows some masks have special meaning (8.3 filenames legacy)
;      these special cases are not replicated in `glob`:
;  "*.*" is an equivalent of "*" 
;     use "*" instead or better leave out the /only refinement
;  "*." historically meant any name with no extension, but now also matches filenames ending in a period
;     use `/omit "*.?*"` instead of it
;  "name?" matches "name1", "name2" ... but also "name"
;     use ["name" "name?"] set instead

glob: function [
	"Recursively list all files"
	/from "starting from a given path"
		root [file!] "CWD by default"
	/limit "recursion depth (otherwise limited by the maximum path size)"
		sublevels [integer!] "0 = root directory only"
	/only "include only files matching the mask or block of masks"
		imask [string! block!] "* and ? wildcards are supported"
	/omit "exclude files matching the mask or block of masks"
		xmask [string! block!] "* and ? wildcards are supported"
	/files "list only files, not directories"
] bind [
	; ^ tip: by binding the func to a context I can use a set of helper funcs
	; without recreating them on each `glob` invocation
	
	prefx: tail root: either from [clean-path dirize to-red-file root][copy %./]
	
	; prep masks for bulk parsing
	if only [imask: compile imask]
	if omit [xmask: compile xmask]
	
	; lessen the number of conditions to check by defaulting sublevels to 1e9
	; with maximum path length about 2**15 it is guaranteed to work
	unless sublevels [sublevels: 1 << 30]
	
	; requested file exclusion conditions:
	; tip: any [] = none, works even if no condition is provided
	excl-conds: compose [
		(either files [ [dir? f] ][ [] ])					;-- it's a dir but only files are requested?
		(either only  [ [not match imask f] ][ [] ])		;-- doesn't match the provided imask?
		(either omit  [ [match xmask f] ][ [] ])			;-- matches the provided xmask?
	]

	r: copy []
	subdirs: append [] %"" 		;-- dirs to list right now
	nextdirs: [] 					;-- will be filled with the next level dirs
	until [
		foreach d subdirs [		;-- list every subdir of this level
			; path structure, in `glob/from /some/path`:
			; /some/path/some/sub-path/files
			; ^=root.....^=prefx
			; `prefx` gets replaced by `d` every time, which is also relative to `root`:
			append clear prefx d
			unless error? fs: try [read root] [		;-- catch I/O (access denied?) errors, ignore silently
				foreach f fs [
					; `f` is only the last path segment
					; but excl-conds should be tested before attaching the prefix to it:
					if dir? f [append nextdirs f]
					unless any excl-conds [append r f]
					; now is able to attach...
					insert f prefx
				]
			]
		]
		; swap the 2 directory sets, also clearing the used one:
		subdirs: also nextdirs  nextdirs: clear subdirs

		any [
			0 > sublevels: sublevels - 1 		;-- exit upon reaching the limit
			0 = length? subdirs					;-- exit when nothing more to list
		]
	]
	clear subdirs		;-- cleanup
	r
	
] context [		;-- helper funcs container

	; test if file matches a mask (any of)
	match: func [mask [block!] file /local end] [
		; shouldn't try to match against the trailing slash:
		{end: skip  tail file  pick [-1 0] dir? file
		forall mask [if parse/part file mask/1 end [return yes]]
		no}
		; (parse/part is buggy, have to modify the file)
		end: either dir? file [take/last file][""]
		; do [...] is for the buggy compiler only
		also do [forall mask [if parse file mask/1 [break/return yes] no]]
			append file end
	]

	; compile single/multiple masks
	compile: func [mask [string! block!]] [
		either string? mask [reduce [compile1 mask]] [
			also mask: copy/deep mask
			forall mask [mask/1: compile1 mask/1]
		]
	]

	; compiles a wildcard-based mask into a parse dialect block
	compile1: func [mask [string!] /local rule] [
		parse mask rule: [ collect [any [
			keep some non-wild
		|	#"?" keep ('skip)
		|	#"*" keep ('thru) [
				; "*" is a backtracking wildcard
				; to support it we have to wrap the whole next expr in a `thru [...]`
				mask: keep (parse mask rule) thru end
			]
		] end keep ('end)] ]
	]
	non-wild: charset [not "*?"]
]

