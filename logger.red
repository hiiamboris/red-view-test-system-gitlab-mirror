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
		append append message-log msg lf
		if log-echo? [print msg]
	]
]

panic:  log-crit:  func [msg [string!]] [log 0 rejoin ["CRITICAL: " msg]]
warn:   log-warn:  func [msg [string!]] [log 1 rejoin ["WARNING: " msg]]
inform: log-info:  func [msg [string!]] [log 2 msg]
		log-trace: func [msg [string!]] [log 3 msg]

warn-if:  func [cond [block!] msg [string!]] [if do cond [warn  msg]]
panic-if: func [cond [block!] msg [string!]] [if do cond [panic msg]]

log-review: does [
	;; report errors if any
	unless empty? reverse message-log [		;@@ TODO: when area becomes programmatically scrollable, get rid of reverse
		view/options [
			area wrap 500x500 with [text: form message-log]
			return button "OK" focus [unview]
		] [text: "(Reversed) error log"]
	]
]