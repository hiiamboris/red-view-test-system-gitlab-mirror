Red [
	title:   "Perspective - a Red view test system UI"
	author:  @hiiamboris
	license: 'BSD-3
]

;@@ TODO: config-file with last known size/offset; reduced if maximized

#include %assert.red				;@@ stupid `do` junk!
#include %composite.red				;@@ stupid `do` junk!

do/expand load %testing.red
assert [what-dir = working-dir]		;@@ pathetic #include junk!


context [												;-- hide everything in a context from accidental modification

	rea: make deep-reactor! [
		auto-testing?: no
		scheduled-tests: []
		comparison-dir: what-dir
	]

	adapt-tile-size: function ["Reposition tiles to fit the window"][
		ips: do with issues-panel [
			size: main-window/size - offset - (offset/x * 1x1)
		]
		tile-space: max 1 ips/x * ips/y / n-tiles: length? issues
		size: tile-space ** 0.5 * 1x1					;-- adjust tile size until all tiles are in
		while [all [size/x > 1  n-tiles > space? ips / size]] [size: size - 1x1]
		fits: ips / size								;-- number of tiles that fit horizontally & vertically

		cached-fits: [0x0]								;-- caches the previous size
		if fits = cached-fits/1 [exit]					;-- no action needed
		cached-fits/1: fits

		scope [
			system/view/auto-sync?: no						;-- reposition everything
			leaving [system/view/auto-sync?: yes]
			pane: issues-panel/pane
			xyloop xy fits [
				while [all [base: pane/1  base/type <> 'base]] [pane: next pane]		;@@ TODO: rewrite this using `lookup`? ;)
				unless base [break]
				base/size: size - 1x1						;-- 1x1 for spacing
				base/offset: xy - 1x1 * size
				pane: next pane
			]
		]		

		if issues-panel/state [show issues-panel]		;-- renew the visible state
	]

	anything-to-test?: function [] [
		foreach [key issue] issues [if issue/status = 'ready [return yes]]	;@@ TODO: rewrite using `locate`
		no
	]

	click-test-all-handler: func [fa ev] [
		hold-horses [										;-- don't let it reset auto-testing before we schedule some tests
			if all [
				rea/auto-testing?: not rea/auto-testing?	;-- tests are about to continue?
				empty? rea/scheduled-tests					;-- starting, not resuming?
			][
				unless anything-to-test? [					;-- reset issues status so they can be re-tested
					foreach [key issue] issues [
						if issue/status = 'tested [issue/status: 'ready]
					]
				]
				append rea/scheduled-tests keys-of issues
			]
		]
	]
	load-cmp-handler: func [fa ev /local dir] [
		if dir: request-dir/dir/title rea/comparison-dir "Select a logs directory to compare to" [
			load-comparison dir
		]
	]
	load-run-handler: func [fa ev /local dir] [
		if dir: request-dir/dir/title what-dir "Select a directory to load from & log results to" [
			load-test-run dir
		]
	]
	load-prv-handler: func [fa ev /local dir] [load-test-run last-run-dir]
	over-tile-handler: func [fa ev /local issue] [
		either ev/away? [
			maybe tooltip/text: ""
		][
			maybe tooltip/text: rejoin [
				select issue: issues/(fa/text) 'title
				"^/double-click to " pick ["compile" "run"] issue/status = 'not-compiled
				"^/right-click to inspect"
			]
			maybe tooltip/offset: face-to-window ev/offset fa
		]
	]
	test-btn-reaction: [
		maybe face/text: case [
			empty? rea/scheduled-tests [
				rea/auto-testing?: no			;-- force `no` when empty
				"Test all"
			]
			rea/auto-testing? ["Stop tests"]
			'else ["Resume"]
		]
	]
	tooltip-reaction: [
		if face/text <> get in face 'extra [
			face/extra: face/text
			face/size: 2000x50						;-- provide some space for size-text; make it big for #4344 bug
			face/size: size-text face
		]
	]

	main-window: layout elastic collect [
		keep compose/deep [
			size (wsize: system/view/screens/1/size / 2x1 - 12x64)
			backdrop #608
			below
			panel #405 #fill-x [
				below
				load-cmp-btn: button 100 "Load reference..." :load-cmp-handler
				load-run-btn: button 100 "Load results..."   :load-run-handler
				load-prv-btn: button 100 "Load previous"     :load-prv-handler
				return

				ref-label: text rate 2 on-time [maybe face/data: to-local-file rea/comparison-dir] (wsize/x - 260) font-size 13 #fill-x
				cwd-label: text rate 2 on-time [maybe face/data: to-local-file what-dir]           (wsize/x - 260) font-size 13 #fill-x
				return

				comp-btn: button 100 "Compile all" [start-compile-all] #fix-x
				test-btn: button 100 "Stop tests" #fix-x :click-test-all-handler
				react test-btn-reaction 
				show-every: check true 100 "Show results?" #fix-x
				rate 0:0:20 on-time [recycle]
			]
		]
		keep [issues-panel: panel #608]
		keep/only map-each [key _] to block! issues [
			compose [
				base #95B black (key) extra 'issue
				react [face/font/color: contrast-with face/color]
				on-dbl-click [proceed-with face] on-up []
				on-alt-up [explore-artifact issues/(face/text)]
				all-over on-over :over-tile-handler
			]
		]
		keep [
			at 0x0 tooltip: box 1x1 left font-color #057 font-size 10 react tooltip-reaction
		]
	]

	run-test: func [key [string!]] [
		apply test-issue [
			title: key
			no-review: not show-every/data
		]
	]

	proceed-with: function [face [object!]] [
		key: face/text
		issue: issues/:key
		#assert [issue]
		code: compose switch issue/status [
			not-compiled [[start-compile (key)]]
			compiling    [none]
			ready tested [[run-test (key)]]
		]
		face/actors/on-up: all [
			code
			func [fa ev] compose [
				fa/actors/on-up: none
				(code)
			]
		]
	]

	tile-font: make font! [size: 20]
	update-tiles: function ["Update each tile's colors & decorations depending on respective issue's state"] [
		unless jobs/alive? main-worker [exit]		;-- happens when exiting, or during the crash

		jobs/read-heavy-reports						;-- update all compiling issues status
		n-done: 0
		scope [
			system/view/auto-sync?: no
			leaving [system/view/auto-sync?: yes]
			foreach base issues-panel/pane [
				unless all ['base = base/type 'issue = base/extra] [continue]
				key: base/text
				issue: issues/:key
				#assert [issue]
				if all [								;-- check & update compilation status
					find [not-compiled compiling] issue/status
					is-compiled? key					;-- may be true even for `not-compiled` issue when detects an exe
				] [issue/status: 'ready]

				status-colors: [not-compiled #95B compiling #B9C ready #FFF]	;-- update tile color
				unless new-color: select status-colors issue/status [
					#assert [issue/status = 'tested]
					#assert [issue/result]
					result-colors: [
						ok      #0F0
						warning #FF0
						error   #F00
						crash   #000
						freeze  #000
					]
					new-color: select result-colors issue/result
					#assert [new-color]
					n-done: n-done + 1					;-- count finished issues
				]
				maybe base/color: hex-to-rgb new-color

				if empty? base/draw [					;-- `draw` skeleton (filled below)
					sc: base/size/x / 80.0
					base/draw: compose/deep [
						scale (sc) (sc) pen off [fill-pen white []] [fill-pen white []]
					]
				]
				
				dots: last last base/draw				;-- draw dots on "compiling" issues
				either issue/status = 'compiling [
					n-dots: (length? dots) / 3
					either n-dots = 3 [
						clear dots
					][	append dots compose [circle (n-dots + 1 * 20x0 + 0x60) 3]
					]
				][	unless empty? dots [clear dots]
				]

				arrows: last base/draw/6				;-- draw arrows on issues with results better or worse than comparison
				#assert [block? arrows]
				imp: get-improvement key
				; c: white - (base/color - 100)						;-- somewhat inverted + brighter
				c: contrast-with base/color
				case [
					'? = imp [										;-- suspicious result
						append clear arrows compose [pen (c) font tile-font text 0x0 "?"]
					]
					imp <> 0 [										;-- definite result
						; if imp < 0 [c: white - base/color - 100]	;-- somewhat inverted + darker
						base/draw/6/2: c
						append clear arrows
							map-each i gen-range abs imp [
								compose/only [
									translate (i - 1 * 0x10)
									(pick [
										[ shape [move 5x13 'line 0x-5 10x-5 10x5  0x5 -10x-5 close] ]
										[ shape [move 5x3  'line 0x5  10x5  10x-5 0x-5 -10x5 close] ]
									] imp > 0)
								]
							]
					]
				]
			];; foreach base issues-panel/pane [
		];; scope [

		show main-window

		;; mark this run as reference if all tests were finished
		if n-done = length? issues [write  %.reference.run ""]
	]

	run-some-test: function ["Run one of the pending tests"] [
		unless rea/auto-testing? [exit]		;-- do not run tests until enabled

		if first lock: [] [exit]			;-- prevent reentry with test-issue -> log-review -> view -> do-events
		change lock yes

		for-each [pos: test] rea/scheduled-tests [
											;@@ TODO: add manual tests also here?
			if find [ready tested] st: issues/:test/status [
				remove at rea/scheduled-tests pos
				if 'ready = st [run-test test]		;-- skip those already tested (manually in console or with dbl-click)
				clear lock
				exit
			]
		]
	]

	;; new artifacts will be output in this directory!
	load-test-run: function [
		"Load results from a directory and use it to log newly run tests"
		path [file!]
	][
		#assert [exists? dirize path]
		change-dir working-dir: dirize path
		files: read dirize path

		clear toolset/compile-tasks
		foreach [key issue] issues [		;-- reset issues to not-tested or not-compiled
			issue/status: 'ready
			all [
				issue/flags/compiled
				not is-compiled? key
				issue/status: 'not-compiled
			]
		]

		suffix: "-artifacts.red"
		foreach file files [				;-- fill status from artifact files
			if parse as string! file [copy key to suffix suffix end] [
				issue: issues/:key
				#assert [issue]				;-- should always be true unless we get rid of some issues definitions
				issue/artifacts: arts: reduce load file
				#assert [parse arts [some object!]]		;-- only objects allowed
				result: none  foreach a arts [if a/type = 'result [result: a/result]]
				if issue/result: result [issue/status: 'tested]
			]
		]

		config/last-working-dir: working-dir
		save-config
	]

	load-comparison: function [
		"Load results to compare to"
		path [file!]
		/extern comparison
	][
		#assert [exists? dirize path]
		scope [
			leaving [change-dir working-dir]
		
			change-dir rea/comparison-dir: clean-path dirize path
			files: read %./

			comparison: clear #()
			suffix: "-artifacts.red"
			foreach file files [
				if parse as string! file [copy key to suffix suffix end] [
					#assert [issues/:key]			;-- should always be true unless we get rid of some issues definitions
					arts: reduce load file
					#assert [parse arts [some object!]]		;-- only objects allowed
					result: none  foreach a arts [if a/type = 'result [result: a/result]]
					comparison/:key: object compose/only [
						result:    quote (result)
						artifacts: (arts)
					]
				]
			]
		]
	]

	get-improvement: function ["Get improvement score of test KEY (-3 to +3 or '? when suspicious)" key [string!]] [
		issue: issues/:key
		#assert [issue]
		unless all [
			value? 'comparison				;-- no comparison loaded?
			cmp: comparison/:key			;-- newly defined issue?
			cmp/result						;-- untested before?
			issue/result					;-- not tested yet?
		] [return 0]

		;; things to compare: result; identity of artifacts (errors count; images)
		if issue/result <> cmp/result [
			rating: [ok 0 warning -1 error -2 crash -3 freeze -3]
			return subtract
				select rating issue/result
				select rating cmp/result
		]
		;@@ TODO: consider closeness to ideal parameters here?

		;; now that results are equal, look for subtle differences
		arts: copy issue/artifacts
		for-each [i: a] arts [if a/type = 'context [remove at arts i  break]]
		if (length? arts) <> length? cmp/artifacts [return '?]
		repeat i length? arts [if arts/:i <> cmp/artifacts/:i [return '?]]
		
		;@@ TODO: on inspection - display the diff so it's clear where improvement is; allow to explore images side by side; allow to highlight areas of difference
		0
	]


	;; automatically compare to the previous reference run
	;; %.reference.run file is created automatically when all tests were finished
	cmp: runs: sort read %../
	foreach dir runs [
		if all [
			find/match dir %run-
			exists? cmp: #composite %"../(dir).reference.run"
		][
			load-comparison #composite %"../(dir)"
			break
		]
	]

	save-config: function [] [
		cfg-file: #composite %"(startup-dir)config.red"
		write cfg-file ";; do not modify! (or deal with the possibility of overwrite)^/^/"
		write/append cfg-file #composite "config: (mold config)"
	]

	;; will be using previous directory for 1-click crash recovery
	if not none? dir: select config 'last-working-dir [
		last-run-dir: dir
	]

	;; save the log directory in the config - for crash recovery
	set 'config make config [last-working-dir: working-dir]
	save-config

	apply view [
		spec: main-window
		flags: options: yes
		flgs: [resize]
		opts: [
			text: "Red view test system UI"
			offset: 0x0
			rate: 3
			actors: object [
				on-time:  func [f e] [update-tiles run-some-test]
				on-close: func [f e] [quit-gracefully]
				on-resizing: on-resize: func [f e] [adapt-tile-size]
			]
		]
		no-wait: system/console/gui?
	]

];; end of all-encompassing context
