Red [
	title:   "simple logger"
	author:  @hiiamboris
	license: 'BSD-3
]

log-echo?: yes		;-- echo to console?

message-log: make block! 500

log: function [lvl [integer!] "0 = critical, 1 = warning, 2 = info, 3 = trace" msg [string!]] [
	verbosity: 3
	if lvl <= verbosity [
		append message-log append copy msg lf
		if log-echo? [print msg]
	]
]

log-artefact: log-artifact: function [art [object!]] [
	append message-log art
]

panic:  log-crit:  func [msg [string!]] [log 0 rejoin ["CRITICAL: " msg]]
warn:   log-warn:  func [msg [string!]] [log 1 rejoin ["WARNING: " msg]]
inform: log-info:  func [msg [string!]] [log 2 msg]
		log-trace: func [msg [string!]] [log 3 msg]

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
			tl: text-list 200x450 data artstrings on-dbl-click [
				if art: pick arts event/picked [explore-artifact art]
			]
			button "OK" focus [unview/only event/window]
		] [text: "(Reversed) error log"]
	]
	;; @@ TODO: browse artifacts
]
