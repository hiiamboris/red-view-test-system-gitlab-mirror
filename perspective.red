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
		scores-map: make hash! map-each/eval [k v] body-of issues [[k 0.0]]
		score: is [sum extract next scores-map 2]
	]

	adapt-tile-size: function ["Reposition tiles to fit the window"][
		ips: do with issues-panel [
			size: main-window/size - offset - (offset/x * 1x1)
		]
		tile-space: max 1 ips/x * ips/y / n-tiles: length? issues
		size: tile-space ** 0.5 * 1x1					;-- adjust tile size until all tiles are in
		while [all [size/x > 1  n-tiles > space? ips / size]] [size: size - 1x1]
		fits: ips / size								;-- number of tiles that fit horizontally & vertically
		cache: [0x0 0x0]								;-- caches the previous grid & tile size
		if cache = new: reduce [fits size] [exit]		;-- no action needed
		change cache new

		scope [
			maybe system/view/auto-sync?: no						;-- reposition everything
			leaving [maybe system/view/auto-sync?: yes]
			pane: issues-panel/pane
			xyloop xy fits [
				while [all [base: pane/1  base/type <> 'base]] [pane: next pane]		;@@ TODO: rewrite this using `lookup`? ;)
				unless base [break]
				maybe base/size: size - 1x1						;-- 1x1 for spacing
				maybe base/offset: xy - 1x1 * size
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
		dir: any [select config 'last-comparison-dir  %./]
		if dir: request-dir/dir/title dir "Select a logs directory to compare to" [
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

	var: var2: none
	main-window: layout elastic collect [
		var: get-build-info
		var2: copy/part form any [var/commit ""] 8
		keep compose/deep [
			size (wsize: system/view/screens/1/size / 2x1 - 12x64)
			backdrop #608
			below
			panel #608 #fill-x [
				origin 0x0
				text (wsize/x - 160) font-color #CB4 font-size 11
					(#composite "Worker build date: (var/date) commit: (var2)^/OS: (system/platform)") #fill-x
					on-dbl-click [write-clipboard (var2)]		;@@ not gonna work on Windows, which already copies the whole text
				panel #608 #fix-x [
					origin 0x0
					text font-color #FE6 60 font-size 16 "Score:"
					text font-color #FE6 60 font-size 16 "0" rate 2 on-time [maybe face/data: rea/score] return
				]
			]
			panel #405 #fill-x [
				below
				load-cmp-btn: button 100 "Load reference..." :load-cmp-handler
				load-run-btn: button 100 "Load results..."   :load-run-handler
				load-prv-btn: button 100 "Load previous"     :load-prv-handler
				return

				ref-label: text font-color #BA4 (wsize/x - 260) font-size 12 #fill-x
					rate 2 on-time [maybe face/data: to-local-file select config 'last-comparison-dir]
				cwd-label: text font-color #BA4 (wsize/x - 260) font-size 12 #fill-x
					rate 2 on-time [maybe face/data: to-local-file what-dir]
				return

				comp-btn: button 100 "Compile all" [start-compile-all] #fix-x
				test-btn: button 100 "Stop tests" #fix-x :click-test-all-handler
				react test-btn-reaction 
				show-every: check true 100 "Show results?" #fix-x
				rate 0:0:5 on-time [recycle]
			]
		]
		keep [issues-panel: panel #608]
		keep/only map-each [key _] to block! issues [
			compose [
				base #95B black (key) extra 'issue
				react [face/font/color: contrast-with face/color]
				on-dbl-click [proceed-with face] on-up []
				on-alt-up [visual-comparison face/text]
				; on-alt-up [explore-artifact issues/(face/text)]
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

	j: none
	arrow-shapes: map-each/eval imp [-3 -2 -1 0 1 2 3] [[
		imp
		map-each i gen-range abs imp [
			compose/only [
				translate (i - 1 * 0x10)
				(pick [
					[ shape [move 5x13 'line 0x-5 10x-5 10x5  0x5 -10x-5 close] ]
					[ shape [move 5x3  'line 0x5  10x5  10x-5 0x-5 -10x5 close] ]
				] imp > 0)
			]
		]
	]]

	tile-font: make font! [size: 20]
	update-tiles: function ["Update each tile's colors & decorations depending on respective issue's state"] [
		unless jobs/alive? main-worker [exit]		;-- happens when exiting, or during the crash

		jobs/read-heavy-reports						;-- update all compiling issues status
		n-done: 0
		scope [
			maybe system/view/auto-sync?: no
			leaving [maybe system/view/auto-sync?: yes]
			foreach base issues-panel/pane [
				unless all ['base = base/type 'issue = base/extra] [continue]
				key: base/text
				issue: issues/:key
				#assert [issue]

				rea/scores-map/:key: (1.0 * sum issue/score) / max 1 length? issue/score

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
				arrows': case [
					'? = imp [										;-- suspicious result
						compose [pen (c) font tile-font text 0x0 "?"]
					]
					imp <> 0 [										;-- definite result
						; if imp < 0 [c: white - base/color - 100]	;-- somewhat inverted + darker
						maybe base/draw/6/2: c
						select/skip arrow-shapes imp 2
					]
					'else [ [] ]
				]
				unless arrows = arrows' [append clear arrows arrows']
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
		/extern config
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
			clear issue/score				;-- not tested by default
		]

		suffix: "-artifacts.red"
		foreach file files [				;-- fill status from artifact files
			if parse as string! file [copy key to suffix suffix end] [
				issue: issues/:key
				#assert [issue]				;-- should always be true unless we get rid of some issues definitions
				issue/artifacts: arts: reduce load file
				#assert [parse arts [some object!]]		;-- only objects allowed
				result: none 
				foreach a arts [				;@@ TODO: use `locate`
					if a/type = 'result [
						result: a/result		;-- load status
						attempt [issue/score: a/score]		;-- load scores (if present)
					]
				]
				if issue/result: result [issue/status: 'tested]
			]
		]

		config: make config [last-working-dir: working-dir]
		save-config
	]

	load-comparison: function [
		"Load results to compare to"
		path [file!]
		/extern comparison config
	][
		#assert [exists? dirize path]
		scope [
			leaving [change-dir working-dir]
		
			change-dir cmp-dir: clean-path dirize path
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

			config: make config [last-comparison-dir: cmp-dir]
			save-config
		]
	]


	prep-for-comparison: function [
		"Expands any saved images in object O into a new object (returned)"
		o [object! none!]
	] compose [
		cache: (make hash! [])
		if o [
			if r: select/same cache o [return r]
			r: copy o
			foreach w words-of r [
				if paren?  :r/:w [r/:w: do r/:w]
				if object? :r/:w [attempt [r/:w: prep-for-comparison r/:w]]		;-- catch stack overflows if recurses
			]
			if 1000 < length? cache [clear cache]		;-- reset in case it grows too much
			repend cache [o r]
			r
		]
	]

	;; sets will be modified!!
	compare-artifact-sets: function [set1 [block!] set2 [block!] /local a] [
		;; TODO: this would really benefit from levenshtein's; for now dumb & linear
		r: copy []
		remove-each a set1 cond: [find [context build] a/type]		;-- ignore `context` which we don't save at all; and `build` which always differs
		remove-each a set2 cond
		key: attempt [select any [pick set1 1 pick set2 1] 'key]
		repeat i max length? set1 length? set2 [		;@@ make this map-each over zip of sets?
			if art1: prep-for-comparison pick set1 i [set1/:i: art1]
			if art2: prep-for-comparison pick set2 i [set2/:i: art2]
			append/only r cmp: compare-objects art1 art2
			all [			;-- enforce equality of all keys - anything that's different should be highlighted
				any [key <> select art1 'key  key <> select art2 'key]
				not find cmp 'key
				append cmp key
			]
		]
		r
	]

	compare-objects: function [
		"Compare 2 objects/artifacts and return a set of words that are different"
		o1 [object! none!] o2 [object! none!]
	][
		r: copy []
		unless all [o1 o2] [return r]
		ws: words-of o1
		art?: all [find ws 'key  find ws 'type]		;-- objects are artifacts?
		if ws <> ws2: words-of o2 [append r difference ws ws2]
		foreach w intersect ws ws2 [
			if all [art?  w = 'file] [continue]			;-- ignore filenames - they're always different
			if (select o1 w) <> (select o2 w) [append r w]
		]
		r
	]

	get-improvement: function [
		"Get improvement score of test KEY (-3 to +3 or '? when suspicious)"
		key [string!]
		/local res arts1 arts2
	][
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

		cache: #()								;-- greatly reduces CPU & RAM load
		set [res arts1 arts2] cache/:key
		all [
			arts1 =? issue/artifacts
			arts2 =? cmp/artifacts
			return res
		]

		;; now that results are equal, look for subtle differences
		arts: copy issue/artifacts

		;; this is done by `compare-artifact-sets` but with a lot more memory pressure, cuz it unpacks images
		remove-each a arts [find [context build] a/type]		;-- ignore `context` which we don't save at all; and build which always differs
		either (length? arts) <> length? cmp/artifacts [
			res: '?
		][
			;@@ TODO: optimize this for less memory pressure
			cmprslt: compare-artifact-sets arts copy cmp/artifacts		;-- blocks of words that differ
			res: pick [? 0] 0 <> sum map-each c cmprslt [length? c]
		]

		cache/:key: reduce [res issue/artifacts cmp/artifacts]
		res
	]

	get-build-from: function [
		"Get build info from an artifact set"
		artset [block!]
	][
		foreach a artset [					;@@ TODO: use `locate`
			if a/type = 'build [
				return #composite "(a/date) (either a/commit [to paren! a/commit][""])"
			]
		]
		""
	]

	visual-comparison: function [
		"Compare test results side-by-side"
		key [string!]
	][
		prep: func [v [any-type!]] [if paren? :v [v: do v] :v]		;-- support for `(load/as .. 'png)
		;@@ TODO: add other issue parameters (field) into the header! and call explore-* on those!
		arts1: copy issues/:key/artifacts
		arts2: copy comparison/:key/artifacts
		build1: get-build-from arts1
		build2: get-build-from arts2
		diff: compare-artifact-sets arts1 arts2
		view/flags/options elastic collect [
			keep compose [
				backdrop #608 space 10x4
				text 300 #405 #FF4 #scale-x center "Current:" 
				text 300 #405 #FF4 #scale-x center "Reference:" return
				text 300 #405 #FF4 #scale-x center (build1)
				text 300 #405 #FF4 #scale-x center (build2) return
			]
			keep map-each [i: ws] diff [
				clr: pick [#5F4 #F45] empty? ws
				code: compose/only [explore+compare (v1: arts1/:i) (v2: arts2/:i)]
				compose/deep/only [
					;; should be left-aligned to show the beginning of long strings, e.g. `make object! ..`
					button 300x25 (mold/flat/part v1 100) glass (clr) #scale-x left on-click (code)
					button 300x25 (mold/flat/part v2 100) glass (clr) #scale-x left on-click (code)
					return
				]
			]
		] 'resize [text: #composite "(key) comparison"]
	]

	explore+compare: function [
		"Compare 2 values side by side"
		v1 [any-type!] v2 [any-type!]
		/name nm /owners o1 o2
		/builds "Specify console build versions where those objects were obtained"
			b1 [object! none!] b2 [object! none!]
	][
		case [
			; all [block?  :art1  block?  :art2]
			all [object? :v1  object? :v2] [explore+compare-objects v1 v2]
			all [image?  :v1  image?  :v2] [explore+compare-images v1 v2]
			all [block?  :v1  block?  :v2  o1 o2] [
				if all ['box = select o1 'type  'box = select o2 'type] [		;-- special cases for edges & boxes
					switch nm [
						edges [
							explore+compare-images
								imprint-edges copy o1/image o1/edges
								imprint-edges copy o2/image o2/edges
						]
						boxes [
							explore+compare-images
								imprint-boxes copy o1/image o1/boxes magenta
								imprint-boxes copy o2/image o2/boxes magenta
						]
						box [
							explore+compare-images
								imprint-boxes copy o1/image reduce [100% o1/box/1 o1/box/1 + o1/box/2] cyan
								imprint-boxes copy o2/image reduce [100% o2/box/1 o2/box/1 + o2/box/2] cyan
						]
					]
				]
				;@@ TODO: explore blocks (lists) ability & somehow unite it with visual-comparison
			]
		]		;-- do not descend into scalars or if different types (then difference is obvious)
		;@@ TODO: text - highlight different areas using rich-text & red background - requires levenshtein's
		;; images: scale to fit, add a difference image
		;; objects: word/value table, colored
		;; @@ anything else?
	]
	
	explore+compare-objects: function [
		"Compare 2 objects side by side"
		o1 [object!] o2 [object!]
	][
		diff: compare-objects o1 o2
		view/flags/options elastic collect [
			keep [
				backdrop #608 space 10x4
				text 300 #405 #FF4 #scale-x center "Current:" 
				pad 70x0
				text 300 #405 #FF4 #scale-x center "Reference:" return
			]
			ws: union words-of o1 words-of o2
			keep map-each w ws [
				clr: pick [#5F4 #F45] none? find diff w
				v1: select o1 w
				v2: select o2 w
				code: compose/only [explore+compare/name/owners quote (:v1) quote (:v2) quote (w) (o1) (o2)]
				compose/deep/only [
					;; should be left-aligned to show the beginning of long strings, e.g. `make object! ..`
					button 300x25 (mold/flat/part :v1 100) glass (clr) #scale-x left on-click (code)
					text   60     (mold/flat w)            glass (clr) #scale-x center
					button 300x25 (mold/flat/part :v2 100) glass (clr) #scale-x left on-click (code)
					return
				]
			]
		] 'resize [text: "objects comparison"]
	]

	explore+compare-images: function [
		"Compare 2 images side by side"
		i1 [image!] i2 [image!]
	][
		ssize: system/view/screens/1/size
		third: ssize - 100x200 / 3x1
		i1': i1  i2': i2
		if i1/size <> i2/size [
			unisize: max i1/size i2/size
			if i1/size <> unisize [i1': draw unisize [image i1]]
			if i2/size <> unisize [i2': draw unisize [image i2]]
		]

		diff: make image! i1'/size
		xyloop xy diff/size [if i1'/:xy = i2/:xy [diff/:xy: black]]	;@@ TODO: do this in R/S
		i1':   scale-to-fit i1   third
		i2':   scale-to-fit i2   third
		diff': scale-to-fit diff third

		view/flags/options elastic compose [
			backdrop #608
			text (  i1'/size/x) #405 #FF4 #scale-x center "Current:" 
			text (diff'/size/x) #405 #FF4 #scale-x center "Diff:" 
			text (  i2'/size/x) #405 #FF4 #scale-x center "Reference:" return
			text (  i1'/size/x) (#composite "size: (i1/size)") center #608 (clr: pick [#5F4 #F45] i1/size = i2/size)
			pad  (diff'/size * 1x0)
			text (  i2'/size/x) (#composite "size: (i2/size)") center #608 (clr) return
			image i1'   on-down [explore i1]  			;@@ TODO: should be on-up, but see #4384
			image diff' on-down [explore diff]
			image i2'   on-down [explore i2]
		] 'resize [text: "images comparison"]
	]


	;@@ should we automatically choose reference, or save/load to/from config?
	; it can be boring to find it among the logs - a prefiltering might help but will disable the ability to use non-full results as reference
	;; automatically compare to the previous reference run
	;; %.reference.run file is created automatically when all tests were finished
	load-reference: function ["Find and load last saved or last produced reference run for comparison"] [
		cmp: runs: sort/reverse read %../			;-- newer items come first
		unless cmp-dir: select config 'last-comparison-dir [
			foreach dir runs [
				if all [
					find/match dir %run-				;-- one can rename `run-` dirs but only by adding a suffix
					exists? cmp: #composite %"../(dir).reference.run"
				][
					cmp-dir: #composite %"../(dir)"
					break
				]
			]
		]
		if cmp-dir [load-comparison cmp-dir]
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

	load-reference

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
