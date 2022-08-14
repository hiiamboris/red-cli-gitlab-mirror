Red [
	title:   "Red build tool"
	purpose: "Automate building the console from sources"
	author:  @hiiamboris
	license: 'BSD-3
	; needs:    CLI
]

#include %../../cli.red
#include %redbuildcore.red
system/script/header: []
cli/process-into red-build
