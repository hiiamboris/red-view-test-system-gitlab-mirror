Red [
	title:   "hi-level view testing facilities"
	author:  @hiiamboris
	license: 'BSD-3
]

recycle/off 
#either value? 'startup-dir [
	do #composite %"(startup-dir)dope.red"
	do #composite %"(startup-dir)jobs.red"
	do #composite %"(startup-dir)input.red"
	do #composite %"(startup-dir)visuals.red"
][
	#include %dope.red
	#include %jobs.red
	#include %input.red
	#include %visuals.red
]

;; let all I/O be localized in a single isolated directory:
;;   working-dir will contain the workers and their I/O
;;   current dir (same by default) will contain tests output, scripts, compiled exes and artifacts
once startup-dir: what-dir
once working-dir: clean-path rejoin [%logs/run- timestamp %/]
unless what-dir = working-dir [
	unless exists? working-dir [make-dir/deep working-dir]
	change-dir working-dir
]

assert [what-dir = working-dir]

#where's-my-error?

load-issues: does [clear issues: #() do #composite %"(startup-dir)issues.red"]		;@@ move this into %issues.red?

reload: does [do/expand load #composite %"(startup-dir)testing.red" ()]		;-- load is required for change-dir to have effect

unless value? 'main-worker [jobs/init]

score: 0

toolset: context [

	{
		issue status can be:
			not-compiled - for those requiring compilation
			compiling - after compilation started
			ready - compiled or does not require compilation
			tested - ran at least once; test results are available

		issue result can be:
			none - not tested yet
			ok - all tests pass
			warning - at least one parameter at a warning level, and no errors/critical levels
			error - at least one `expect` failed or at least one parameter reached critical level
			crash - crash detected during testing (overrides any errors)
			freeze - hung during testing (overrides any errors and crashes)
	}
	set 'issue function [
		"Declare an issue test code with specific test capabilities"
		title [string! issue!]
		test-code [block!]
		/interactive "Exposes DISPLAY, CLICK, DRAG, SHOOT (and more)"
		/layout "Exposes SHOOT"
		/compile /compiled "Exposes COMPILE"
		/local condition
	][
		;@@ map has got no support for #issue keys yet - gotta convert to string
		if issue? title [title: mold title]
		words: collect [		;-- these words are automatically bound to `toolset` context
			keep [offload sync pull push should settle-down expect-box crashed?]	;-- common words
			case/all [
				interactive
					[keep [display click drag roll-the-wheel move-pointer sim-key sim-string shoot close-windows close]]
				layout
					[keep [shoot close-windows]]
				any [compile compiled]
					[keep bind [compile run] toolset]		;-- shouldn't bind it to local /compile
			]
		]
		code: copy/deep test-code				;-- will be modified
		;; for now, just remove `should not.. patterns` @@ TODO: use them
		;; test code may formally not contain any tests but `should not` directive which is the test condition!
		special: copy []
		parse/case code [
			any [
				to remove ['should 'not set condition ['crash | 'hang | 'error 'out]]
				(append special condition)
			]
			to end
		]

		bind-only code words
		flags: object compose [
			interactive: (interactive)
			layout: (layout)
			compiled: (any [compile compiled])
			should-not: special
		]
		vars: expand-variants code
		foreach [vnum vcode] vars [
			key: either 2 = length? vars [title][#composite "(title)-(vnum)"]
			if issues/:key [		;-- redefinition attempt
				warn #composite "Redefinition of issue (key) detected"
			]
			ctx: make-context-for vcode			;-- binds in place
			issues/:key: object compose/only [
				code:   (vcode)
				flags:  (flags)
				ctx:    (ctx)
				key:    (key)
				title:	either string? :vcode/1 [:vcode/1][none]
				status: either flags/compiled ['not-compiled]['ready]
				result: none
				log:    none
				artifacts: copy []
			]
		]
	]

	;; VARIANT - top level only! (for now at least;; TODO - deep variant)
	expand-variants: function [definition [block!]] [
		v-numbers: copy []
		forparse [
			'variant [
				[set i integer! | p: (ERROR "`variant` expects integer here: (mold-part/flat p 50)")]
				[block!         | p: (ERROR "`variant` expects a block here: (mold-part/flat p 50)")]
			]
		] definition [append v-numbers i]
		
		either empty? v-numbers [
			variants: reduce [1 definition]
		][
			variants: copy []
			v-numbers: sort unique v-numbers
			foreach v-num v-numbers [
				append variants v-num
				append/only variants collect [			;-- parse's keep implies /only - no good
					parse definition [
						any [
							p: thru [s: 'variant set i integer! set b block!]
							(
								keep copy/deep/part p s
								if i = v-num [keep new-line b yes]
							)
						]
						p: (keep copy/deep p)
					]
				]
			]
		]
		; probe variants
		variants
	]

	; ;@@ TODO: box these into a context
	; should: func ['not? [word!] 'what? [word!]] []	;@@ TODO

	crashed?: function [
		"Check if main worker has crashed and if so, return it's last output & restart it"
	][
		wait 0.2		;-- delay for OS to realize the worker process has stopped
		unless jobs/alive? main-worker [
			;@@ TODO: subtract something from the score on crash??
			panic #composite "main-worker has CRASHED! during execution of:^/(mold main-worker/last-code)"
			output: jobs/peek-worker-output main-worker		;-- read it's last wish
			jobs/restart-worker main-worker
			output
		]
	]

	set '... none			;-- this is required to load cross-linked face trees

	offload: function [
		"Let one of the workers to perform CODE"
		code	[block!]
		/return "Mold and load the CODE result"
		/timeout period [time! integer! float!] "Wait no longer than PERIOD"
		/silent "Silently allow an error (incompatible with /return)"
		; /heavy  "Use heavy worker (default: main worker)"
		; /async	"Return immediately (otherwise blocks)"
	][
	 	default period: [0:0:10]
	 	if return [code: compose/only [print mold/all/flat do (code)]]	 ;@@ mold/all leads to unloadable #[handle! ...] - FIXED by commit
		task: jobs/send-main code
		output: clock [jobs/wait-for-task/max task period]
		either output [
			;@@ for debugging only:
			print #composite "=== Worker said:^/(copy/part output 100)^/==="

			any [				;-- check for errors
				silent
				not parse output [thru "***" thru "Error:" thru "^/*** Where:" thru "^/*** Stack:" to end]
				ERROR "command (mold-part/flat code 30) failed with:^/(form/part output 100)"
			]
		][
			either jobs/alive? main-worker [
				ERROR "=== Worker is BUSY! after executing:^/(mold-part code 100)^/==="		;@@ TODO: kill it or not?
			][
				crashed?							;-- crashed! report and restart
				system/words/return ()				;-- make the tests (if any) fail
			]
		]
		either return [							;-- load the output?
			;@@ workaround for the bug of `mold` - molds unset values as `unset` word: return an unset explicitly
			either any [						;-- produce "unset" if:
				none? output						;-- worker is busy
				"unset" = trim/lines copy output	;-- it returned unset (which isn't properly molded)
			] [] [do load/all output]
		][output]
	]

	;@@ TODO: keep all important stuff in contexts and context names - somewhere else? for sync not to override them

	pull: sync: function [
		; "Sets local WORD to the value of this word held by main worker"		-- deprecated behavior as I forget to declare a set-word to make it local
		"Return the value of the WORD used by main worker"
		'word	[any-word!]
		;@@ TODO: /with other-worker.. (or /from)
		/local x
	][
		set/any 'x offload/return reduce [to get-word! word]	;@@ TODO: trap it
		; if value? 'x [set word :x]			;-- do not pull `unset` words as they are mistakingly pulled -- deprecated
	]

	push: function [
		"Sets main worker's WORD it's local value"
		'word	[any-word!]
		;@@ TODO: /into other-worker..
	][
		#assert [not all [object? get word  quacks-like-face? get word]]		;-- no need to push faces, right?
		offload reduce [to set-word! word 'quote get word]		;@@ TODO: trap it
	]

	;@@ TODO: upon exiting the interactive issue code - offload [unview/all]

	display: function [
		"View LAYOUT in a main-worker thread; return the window object and sync all set-words"
		layout [block!]
		/with  opts [block!]
		/flags flgs [block! word!]
		/tight
		/local ret
	][
		set-words: append collect-set-words layout [top-window:]	;-- need `top-window:` to sync it properly
		view-path: apply/only view construct/only compose/only [
			no-wait: yes
			spec:    (layout)
			tight:   (tight)
			options: (with)  opts: (opts)
			flags:   (flags) flgs: (flgs)
		]
		offload compose [top-window: (view-path)]		;-- the main window
		foreach sw set-words [set/any sw pull (sw)]		;@@ TODO: process ALL queued events before pulling?
		foreach sw set-words [							;-- also update window objects for use in capture-face
			all [
				object? set/any 'face get/any sw
				quacks-like-face? face
				win: window-of face
				not same? face win
				win/state/1: top-window/state/1
			]
		]
		;@@ TODO: should `display` call `settle-down`?
		#assert [quacks-like-face? top-window]
		top-window
	]

	;@@ BUG: see #4268,#4269 - `to-image` cannot be used on faces directly
	;; however it seems to work with the whole window, so we just have to crop it after
	shoot: function [
		"Capture the LAYOUT in a main-worker thread using to-image; return the image"
		'layout [block! word!] "Layout block or name of a face known to the worker"
		/real "Capture real appearance (may be overlapped!)"
		/whole "Include non-client area if layout is a window"
		/tight
		/local top-window
	][
		#assert ['compose <> layout]		;-- a likely shoot compose [..] error - use shoot (compose [..])
		unless word? layout [
			close?: yes
			; top-window: display layout
			top-window: either tight [display/tight layout][display layout]
			layout: 'top-window
		]
		settle-down 1 sec
		
		; img: offload/return compose [to-image (layout)]
		unless real [
			unless object? face: get/any layout [face: pull (layout)]		;-- word hasn't been synced, but we need to know it's face type
			img: offload/return compose [
				to-image (either 'window = face/type [layout]['top-window])		;-- to-image doesn't work on bare faces, so shoot the whole window
			]
		]
		layout: pull (layout)		;-- sync it, as we require it right now and it can be unset or filled with other data locally
		#assert [object? :layout]
		#assert [quacks-like-face? :layout]
		img: apply capture-face compose [
			face:  layout
			real:  (real)
			with:  (not real) img: (img)
			whole: (whole)
		]

		if close? [offload [unview]]
		#assert [image? img]
		img
	]

	close-windows: function [
		"Close all windows opened by the main-worker"
	][
		offload [unview/all]
	]

	;@@ TODO: portable way or one for each OS
	close: function [
		"Close a WINDOW by interacting with it"
		window [object!] "Region on a screen where window is located"
	][
		;; I'd love to send Alt-F4 to it, but it's unreliable - often closes layered windows
		simulate-input-raw compose [
			(window/offset + (window/size * 1x0) + -10x10)		;-- target the X button
			+ lmb - lmb
		]
		do-queued-events				;-- required to redraw background so the window actually disappears from the screen
	]


	settle-down: function [
		"Wait until there's no movement on the screen or time is out"
		num		[integer! float!]
		'unit	[word!] "sec / ms"
	][
		num: num * switch unit [
			sec secs second seconds [1.0]
			ms msec millis [1e-3]
		]
		t1: now/precise
		; im: reduce [capture none]
		im: [#[none] #[none]]
		im/1: capture/no-save/into im/1
		still: 1
		until [
			do-queued-events	;-- this is for redrawing own background, cleaning it from already destroyed windows
			wait 0.05			;-- screenshot alone takes ~10ms
			im/2: capture/no-save/into im/2
			reverse im
			any [
				num <= to float! difference now/precise t1		;-- out of time
				3 <= still: either im/1 = im/2 [still + 1][1]	;-- 3 different shots were equal
			] 
		]
		; im/1
		;-- I'd return the screenshot but it takes too much RAM to not reuse it
		;@@ TODO: return it once GC takes care of images
		none
	]

	;; right now it just jumps to the destination point
	drag: function [
		"Simulate a drag & drop event"
		start	[object! pair!] "Where to click: face object or a screen coordinate"
		path	[block! pair!] "Dragging path: [direction 'by integer!] or an offset"
		;@@ TODO: more sophisticated drag paths? intermediate mouse-move events?
		;@@ TODO: modifier keys?
	][
		if object? start [
			either quacks-like-face? start [
				activate start
				offload body-of :do-queued-events			;-- let worker process the activation request
				start: face-at start start/size / 2			;-- aim at center
			][
				start: start/size / 2 + start/offset + any [attempt [start/base] 0x0]
			]
		]
		if block? path [
			=dir=: ['left | 'right | 'up | 'down]
			unless parse/case path [set dir =dir= 'by set amnt integer!] [
				ERROR "drag: invalid path spec (mold path)"
			]
			path: amnt * select [left -1x0 right 1x0 up 0x-1 down 0x1] dir
		]
		simulate-input-raw compose [(start)  + lmb  (start + path)  - lmb]
		offload body-of :do-queued-events				;-- let worker process the drag events
	]

	click: function [
		"Simulate a left click on a center of face object or at specific point"
		target		[object! pair!] "Face object or a screen coordinate"
		/mods mlist	[block!] "List of modifier keys"
		/at point	[pair! block!] "Offset in the face or coordinate descriptor block"
		; /no-wait	"Do not wait for the worker to process the event"
		/right		"Simulate RMB instead"
		/double		"Double the specified event"
		/async		"Do not wait for the worker to process the click event"		;-- this is useful when popping up any menu - the event loop stops
		/local mod
	][
		if mods [simulate-input-raw map-each/eval mod mlist [['+ mod]]]
		if object? target [
			either quacks-like-face? target [
				activate target
				offload body-of :do-queued-events			;-- let worker process the activation request
				unless point [point: target/size / 2]		;-- aim at center
				target: face-at target point
			][
				target: target/size / 2 + target/offset + any [attempt [target/base] 0x0]
			]
		]
		move:  reduce [target]
		click: pick [[+ rmb - rmb][+ lmb - lmb]] right
		simulate-input-raw compose [(move) (click)]
		if double [wait 0.05 simulate-input-raw click]
		if mods [simulate-input-raw reverse map-each/eval mod mlist [[mod '-]]]
		unless async [offload body-of :do-queued-events]	;-- let worker process the input (else sync may return old values in `sync`)
	]

	sim-key: function [
		'key [word! char!]
		/mods mlist	[block!] "List of modifier keys"
		/async		"Do not wait for the worker to process the click event"		;-- this is useful when popping up any menu - the event loop stops
		/local mod
		;@@ TODO: add a target to focus before keypresses?
	][
		if mods [simulate-input-raw map-each/eval mod mlist [['+ mod]]]
		simulate-input-raw reduce ['+ key '- key]
		if mods [simulate-input-raw reverse map-each/eval mod mlist [[mod '-]]]
		unless async [offload body-of :do-queued-events]	;-- let worker process the input (else sync may return old values in `sync`)
	]

	sim-string: function [
		str [string!]
		/async		"Do not wait for the worker to process the click event"		;-- this is useful when popping up any menu - the event loop stops
		/local c
		;@@ TODO: add a target to focus before keypresses?
	][
		simulate-input-raw map-each/eval c str [['+ c '- c]]
		unless async [offload body-of :do-queued-events]	;-- let worker process the input (else sync may return old values in `sync`)
	]

	roll-the-wheel: function [
		"Simulate a mouse-wheel event"
		'direction [word!] "up or down"
		;@@ TODO: add /mods? /async? multiplier for many rotations at once?
	][
		#assert [find [up down] direction]
		simulate-input-raw compose [
			(pick [+ -] 'up = direction) wheel
		]
		offload body-of :do-queued-events	;-- let worker process the input (else wheel-up + wheel-down may produce no event at all)
	]

	move-pointer: function [
		"Simulate a mouse-move event"
		offset [pair!] "Screen coordinate"		;-- use ~at~ to target faces/boxes
	][
		simulate-input-raw reduce [offset]
		offload body-of :do-queued-events	;-- let worker process the input (else wheel-up + wheel-down may produce no event at all)
	]

	;@@ TODO: make issue set-words local; and also synced words local
	;@@ TODO: inspect any values inside an issue post-failure
	;@@ TODO: a list of successful and failed issues (latter may be re-tested, or the test process interrupted and continued...)
	set 'ti set 'test-issue function [
		"Run the tests for a given issue"
		title [string! issue! number!]
		/variant vnum [integer!]
		/no-review
		/local code flags
		/extern score
	][
		mark: log-mark

		key: form-issue-key/variant title vnum
		unless def: issues/:key [
			ERROR "Unable to find definition for issue (key)"
		]
		#assert [find [ready tested] def/status]
		#assert [not all [def/flags/compiled find [not-compiled compiling] def/status] "Issue has not been compiled!"]

		code: def/code
		;; log the issue context
		;; @@ TODO: maybe log the whole issue object? ;)
		unless empty? words-of def/ctx [
			log-artifact object compose [type: 'context  ctx: (def/ctx)  key: (key)]
		]

		if def/flags/interactive [bgnd: display-background do-queued-events]
		sw-len: offload/return [length? words-of system/words]
		eval-results-group/key code key

		close-windows
		if bgnd [unview/only bgnd]		;@@ TODO: display it once only?
		finish-exes key
		offload compose [					;-- unset all used words (cleanup)
			unset skip words-of system/words (sw-len)
		]
		recycle											;-- forget screenshots
		;@@ TODO: maybe call `clear-reactions` too?

		;; update the result
		def/status: 'tested
		msgs: rejoin ["" keep-type log-since mark string!]
		foreach [marker word should-cond] [
			"WARNING:" warning #[none]			;-- order here: from the small evil to greater
			"ERROR:"   error   error
			"CRASHED!" crash   crash
			"BUSY!"    freeze  hang
		][
			if find/case msgs marker [
				result: word
				continue						;-- score shouldn't be incremented
			]
			if find def/flags/should-not should-cond [	;-- condition affects the score
				score: score + 1		;@@ TODO: or get rid of `should not *` completely?
			]
		]
		default result: ['ok]
		def/result: result
		log-artifact object compose [
			type:   'result
			result: quote (result)
			key:    (key)
		]
		save-artifacts key		;-- save for later comparison

		unless no-review [log-review/key key]
	]

	comment {
		compile logic:
		1) check if compiled exe already exists, return it then
		2) if not, make a job for the worker and throw a STOP
		who will wait for the job?

		limitations of compile:
		- after variant expansion, `compile` should be a top-level instruction
		- tests code should not rely on worker preserving any words set before a call to `compile`
		- only a single compile per variant is allowed for now (@@ TODO: relax this)
			(multiple compiles were never needed so far and they complicate the test system logic)
	}

	once compile-tasks: #()

	set 'start-compile function [
		title	[issue! integer! string!]
		/variant var [integer!]
	][
		key: form-issue-key/variant title var
		unless def: issues/:key [ERROR "Unable to find definition for issue (key)"]
		unless def/flags/compiled [ERROR "Not a compiled issue - (key)"]
		;; verify that this variant (it's non-evaluated yet part) has a compile instruction
		unless compile-ahead? def/code [ERROR "Nothing to compile in issue (key)"]
		code: eval-part/key def/code key
		def/status: 'compiling
		#assert [same? head code head def/code]
		def/code: code					;-- update the variant code to start off the new point next time
		; assert [not empty? code]			;-- compile should not be the only instruction
		; assert [not compile-ahead? code]	;@@ see the note above
		compile-tasks/:key			;-- return the task
	]

	set 'run-all-interpreted function [
		"Test all issues that do not require compilation"
		/local code flags
	][
		foreach [key def] issues [
			unless def/flags/compiled [test-issue key]
		]
	]

	;; returns a block of refinements (could be empty) or none
	compile-ahead?: function [code [block!]] [
		flags: []
		all [
			parse code [
				to ['compile | ahead path! into ['compile copy flags some word! to end]] to end
			]
			as block! flags
		]
	]

	;; this one has to be smart:
	;; 1) schedule a devmode script first - this creates libredrt
	;; 2) schedule all release-mode scripts - to give the 1st compilation time to finish
	;; 3) schedule all the rest - with libredrt present devmode compilations should be fast
	set 'start-compile-all function [
		"Initiate compilation of all compiled issues"
		/local code flags
	][
		list: copy []
		foreach [key def] issues [
			if any [
				not def/flags/compiled				;-- not a /compiled issue
				not flags: compile-ahead? def/code	;-- no `compile` in non-evaluated part of it?
				is-compiled? key					;-- already done?
			] [continue]
			repend list [def find flags 'release]
		]
		sort/skip/compare/reverse list 2 2			;-- puts /release compiles ahead
		if false = last list [						;-- at least one /devmode present?
			insert list take/part skip tail list -2 2	;-- move it to the head of the list
		]
		foreach [def rel?] list [
			def/code: eval-part/key def/code def/key	;-- compile & update the variant code to start off the new point next time
			def/status: 'compiling
			; assert [not empty? code]			;-- compile should not be the only instruction
			; assert [not compile-ahead? code]	;@@ see the note above
		]
	]

	;; returns none if such issue was never started to compile or if it's not finished
	set 'is-compiled? function [
		"Check if issue with KEY has finished compiling"
		key [string!]
	][
		task: compile-tasks/:key
		; assert [not none? task]
		any [
			all [task task/finished?]
			exists? #composite %"(key)-code.exe"	;-- allow user to provide the exe ;@@ TODO: make it portable
		]
	]

	set 'do-compiled-tests function ["Test all compiled issues that were interrupted by compilation"] [
		unless while-waiting 0:10:0 [not empty? compile-tasks] [		;@@ TODO: how much to wait?
			foreach [key task] compile-tasks [
				jobs/read-task-report task/worker			;-- update it's state
				if task/finished? [
					test-issue key
					remove/key compile-tasks key
					break				;-- better not to rely on foreach after removal and restart iterations
				]
			]
			wait 0.1
		] [ERROR "Could not finish issues compilation!"]
	]


	compile: function [
		code	[block! string!] "Code to compile"			;-- string is meant for invalid code - non-loadable
		/release "-r" /devmode "-c"
		/debug "-d"
		/header "Add header automatically"		;@@ TODO: make it the default??
		/local flag opt
		;@@ TODO: -e flag too?
	][
		if all     [release devmode] [ERROR "/release and /devmode are mutually exclusive"]
		unless any [release devmode] [ERROR "compilation mode [/release or /devmode] should be specified"]		;@@ TODO: or /devmode by default??
		flags: rejoin map-each [flag opt] reduce [release " -r" devmode " -c" debug " -d"] [either flag [opt][""]]

		if block? code [code: mold/all/only code]		;@@ okay to use /all ?
		if header [
			unless parse/case code [to ["Red" opt "/System" any [#" " | #"^-"] "["]] [
				insert code: copy code "Red [needs: view]^/"		;-- use 'view since that's our primary testing target
			]
		]

		key: current-key
		assert [not none? key]						;-- require a unique name
		src-file: #composite %"(key)-code.red"		;-- paths fed to worker are relative to where worker has been started!
		exe-file: #composite %"(key)-code.exe"		;@@ TODO: make it portable
		if exists? exe-file [return exe-file]		;-- return the exe name if it exists

		write src-file code
		cmd: #composite {red(flags) -o "(to-local-file exe-file)" "(to-local-file src-file)"}
		job: compose [
			pid: call/shell/wait/output (cmd) output: ""
			print [pid lf output]						;-- let it show the results after
		]
		log-info #composite "Starting compile job in a heavy worker: (cmd)"
		task: jobs/send-heavy job
		put compile-tasks key task
		stop-here
	]


	once running-exes: #()		;-- keep track of started by each issue processes

	running!: object [
		name: handle: stdout: startup-time: none
		output: does [all [stdout read stdout]]
	]

	run: function [
		"Run an EXE file; return a running! object"
		exe	[file!]
		/no-output "Do not divert stdout to a file"
		/wait "Wait for completion"
			period [integer! float! time!]
	][
		r: make running! [
			name: copy exe
			handle: either no-output [
				start-exe exe
			][
				basename: either %.exe = suffix? exe [clear skip tail copy exe -4][copy exe]
				stdout: #composite %"(basename)-stdout.txt"
				start-exe/output exe stdout
			]
			startup-time: now/precise
		]
		key: current-key
		exes: running-exes/:key
		unless exes [exes: running-exes/:key: copy []]
		append exes r/handle
		either wait [
			stop-exe/max r/handle period		;-- return once it's down
		][
			system/words/wait 1.0		;-- delay until `view` kicks in ;@@ TODO: how to ensure Red script is read & running already?
		]
		r
	]

	finish-exes: function [
		"Finish executables started by the issue"
		key [string!]
	][
		if list: running-exes/:key [
			period: 0:0:5								;-- let it be total time
			if exe: list/1 [period: period - stop-exe exe]
			foreach exe next list [
				period: period - stop-exe/max exe period
			]
			clear list
		]
	]

	form-issue-key: func [
		"Form a normalized issue title from it's number or #issue value"
		title	[integer! issue! string!]
		/variant vnum [integer! none!]
	][
		title: switch type?/word title [
			issue!   [mold title]
			integer! [rejoin ["#" title]]
			string!  [return title]		;-- should have a variant appended already
		]
		if vnum [title: #composite "(title)-(vnum)"]
		title
	]

	;@@ TODO: special context for the tester as well, to preserve it's words
	background: none

	display-background: does [
		background: view/flags/tight/no-wait compose [
			base (system/view/screens/1/size) white
		] 'no-border
		do-queued-events
		background
	]

	set 'test-everything function [] [
		;@@ TODO: compile libredrt first, then all issues based on it?
		start-compile-all
		run-all-interpreted
		do-compiled-tests
	]

]
; halt

load-issues

import toolset		;-- for use in the console  ;@@ TODO: remove this

; issue/interactive "test" [
; 	"abcdef"
; 	variant 1 [x: 100]
; 	variant 2 [x: 200]
; 	1 + 1
; 	click 1x1 * x
; ]

