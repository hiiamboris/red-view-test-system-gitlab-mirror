Red [
	title:   "simple logger"
	author:  @hiiamboris
	license: 'BSD-3
]

log-echo?: yes		;-- echo to console?

message-log: make block! 500

current-key: function [/push newkey [string! none!] /back] [
	stk: []
	case [
		push [append stk newkey]
		back [take/last stk]
	]
	any [last stk "GLOBAL"]
]


log: function [
	lvl [integer!] "0 = fatal, 1 = error, 2 = warning, 3 = info, 4 = trace"
	msg [string!]
][
	msg: rejoin [form current-key ": " msg]
	verbosity: 4
	if lvl <= verbosity [
		append message-log append line: copy msg #"^/"
		write/append %log.txt line
		if log-echo? [print msg]
	]
]

log-artefact: log-artifact: func [art [object!]] [
	append message-log art
]

log-image: func [im [image!]] [log-artifact object [type: 'image image: im key: current-key]]

fatal:  log-fatal: func [msg [string!]] [log 0 rejoin ["*** F A T A L ***: " msg]]
panic:  log-error: func [msg [string!]] [log 1 rejoin ["ERROR: " msg]]
warn:   log-warn:  func [msg [string!]] [log 2 rejoin ["WARNING: " msg]]
inform: log-info:  func [msg [string!]] [log 3 msg]
		log-trace: func [msg [string!]] [log 4 msg]

warn-if:  func [cond [block!] msg [string!]] [if do cond [warn  msg]]
panic-if: func [cond [block!] msg [string!]] [if do cond [panic msg]]

log-review: function [] [	;; report errors if any
	unless empty? message-log [		;@@ TODO: when area becomes programmatically scrollable, get rid of reverse
		msgs: keep-type message-log string!
		arts: keep-type message-log object!
		artstrings: map-each [x] arts [rejoin [attempt [x/key] ": " replace/all form/part x 50 #"^/" #" "]]
		set 'message-log tail message-log
		view/options [
			area font-name "Lucida Console" wrap 500x500 with [text: form reverse msgs]
			below
			text "Artifacts:"
			tl: text-list 300x450 data artstrings on-dbl-click [
				if art: pick arts event/picked [explore-artifact art]
			]
			button "OK" focus [unview/only event/window]
		] [text: "(Reversed) error log"]
	]
	;; @@ TODO: browse artifacts
]
