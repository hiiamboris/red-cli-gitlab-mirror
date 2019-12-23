sing: function [input][
    input: copy input
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
;sing [99 bottles of beer]
;sing [33 carafes of wine]
;sing [13 flagons of ale]
;sing [17 vials of blood]    ; for vampires
