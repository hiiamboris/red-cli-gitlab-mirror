Red []

#include %../cli.red

curl-mockup: func [
	url [url!]
	/socks5 "SOCKS5 proxy on given host + port"
		HOST+PORT "as HOST[:PORT]"
	/telnet-option "Set telnet option"
		OPT=VAL [block!]
	/t "alias /telnet-option"
][
	print ["url=" url]
	if socks5 [print ["using host=" host+port]]
	if telnet-option [print ["telnet opts=" opt=val]]
]

probe cli/process-into curl-mockup
; print help-for curl-mockup

