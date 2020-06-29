Red [
	title:   "simple logger"
	author:  @hiiamboris
	license: 'BSD-3
]

{
	kinds of logging here:
	- global text log is meant to be readable by the user and only for debugging the system, understanding the sequence and outcome of events
	- artifacts produced by each issue are saved to a corresponding file - to be compared between test runs
	;@@ TODO: log extract also should be saved as artefact, for it may contain errors/warnings which we wanna see gone in comparison
}

include %common/setters.red

once logger-ctx: context [

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

	log-mark: does [tail message-log]
	log-since: func [mark [block!]] [copy mark]

	log: function [
		lvl [integer!] "0 = fatal, 1 = error, 2 = warning, 3 = info, 4 = trace"
		msg [string!]
	][
		msg: rejoin [form current-key ": " msg]
		verbosity: 4
		if lvl <= verbosity [
			append message-log append line: copy msg #"^/"
			write/append #composite %"(working-dir)log.txt" line
			if log-echo? [print msg]
		]
	]

	log-artefact: log-artifact: function [art [object!]] [
		append message-log art
		attempt [append issues/(art/key)/artifacts art]
		;; can't save it here since values are gonna be updated after it's logged!
		; write/append/lines #composite %"(key)-artifacts.red" mold/all/flat art
	]

	clean-artefacts: clean-artifacts: function [key [string!]] [
		if exists? file: #composite %"(key)-artifacts.red" [write file {}]
	]

	compress-images: function ["Compress images in OBJ, in place" obj [object!]] [
		foreach w words-of obj [
			case [
				image? i: select obj w [
					i: save/as copy #{} i 'png
					obj/:w: does compose [load/as (i) 'png]
				]
				object? :i [compress-images i]
			]
		]
		obj
	]

	save-artefacts: save-artifacts: function [key [string!]] [
		clean-artifacts key		;@@ is there a point in holding results from multiple runs?
		objs: issues/:key/artifacts

		foreach o objs [
			#assert [o/key = key]
			if o/type = 'context [continue]					;-- may contain huge images, and they are duplicates anyway - unpractical to save
			either all [o/type = 'image  select o 'file] [	;-- do not mold the whole image if it's saved; leave the code to load it instead
				#assert [file? o/file]
				o: copy o
				o/image: does compose/deep [
					load/as rejoin [
						;; save paths relative to the startup dir so they are not sensitive to working directory changes!
						startup-dir (head insert get-relative-path o/file startup-dir #"/")
					] 'png
				]
			][	o: compress-images copy/deep o
			]
			;; images are still too huge and saving them slows down testing by a lot
			;; so we have to compress each one
			write/append/lines #composite %"(key)-artifacts.red" mold/all/flat o
		]
	]

	log-image: func [im [image!] /name fname [file! string!]] [
		fname: any [fname gen-name-for-capture]
		save-capture/as im fname
		log-artifact object [type: 'image image: im file: fname key: current-key]
	]

	fatal:  log-fatal: func [msg [string!]] [log 0 rejoin ["*** F A T A L ***: " msg]]
	panic:  log-error: func [msg [string!]] [log 1 rejoin ["ERROR: " msg]]
	warn:   log-warn:  func [msg [string!]] [log 2 rejoin ["WARNING: " msg]]
	inform: log-info:  func [msg [string!]] [log 3 msg]
			log-trace: func [msg [string!]] [log 4 msg]

	warn-if:  func [cond [block!] msg [string!]] [if do cond [warn  msg]]
	panic-if: func [cond [block!] msg [string!]] [if do cond [panic msg]]

	log-review: function [/key title [string!]] [	;-- report errors if any
		unless empty? message-log [
			msgs: keep-type message-log string!
			arts: keep-type message-log object!
			artstrings: map-each [x] arts [rejoin [select x 'key ": " replace/all form/part x 50 #"^/" #" "]]
			set 'message-log tail message-log
			view/flags/options elastic compose [
				space 2x2 below
				text #scale (any [attempt [issues/:title/title] title current-key])
				area #scale font-name (system/view/fonts/fixed) wrap 500x475 with [text: form msgs]
				return
				text "Artifacts:" #fix
				tl: text-list 300x450 #fill-y #scale-x data artstrings on-dbl-click [
					all [
						event/picked		;-- `none` when misses the line
						art: pick arts event/picked
						explore-artifact art
					]
				]
				button #fix "OK" focus [unview/only event/window]
			] 'resize [text: #composite "Error log (any [title {}])"]
		]
		set 'message-log tail message-log
	]

	import self
]