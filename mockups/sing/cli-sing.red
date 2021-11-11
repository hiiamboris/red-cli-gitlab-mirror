Red [title: "Drinking song" author: [@greggirwin @hiiamboris]]

#include %../../cli.red

sing: function [
	"Sing drinking song"
	input {e.g. "99 bottles of beer" or "17 vials of blood"}
][
    input: copy input: transcode input
	n: orig-num: first input
	sing-verse: func [n][
		print [
			n =phrase "on the wall," n =phrase ".^/"
			"Take one down and pass it around," 
			either n > 1 [n - 1]["no more"] =phrase "on the wall.^/"
		]
	]
	sing-last-verse: does [
		print [
			"No more" =phrase "on the wall, no more" =phrase ".^/"
			"Go to the store and buy some more," orig-num =phrase "on the wall."
		]
	]
	
	phrase: [copy =phrase to end]
	rule: [
		set n quote 0 phrase (sing-last-verse)
		| change set n integer! (n - 1) phrase (sing-verse n)
	]
	while [n > 0][parse input rule]
]
;do-sing [99 bottles of beer]
;do-sing [33 carafes of wine]
;do-sing [13 flagons of ale]
;do-sing [17 vials of blood]    ; for vampires

cli/process-into sing
