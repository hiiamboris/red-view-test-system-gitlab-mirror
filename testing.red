Red [
	title:   "hi-level view testing facilities"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %dope.red
#include %jobs.red
#include %input.red
#include %visuals.red

; #where's-my-error?

load-issues: does [clear issues: #() do %issues.red]	;@@ move this into %issues.red?

reload: does [do %testmap.red]

unless value? 'main-worker [jobs/init]

toolset: context [

	set 'issue function [
		"Declare an issue test code with specific test capabilities"
		title [string! issue!]
		test-code [block!]
		/interactive "Exposes DISPLAY, CLICK, DRAG, SHOOT"
		/layout "Exposes SHOOT"
		/compile /compiled "Exposes COMPILE"
		/deadlock "IDK yet @@ TODO"
		;@@ TODO: refinements
	][
		;@@ map has got no support for #issue keys yet - gotta convert to string
		if issue? title [title: mold title]
		if issues/:title [		;-- redefinition attempt
			warn #composite "Redefinition of issue (mold title) detected"
		]
		words: collect [		;-- these words are automatically bound to `toolset` context
			keep [offload sync pull should settle-down]	;-- common words
			if interactive [keep [display click drag shoot close-windows]]
			if layout [keep [shoot close-windows]]
		]
		code: copy/deep test-code				;-- will be modified
		bind-only code words
		issues/:title: code
		;@@ TODO: each issue should live in it's own context - for /compile recursion to work
	]

	comment {
		problem with `compile` is that it can't pre-compile stuff before running the issue code: that code may form the string to compile
		but it also can't wait until compilation is finished - that's too slow
		I also can't let the workers perform the issues code as that will complicate them too much and affect their behavior
		(at the very least workers should be run on unmodified console)
		so the least evil seems to be to let it recurse:
		`compile` sends the compilation task to the worker and forks into testing another issue
		after this issue's successful/erroneous evaluation, it tests again and either forks again or proceeds with issue's code
		.. but for that I need to first finish the linear testing pipeline ..
	}

	compile: function [
		title	[string! integer! issue!] "Issue number"	;@@ TODO: automatically get this from the issue
		code	[block! string!] "Code to compile"			;-- string is meant for invalid code - non-loadable
		/release "-r" /devmode "-c"
		/debug "-d"
		/header "Add header automatically"
	][
		if all     [release devmode] [ERROR "/release and /devmode are mutually exclusive"]
		unless any [release devmode] [ERROR "compilation mode (/release or /devmode) should be specified"]		;@@ TODO: or /devmode by default??
		flags: rejoin map-each [flag opt] reduce [release " -r" devmode " -c" debug " -d"] [either flag [opt][""]]

		title: form-issue-title title
		unless issues/:title [ERROR "Compile: unknown issue (mold title)"]
		if block? code [code: mold/all code]		;@@ okay to use /all ?

		if header [
			unless parse/case code [to ["Red" opt "/System" any [#" " | #"^-"] "["]] [
				insert code: copy code "Red [needs: view]^/"		;-- use 'view since that's our primary testing target
			]
		]

		file: #composite %"issue-(title).red"
		while [exists? file] [						;-- allow multiple compiles from a single test
			n: 1 + any [n 0]
			file: #composite %"issue-(title)-(n).red"
		]
		write file code

		jobs/send-heavy [call/shell/wait #composite {red(flags) "(to-local-file file)"}]
		;; returns task id
	]


	;; VARIANT - top level only! (for now at least;; TODO - deep variant)
	expand-variants: function [definition [block!]] [
		v-numbers: copy []
		forparse [
			'variant [
				[set i integer! | p: (ERROR "`variant` expects integer here: (mold/flat/part p 50)")]
				[block!         | p: (ERROR "`variant` expects a block here: (mold/flat/part p 50)")]
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
								keep copy/part p s
								if i = v-num [keep new-line b yes]
							)
						]
						p: (keep p)
					]
				]
			]
		]
		; probe variants
		variants
	]

	;@@ TODO: box these into a context
	should: func ['not? [word!] 'what? [word!]] []	;@@ TODO

	offload: function [
		"Let one of the workers to perform CODE"
		code	[block!]
		/return "Mold and load the CODE result"
		; /heavy  "Use heavy worker (default: main worker)"
		; /async	"Return immediately (otherwise blocks)"
	][
	 	if return [code: compose/only [print mold/flat do (code)]]	 ;@@ mold/all leads to unloadable #[handle! ...] - avoid it
		task: jobs/send-to main-worker code
		output: clock [jobs/wait-for-task/max task 3]
		;@@ for debugging only:
		either output [
			print #composite "=== Worker said:^/(copy/part output 100)^/==="
		][
			ERROR "=== Worker is BUSY! after executing:^/(mold/part code 100)^/==="
		]
		if return [output: do load/all output]
		output
	]

	;@@ TODO: keep all important stuff in contexts and context names - somewhere else? for sync not to override them

	;@@ TODO: also `push`?
	sync: pull: function [
		"Sets local WORD to the value of this word held by main worker"
		'word	[any-word!]
		;@@ TODO: /with other-worker..
	][
		set word offload/return reduce [to word! word]	;@@ TODO: trap it
		if quacks-like-face? face: get word [		;@@ HACK: also retrieve face's handle (as integer) for non-client size estimation!
			face/state/1: offload/return compose [
				second load next mold/all (as path! compose [(to word! word) state 1])
			]
		]
		get word
	]

	;@@ TODO: upon exiting the interactive issue code - offload [unview/all]

	display: function [
		"View LAYOUT in a main-worker thread; return the window object and sync all set-words"
		layout [block!]
		/local ret
	][
		=coll=: [any [keep set-word! | ahead [block! | paren!] into =coll= | skip]]
		set-words: append parse layout [collect =coll=] [top-window:]	;-- need `top-window:` to sync it properly
		offload compose/only [top-window: view/no-wait (layout)]		;-- return the main window
		foreach sw set-words [pull (sw)]				;@@ TODO: process ALL queued events before pulling?
		foreach sw set-words [							;-- also update window objects for use in capture-face
			all [
				object? face: get sw
				quacks-like-face? face
				not same? face win: window-of face
				win/state/1: top-window/state/1
			]
		]
		;@@ TODO: should `display` call `settle-down`?
		top-window
	]

	;@@ BUG: see #4268,#4269 - `to-image` cannot be used on faces directly
	;; however it seems to work with the whole window, so we just have to crop it after
	shoot: function [
		"Capture the LAYOUT in a main-worker thread using to-image; return the image"
		'layout [block! word!] "Layout block or name of a face known to the worker"
		/local top-window
	][
		unless word? layout [
			close?: yes
			display layout
			layout: 'top-window
		]
		settle-down 1 sec
		
		;@@ img: offload/return compose [to-image (layout)]	-- doesn't work
		;@@ workaround:
		img: offload/return compose [to-image top-window]
		if layout <> 'top-window [	;-- window might have or not have a border
			face: get layout
			img: capture-face/with face img
		]

		if close? [offload [unview]]
		img
	]

	close-windows: function [
		"Close all windows opened by the main-worker"
	][
		offload [unview/all]
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
		t1: now/time/precise
		; im: reduce [capture none]
		im: [#[none] #[none]]
		im/1: capture/into im/1
		still: 1
		until [
			wait 0.05		;-- screenshot alone takes ~10ms
			im/2: capture/into im/2
			reverse im
			any [
				num <= to float! now/time/precise - t1 + 24:00 % 24:00	;-- out of time
				3 <= still: either im/1 = im/2 [still + 1][1]			;-- 3 different shots were equal
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
			activate start
			offload body-of :do-queued-events			;-- let worker process the activation request
			start: face-at start start/size / 2			;-- aim at center
		]
		if block? path [
			=dir=: ['left | 'right | 'up | 'down]
			unless parse/case path [set dir =dir= 'by set amnt integer!] [
				ERROR "drag: invalid path spec (mold path)"
			]
			path: amnt * select [left -1x0 right 1x0 up 0x-1 down 0x1] dir
		]
		simulate-input-raw compose [(start)  + lmb  (start + path)  - lmb]
	]

	click: function [
		"Simulate a left click on a center of face object or at specific point"
		target		[object! pair!] "Face object or a screen coordinate"
		/mods mlist	[block!] "List of modifier keys"
		/at point	[pair! block!] "Offset in the face or coordinate descriptor block"
	][
		if mods [simulate-input-raw map-each/eval mod mlist [['+ mod]]]
		if object? target [
			activate target
			offload body-of :do-queued-events			;-- let worker process the activation request
			unless point [point: target/size / 2]		;-- aim at center
			target: face-at target point
		]
		simulate-input-raw compose [(target) + lmb - lmb]
		if mods [simulate-input-raw reverse map-each/eval mod mlist [[mod '-]]]
	]

	set 'test-issue function [
		"Run the tests for a given issue"
		title [string! issue! number!]
	][
		title: form-issue-title title
		unless definition: issues/:title [
			ERROR "Unable to find definition for issue (title)"
		]
		variants: expand-variants definition
		foreach [vnum vcode] variants [
			eval-results-group vcode
		]
		log-review
		close-windows
	]

	form-issue-title: func [
		"Form a normalized issue title from it's number or #issue value"
		title	[integer! issue! string!]
	][
		switch type?/word title [
			issue!   [mold title]
			integer! [rejoin ["#" title]]
			string!  [title]
		]
	]

	;@@ TODO: special context for the tester as well, to preserve it's words
	display-background: does [
		background: view/flags/tight/no-wait compose [
			base (system/view/screens/1/size) white
		] 'no-border
	]

]
; halt

load-issues
issue/interactive "test" [
	"abcdef"
	variant 1 [x: 100]
	variant 2 [x: 200]
	1 + 1
	click 1x1 * x
]

