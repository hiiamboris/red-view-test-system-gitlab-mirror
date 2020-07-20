Red [
	title:   "test set for individual issues"
	author:  @hiiamboris
	license: 'BSD-3
]


; #do [print "PREPROCESSING ISSUES"]
; print "EVALUATING ISSUES"

; #where's-my-error?

;@@ TODO: `close` should do platform-specific window closing action

;; issue /types define what capabilities are given to the code: can it compile? can it interact?
;; point is not just clearer definition, but that /compile & /layout can be parallelized but should not use screen-shots or actions

;; TIP: issues title is mostly for informational purpose:
;;   first, when debugging an issue - it makes clear what we're looking for
;;   second, when an issue fails this info can be displayed to provide the person running tests with a context for failure
;;   third, it helps to review tests in the Perspective GUI by telling what results one should expect and how to tell if they failed



issue/interactive #4564 [
	"[CRASH, View] in drop-down & drop-list when clicking outside the face"
	should not crash

	;; logic: click on an item that sticks out of the main window when it's above background (which belongs to another Red process)
	variant 1 [
		display [list: drop-list data ["1" "2" "3" "4" "5" "6" "7"]]	;-- provide enough lines so we don't click outside list itself by accident
	]
	variant 2 [
		display [list: drop-down data ["1" "2" "3" "4" "5" "6" "7"]]	;-- same
	]
	click list ~at~ [right - 10]		;-- expand the list
	wait 1
	click/async list ~at~ 50x60			;-- choose an item
	offload []
]

;@@ #4465 on auto-sync null window handle - will it be fixed?

issue/compiled #4463 [
	"[Compiler] Internal error when overriding face's facet with an object"

	exe: compile/devmode [
		Red [needs: 'view]
		context [
			lay: make-face 'window
			lay/data: object [smth: does []]
		]
		print "OK"
	]
	task: run/wait exe 3
	expect [task/output = "OK"]
]

issue/interactive #4461 [				;-- /interactive for it's crashing
	"[CRASH] When system object is assigned to any facet of a face"
	should not crash

	offload variant 1 [[layout [base data system]]]
	offload variant 2 [[layout [base data system/words]]]
]

;@@ #4458 on `with` in VID being unset - will it be fixed? and how?

issue/interactive #4457 [								;-- /interactive as it can crash
	"face/selected too big will close the window"
	should not crash

	display [field "a" with [selected: 1x1000000]]
]

issue/interactive #4454 [
	"[View] Oddities of event processing during initialization (only?)"

	variant 1 [
		;; logic: displays 6 equal faces created using different means - should be equal at screenshots
		offload [
			liist: []			;-- `init` binds `list` to `layout`! need a unique name
			extend svvs: system/view/VID/styles [
				cell: [
					template: [type: 'panel color: gold]
					init: [react/link func [base cell] [repend liist [cell/extra base/size: cell/size]] [face/pane/1 face]]
				]
				column1: [template: [type: 'panel]  init: [c1c/size/x: 180]]
				column2: [template: [type: 'panel actors: [on-create:  func [_][c2c/size/x: 180]]]]
				column3: [template: [type: 'panel actors: [on-created: func [_][c3c/size/x: 180]]]]
				column4: [template: [type: 'panel]  init: [c4c/size: as-pair 180 c4c/size/y]]
				column5: [template: [type: 'panel actors: [on-create:  func [_][c5c/size: as-pair 180 c5c/size/y]]]]
				column6: [template: [type: 'panel actors: [on-created: func [_][c6c/size: as-pair 180 c6c/size/y]]]]
			]
		]
		leaving [				;-- cleanup
			offload [
				remove/key svvs 'cell
				remove/key svvs 'column1
				remove/key svvs 'column2
				remove/key svvs 'column3
				remove/key svvs 'column4
				remove/key svvs 'column5
				remove/key svvs 'column6
			]
		]

		s1: shoot [c1: column1 purple [c1c: cell 40x40 [base teal] extra 1] 200x100]
		s2: shoot [c2: column2 purple [c2c: cell 40x40 [base teal] extra 2] 200x100]
		s3: shoot [c3: column3 purple [c3c: cell 40x40 [base teal] extra 3] 200x100]
		s4: shoot [c4: column4 purple [c4c: cell 40x40 [base teal] extra 4] 200x100]
		s5: shoot [c5: column5 purple [c5c: cell 40x40 [base teal] extra 5] 200x100]
		s6: shoot [c6: column6 purple [c6c: cell 40x40 [base teal] extra 6] 200x100]

		liist: sync liist									;-- not tested here, just informational
		; expect [liist = [...]]
		expect [s1 .=. s2 .=. s3 .=. s4 .=. s5 .=. s6]		;-- all should be equal
		expect [box [170x30 at s6 30x30 > 95% all teal]]	;-- and all should be equally valid
	];; variant 1

	variant 2 [
		;; logic: reaction should be triggered when s/size changes - just check if it is
		offload [
			extend svvs: system/view/VID/styles [
			    yourbase: [
			        template: [type: 'base size: 100x100]
			        init: [make-face 'base]     ;) remove this an it'll work!
			    ]
			]
		]
		leaving [offload [remove/key svvs 'yourbase]]

		display [
			do [list: []]
		    s: yourbase blue 400x300 react [append list s/size]
		    return btn: button "CLICK ME" [s/size: s/size - 20]
		]
		click btn
		click/right btn 		;-- avoids double-clicking
		click btn
		list: sync list
		expect [list = [400x300 380x280 360x260]]
	]
]

;; #4439 - covered by #4564!

issue/layout #4429 [
	"[View] Rich-text `para` facet resets default settings when present"

	s1: shoot/tight [rich-text {123^/234^/345^/456^/567^/678^/789}]
	s2: shoot/tight [rich-text {123^/234^/345^/456^/567^/678^/789} para []]
	s3: shoot/tight [rich-text top {123^/234^/345^/456^/567^/678^/789}]
	s4: shoot/tight [rich-text left {123^/234^/345^/456^/567^/678^/789}]
	s5: shoot/tight [rich-text right {123^/234^/345^/456^/567^/678^/789}]
	s6: shoot/tight [rich-text bottom {123^/234^/345^/456^/567^/678^/789}]
	s7: shoot/tight [rich-text middle center {123^/234^/345^/456^/567^/678^/789}]
	expect [s1 .=. s2 .=. s3 .=. s4]
	expect [text [aligned left top in s1]]
	expect [text [aligned top right in s5]]
	expect [text [aligned left bottom in s6]]
	expect [text [aligned middle center in s7]]
]

;@@ TODO: #4428 - to what extent it will be fixed and what the expected behavior will be?
;@@ TODO: #4418 - should be tested on MacOS - need to minify the examples and figure out how to aim at the menu

;; #4417 - same as #3942, but on MacOS - needs no separate test

issue/layout #4396 [
	"[CRASH] [View] when converting a face with altered `template` to an image"
	should not crash

	offload [
		extend svvs: system/view/VID/styles compose/only [
			window2: (copy/deep svvs/window)
			base2:   (copy/deep svvs/base)
		]
		append svvs/window2/template [custom-option: 'custom-value]
		append svvs/base2/template   [custom-option: 'custom-value]
	]
	leaving [
		offload [										;-- cleanup
			remove/key svvs 'base2
			remove/key svvs 'window2
		]
	]

	s1: offload/return [
		to image! view/no-wait make-face 'window
	]
	s2: offload/return [
		to image! view/no-wait make-face 'window2
	]
	s3: offload/return [			;-- can't use `shoot` here as it may cast to image on a window rather than on a base
		view/no-wait [b1: base]
		to image! b1
	]
	s4: offload/return [
		view/no-wait [b2: base2]
		to image! b2
	]
	expect [s1 = s2]
	expect [s3 = s4]

]

issue/interactive #4388 [
	"[View] `show` draws outdated window content when resizing"

	display/flags [
		do [
			resize: func [face] [
				unless face/parent/state [exit]
				system/view/auto-sync?: no
				face/size/x: face/parent/size/x - 20
				system/view/auto-sync?: yes
				show face/parent
			]
			r: [resize face face/parent/size]
		]
		below
		t1: text #608 #FD4 "left"   left   react r
		t2: text #608 #FD4 "center" center react r
		t3: text #608 #FD4 "right"  right  react r
	] 'resize
	offload [t1/parent/size/x: 500]
	s1: shoot/real t1
	s2: shoot/real t2
	s3: shoot/real t3
	t1: sync t1
	t2: sync t2
	t3: sync t3
	param [t1/size/x] [460 < 470 < 480 > 490 > 500]
	param [t2/size/x] [460 < 470 < 480 > 490 > 500]
	param [t3/size/x] [460 < 470 < 480 > 490 > 500]
	expect [x1: text [aligned left   in s1]]
	expect [x2: text [aligned center in s2]]
	expect [x3: text [aligned right  in s3]]
	param [x1/found-size/x] [ 7 <  9 < 15 > 40 > 50]
	param [x2/found-size/x] [12 < 16 < 30 > 60 > 70]
	param [x3/found-size/x] [10 < 12 < 20 > 50 > 60]
]

issue/interactive #4384 [
	"[View] `on-up` event locking on clicks"

	;; logic: 
	display [
		do [list: []]
		b1: base on-up [
			append list 'up
			view/no-wait [b2: button [unview/all]]
		]
	]
	click b1				;-- this should show b2
	b2: sync b2
	click b2				;-- this click should close b2
	click/right b2			;-- to avoid double-click event without waiting 1 sec
	click b2				;-- this should go to the background
	list: sync list
	expect [list = [up]]
]

issue/interactive #4380 [
	"[View] [Regression] Mouse over started skipping the 1st event"

	;; logic: move the mouse in and out 3 times, collect event info, check it
	display/with [
		do [list: []]
		b: area 100x100 all-over on-over [repend list [event/offset event/away?]]
	][	offset: 200x200 ]		;-- need a fixed offset for away event offset check
	
	pos: b ~at~ 40x40
	loop 3 [					;-- 1st iteration doesn't fail, but subsequent ones
		move-pointer pos					;-- generate 40x40 event
		move-pointer/async pos + 10x10		;-- /async won't register it, will be overridden by the next (by design?)
		move-pointer pos + 20x20			;-- generate 60x60 event
		move-pointer 0x0					;-- generate away event
		offload [append list '---]			;-- just a delimiter
	]

	list: sync list
	period: index? find list '---
	expect [3 * period = length? list]		;-- 3 equal results expected
	part1: copy/part list period
	part2: copy/part skip list period period
	part3: copy skip list period * 2
	expect [part1 .=. part2 .=. part3]

	bools: keep-type list logic!			;-- 2 events inside, 1 outside; repeat..
	expect [bools = reduce [no no yes  no no yes  no no yes]]

	set [ofs-40 _ ofs-60 _ ofs-away _ _] part1		;-- check all offsets
	param [ofs-40/x]         [37 < 38 < 40 > 42 > 43]
	param [ofs-40/y]         [37 < 38 < 40 > 42 > 43]
	param [ofs-60/x]         [57 < 58 < 60 > 62 > 63]
	param [ofs-60/y]         [57 < 58 < 60 > 62 > 63]
	param [ofs-away/x + 212] [-40 < -20 < 0 > 20 > 40]
	param [ofs-away/y + 232] [-50 < -30 < 0 > 30 > 50]
]

issue/interactive #4375 [						;-- /interactive because it crashes/hangs the worker
	"[CRASH] [View] When using `throw` from within an actor"
	should not crash
	should not hang								;@@ TODO: such flags should automatically make the issue non-parallelizable

	;; logic: it's important that `throw` doesn't get wrapped into worker's `try`, so it has to be an event
	output: offload [view/no-wait [button rate 10 on-time [try [throw 1]]]]
	wait 1										;-- let it process events, so the timer kicks in
	append output offload/silent []				;-- try a dummy code to detect if worker has crashed/hung
	;; "Throw Error: no catch for throw: 1" (must be distinguished from "Runtime Error 95: no CATCH for THROW")
	expect [find output "Throw Error"]
]

;@@ TODO: #4374 - what will be decided?

;@@ TODO: idk why, it gives false results every 2nd time or so... maybe catches GDI during redraw?!
; issue/interactive #4373 [		;@@ BUG: this test is dangerous to OS stability - should it be run at all?
; 	"[View] Wrecked by drawing text on your base"

; 	top-window: display/with lt: collect [
; 		keep [
; 			backdrop magenta
; 			space 2x2
; 			do [n: 0]
; 		]
; 		repeat i 450 [
; 			keep [base 30x30 white]
; 			if i % 30 = 0 [keep 'return]
; 		]
; 	][
; 		rate: 11
; 		actors: object [
; 			on-time: function [fa ev] [
; 				set 'n n + 1
; 				foreach base fa/pane [
; 					base/draw: compose [font (make font! [size: 15]) text 0x0 "ABC"]
; 				]
; 			]
; 		]
; 	]
; 	shots: []
; 	wait 5											;-- redraw is SUPER slow, at least 2 seconds - have to be sure everything is ready
; 	while-waiting 0:0:20 [true] [					;-- shoot it periodically, check for text disappearance (5 sec should be enough, but who knows...)
; 		wait 0.3									;-- not too many shots, to save RAM
; 		prev: last shots
; 		append shots shot: shoot/real/async top-window
; 		if all [prev prev <> shot] [break]
; 	]
; 	prev-1: pick tail shots -2
; 	n: sync n
; 	expect [n > 0]									;-- check that on-time was triggered at all
; 	expect [(shot = prev) and (none <> shot)]		;-- last screenshot is different => some text disappeared
; 	restart-main-worker								;@@ BUG: worker has to be restarted (or no more text drawn)
; ]

issue/interactive #4356 [
	"Newlines ignored in BUTTON text"

	;@@ TODO: rethink this all when `text` becomes smarter
	;@@ (at least it will be possible to check if glyphs are truncated or not, by their min size)

	;; logic: obtain the text geometry, check it (nr. of glyphs, their size & offset)
	display [b: button 80 wrap "█^/█^/█^/█^/█^/█^/█^/█^/█^/█"]
	s1: shoot b										;-- includes borders of unknown size
	s2: get-image-part s1  3x3  s1/size -  6x6		;-- may include borders or not
	s3: get-image-part s1 10x10 s1/size - 20x20		;-- should not include borders
	gs1: glyphs-on s1								;-- should be wrong - detects button outline
	gs2: glyphs-on s2								;-- may correctly detect text
	gs3: glyphs-on s3								;-- should be correct but truncated
	width: gs3/size/x
	height: foreach gs reduce [gs1 gs2 gs3] [		;-- correct height is the maximum one that has a correct width
		if width = gs/size/x [break/return gs/size/y]
	]
	center: 20 + gs3/size/x / 2 + gs3/offset/x
	; expect [10 = max gs3/count gs2/count]			;@@ TODO: glyphs are not counted vertically yet; use this once they are
	param [width ] [ 3 <  4 <  6  > 15  > 25 ]
	param [height] [60 < 80 < 125 > 200 > 250]
	param [center] [30 < 34 < 40  > 46  > 50 ]		;-- half of button's width = 40
]

issue/interactive #4355 [
	"[View] Tardy resize events"

	;; bug only appears while LMB is down, but during this time `do-events` won't return
	;; so I have to go all async here and rely on timeouts
	;; logic: extend the window 3 times, not releasing the LMB, let it update the view, and capture it
	top-window: display/flags/with [
		panel 100x100 gold react [face/size: face/parent/size - 20x20 wait 0.3]
	] 'resize [offset: 500x300 size: 120x120]

	psz: 100x100
	move-pointer p: 501x350
	simulate-input-raw [+ lmb]		;@@ TODO: any higher level way to do this?
	loop 3 [
		move-pointer/async p: p - 100x0
		psz: psz + 100x0
		wait 1										;-- let it finish wait 0.3 and redraw itself
		append shots: [] s: shoot/real/async top-window
		append/only boxes: [] box [size: psz at s 10x10 > 99% all gold]
	]
	simulate-input-raw [- lmb]
	s1: s2: s3: b1: b2: b3: none
	set [s1 s2 s3] shots
	set [b1 b2 b3] boxes

	expect [b1]
	expect [b2]
	expect [b3]
]

;@@ TODO: #4344 - how to *reliably* trigger this bug?

issue/interactive #4342 [
	"[View] `on-over` spams the queue when layout changes within the actor"

	;; logic: hover over the face, hold it over it still
	;; a change of some face's size in on-over handler may retrigger the on-over event (~10 times/sec)
	resize: variant 1 [[b2/size: 161x161 - b2/size]]	;-- 80->81 then 81->80
	        variant 2 [[b1/size: 161x161 - b1/size]]	;-- more sophisticated: same face's size changes
	move-pointer 0x0
	display compose/deep [
		do [list: []]
		b1: base 80x80 all-over on-over [
			append list event/offset
			(resize)
		]
		b2: base 80x80 hidden
	]
	move-pointer b1 ~at~ 40x40
	wait 0.5								;-- need to waste some time until it processes resize and re-enters on-over
	move-pointer 0x0
	list: sync list
	expect [2 = length? list]
	param [list/1/x] [38 < 39 < 40 > 41 > 42]
	param [list/1/y] [38 < 39 < 40 > 41 > 42]
]

issue/interactive #4338 [
	"Asynchronous keyboard handler discards mod keys on Windows"

	;; logic: press a key combo without delays, see if mods were registered (3-key combos can be registered hotkeys, so using just shift)
	display [
		do [list: []]
		field focus on-key [
			repend list [event/shift? event/key]
		]
	]
	sim-key/mods #" " [shift]
	list: sync list
	expect [list = reduce [yes #" "]]
]

;; #4337 - GUI console & `call` bug, too hard to test

issue/layout #4334 [
	"[VID] Incorrect height inferrence from DROP-DOWN"

	s1: shoot [drop-down]
	s2: shoot [drop-down font-size 50]
	s3: shoot [drop-down font-size 100]
	expect [s1/size/y + 20 < s2/size/y]
	expect [s2/size/y + 20 < s3/size/y]
]

issue/layout #4333 [
	"[VID] FIELD should be able to derive it's size from the font alone"

	s1: shoot [field font-size 30]
	s2: shoot [field font-size 30 ""]
	s3: shoot [field font-size 30 "x" on-created [face/text: ""]]
	expect [s1 .=. s2 .=. s3]
]

issue/interactive #4330 [
	{[View] Button "focused" indicator disintegrates after unview}

	;; this one was quite hard to catch as it does not appear in sync mode
	;; logic: worker displays a window 3 times, we interact with it, not syncing with the worker
	top-window: display/with [] [	;-- draft window - only use to repeat the geometry of the window it will show next
		offset: 0x0 size: 250x250
	]
	jobs/send-main [				;-- let the worker be unresponsive for a nick of time
		imgs: []
		loop 3 [
			view/options [
				button 200x200 focus [append imgs to image! face/parent]
			][	offset: 0x0 size: 250x250]
		]
	]
	loop 3 [						;-- asynchronously interact with the worker
		wait 0.3
		click/async 125x125
		close top-window			;-- since top-window looks the same as the new windows, an attempt to close it - closes the new windows instead
									;@@ BUG: watch out for changes in `close` - if it really closed the target window, this could not work
	]
	imgs: reduce sync imgs			;-- should contain 3 screenshots
	expect [3 = length? imgs]
	s1: imgs/1						;-- expose them as words for inspection
	s2: imgs/2
	s3: imgs/3
	expect [s1 .=. s2 .=. s3]
]

issue #4321 [
	"[VID] Shared state in LAYOUT causes stack overflows"
	should not error out			;-- serves as a test condition

	;; logic: this causes a stack overflow, error gets detected & rethrown - `should not` fails
	offload [
		unview/only view/no-wait [
			base react [
				face/text		;) define a reactive source
				layout []		;) restart process-reactors
			]
		]
	]
]

issue #4319 [
	"[View] Irregularities in event processing"
	should not crash

	ok?: no
	;; this test fails so badly that the worker's View becomes unusable and it has to be restarted!
	leaving [unless ok? [restart-main-worker]]

	variant 1 [
		;; logic: worker will process all events in any case,
		;; but I mark the exit point with `!` and check if all closing markers `-` came before it
		;; error rate is 50-70%, so with 10 attempts the probability of false success report is < 0.1%
		loop 10 [
			output: offload [			;-- `offload` will catch error reports and rethrow
				list: []
				base1: view/no-wait [base green]
				loop 5 [
					view/no-wait/options [
						base rate 10
						on-time [
							face/rate: none
							append list '-
							unview/only face/parent
						]
					] [offset: random system/view/screens/1/size - 100x100]
				]
				loop 5 [do-events]
				append list '!
				unview/all
			]
			list: sync list
			expect [list = [- - - - - !]]		;-- freeze or error will stop the loop, and we'll stop waiting
		]
	]

	variant 2 [
		;; logic: same as above
		loop 10 [
			output: offload [			;-- `offload` will catch error reports and rethrow
				list: [0]
				view/no-wait [base green]
				loop 100 [
				    view/no-wait [
				        base rate 100
				        on-time [
				            face/rate: none
				            list/1: list/1 + 1
				            unview/only face/parent
				        ]
				    ]
				]
				loop 100 [do-events]
				insert list '!			;-- replace the number so all subsequent increments will fail (they shouldn't occur)
				unview/all
			]
			list: sync list
			expect [list = [! 100]]		;-- freeze or error will stop the loop, and we'll stop waiting
		]
	]

	ok?: yes
]

;; #4312 - a mistake

issue/interactive #4306 [
	"[View] A call to `view` destroys events sometimes"

	offload [system/view/capturing?: yes]
	leaving [offload [system/view/capturing?: no]]
	display [
		do [list: []]
		b: base 80x80 magenta
		on-detect [if find [down up] event/type [append list event/type]]
		on-down [view/options [base rate 10 on-time [unview]] [offset: 99x99]]
	]
	loop 4 [click b]
	list: sync list
	expect [list = [down up  down up  down up  down up]]		;-- buggy output is: [down up up  down up up]
]

issue/interactive #4292 [
	"[View] `tight` keyword is order-dependend and little too tight"

	top-window: display [
		below
		;; logic: these 3 should be equal
		t1: text "text" blue
		t2: text "text" tight blue
		t3: text tight blue "text"
		return

		;; logic: each face's width should be at least it's height + text size
		r1: radio blue "text" tight
		c1: check blue "text" tight
		dd: drop-down blue "text" tight
		dl: drop-list blue "text" tight
		a1: area blue "text" tight
		;; didn't include `group-box` - unreliable across platforms
		return

		;; logic: compare sizes of tight and not-tight layouts
		g1: group-box blue "abc" tight [base]
		g2: group-box blue "abc" [base]
	]
	shot: shoot top-window						;-- save the artifact for nitpicky comparison

	expect [t1/size .=. t2/size .=. t3/size]

	s0: min t1/size t2/size t3/size				;-- assuming at least one layout is correct, choose it for comparison
	w: s0/x

	expect [r1/size/y + w <= r1/size/x]
	expect [c1/size/y + w <= c1/size/x]
	expect [dd/size/y + w <= dd/size/x]
	expect [dl/size/y + w <= dl/size/x]
	expect [a1/size/y + w <= a1/size/x]

	expect [g2/size .<. (g1/size + 30)]			;-- 30px = 10*2 (padding) + some extra for the rounding
	expect [80x80 .<. g1/size]					;-- should be at least of the default base size (fallback test in case `sb` is wrong)
]

;; #4291 - GC bug, irrelevant

;@@ TODO: #4280 - buttons/checkboxes/radiobuttons can be heavily decorated
;; so I'm not sure how to properly detect text alignment on them
;; this will require a reliable text detection algorithm (discard squares, rounds, ignore gradients, etc)
; issue/layout #4280 [
; 	"[View] custom font resets alignment for BUTTON, CHECK and RADIO"
; view compose [button "1" left button left font-color (system/view/metrics/colors/text) "1"]
; view compose [button "1" right button right font-color (system/view/metrics/colors/text) "1"]
; ]

;; #4276 - GUI console bug; too hard to test; not worth it

issue/interactive #4275 [
	"[View] Wheels behavior is inconsistent between Windows versions"
	;; this one fails on W7-W8, but not on W10
	;@@ TODO: it's unclear what is the "right" behavior - should be a design decision

	;; logic: roll the wheel - events should be detected
	display [
		do [list: []]
		b: base on-wheel [append list event/picked]
	]
	move-pointer b ~at~ (b/size / 2)		;-- does it matter where the pointer is?
	roll-the-wheel up
	roll-the-wheel up
	list: sync list
	expect [list = [1 1]]
]

issue/layout #4271 [
	"[GTK] NO-BUTTONS window flag has no effect"
	;@@ TODO: not sure how to test this! all platforms/desktop managers will look differently
	;@@ and will likely require per-platform test adjustments
	;; on Windows: window appears without buttons and icon, so just need to ensure it contains no small boxes

	shot: shoot/whole/with [] [size: 100x100 flags: 'no-buttons]
	b20: box [20x20 at shot]
	b15: box [15x15 at shot]
	expect [none = b20]
	expect [none = b15]
]

issue/interactive #4270 [
	"[View] Window offset reports inconsistent values"

	;; logic: drag the window right and left, check if new offset = initial offset
	display/with [
		do [list: []]
		text react [append list face/parent/offset]
	] [offset: 200x200 size: 100x50]

	;; for whatever reason, list becomes [none 200x200 200x200] here
	;; but this exact event chain is not the test subject, we only want consistency
	list: sync list
	expect [[200x200] = unique keep-type list pair!]

	offload [clear list]
	drag 250x210 [right by 100]
	list1: sync list

	offload [clear list]
	drag 350x210 [left  by 100]
	list2: sync list

	;; due to DPI rounding errors, offsets may not be exact; and 2 events may be generated
	;; this suffers from #4560 bug and reports wrong first offsets - will be tested in the relevant issue test
	ofs1: last list1
	expect [2 >= length? list1]
	param [ofs1/x] [298 < 299 < 300 > 301 > 302]
	param [ofs1/y] [198 < 199 < 200 > 201 > 202]

	ofs2: last list2
	expect [2 >= length? list2]
	param [ofs2/x] [198 < 199 < 200 > 201 > 202]
	param [ofs2/y] [198 < 199 < 200 > 201 > 202]
]

issue #4269 [
	"[Crash, View] `to-image` on some faces crashes the console"
	should not crash

	face: variant 1 ['rich-text]
	      variant 2 ['scroller]
	offload compose/deep [
		view/no-wait [f: (face) "text" blue]
		to-image f
	]
]

;; TODO: #4268 - requires an external test!

issue/interactive #4267 [
	"[GTK] shift + tab not handled properly"

	;; logic: field is focused, press a key, check output
	display [
		do [list: []]
		field focus
		on-key-down [repend list [event/shift? event/key]]
	]
	sim-key/mods tab [shift]
	list: sync list
	expect [list = reduce [yes 'left-shift yes #"^-"]]		;-- may also fail due to #4338 and yield [no #"^-"]

	;; test 2 literally follows #3168, so is not included
]

issue #4266 [
	"[GTK] crash on creating FIELD with font of zero size"
	should not crash

	;; this crashed
	variant 1 [offload [view/no-wait [field font-size 0]]]

	;; this reported an error to the console (@@ stdout or stderr? will it be caught?)
	variant 2 [
		output: offload [view/no-wait [field font-size -1]]
		expect [output = ""]
	]
]

issue/interactive #4265 [
	"[GTK] on-focus does not work on field"

	display [
		do [list: []]
		f1: field on-focus [append list 1]
		f2: field on-focus [append list 2]
	]
	click f1
	click f2
	list: sync list
	expect [list = [1 2]]
]

issue #4261 [
	"GTK: crash with styles, custom font and appending field to pane."
	should not crash

	offload [
		view/no-wait [f: field font-size 1]
		make f/font [size: 1]
	]
]

issue #4254 [
	"[View] Script Error when killing a window just shown"

	;; logic: check the output after `view` - should contain no errors
	output: offload [
		list: []
		view [base on-created [append list 'created unview]]
		probe list
	]
	expect [output = "[created]"]
]

issue/layout #4253 [
	"[View] Base started feeding on text"
	
	;; logic: just count glyphs drawn; Verdana is best for this
	variant 1 [
		shot: shoot [
			backdrop purple
			base purple cyan
			font-name "Verdana" font-size 10 "OOO OOO OOO"
		]
		glyphs: glyphs-on shot
		expect [9 = glyphs/count]
	]

	;; logic: display the box, measure it, display a bit smaller box - check if we didn't lose last letter
	variant 2 [
		offload [font1: make font! [name: system/view/fonts/fixed size: 30 color: black]]
		
		shot1: shoot [			;-- this face is to measure the proper size
			backdrop white
			b: box "A B C" left top font font1
		]
		b: sync b
		shot2: shoot (compose [	;-- now clip it by 5px
			backdrop white
			b: box (as-pair b/size/x - 5 b/size/y) "A B C" left top font font1
		])
		gs1: glyphs-on shot1
		gs2: glyphs-on shot2
		expect [3 = gs1/count]
		expect [3 = gs2/count]
	]
]

;; TODO: #4252 - requires an external test, it's too big

issue/interactive #4251 [
	"GTK: set-focus does not work"

	;; logic: click button (sets focus to base), press a key, check if registered
	display [
		do [list: []]
	    b: button "give focus to blue rectangle" [set-focus bb]
	    bb: base blue on-key-down [append list event/key]
	]
	click b
	sim-key #"a"
	list: sync list
	expect [list = [#"A"]]
]

issue/interactive #4248 [
	"parent window does not regain focus on macOS"

	;; logic: display a window; then show & close another on top of it; check if former has the focus
	display [
		do [list: []]
		b1: button 100x100 "show" focus [				;-- `focus` to capture keys
		 	view/no-wait [b2: button 50x50 "close" [unview]]
		]
		on-key-down [append list event/key]
	]
	sim-key #"a"
	list: sync list
	expect [list = [#"A"]]		;-- test if initial focus is working (sanity check)

	click b1					;-- show new window
	b2: sync b2
	click b2					;-- close new window
	
	sim-key #"b"
	list: sync list
	expect [list = [#"A" #"B"]]
]

issue/interactive #4247 [
	"[View] RADIO is toggled by default on GTK"

	;; logic: started "off" > toggle it "on" > shots of the face itself has to be different
	variant 1 [display [r: radio off]]
	variant 2 [display [r: radio]]
	s1: shoot r
	click r ~at~ [middle left + 10]
	s2: shoot r
	expect [not image-isochromatic? s1]
	expect [not image-isochromatic? s2]
	expect [s1 <> s2]		;@@ TODO: more reliable tests?
]

issue/interactive #4246 [
	"[View] RADIO emits superfluous events on Windows and macOS"

	;; logic: click, ensure it's not producing 2 events
	list: []
	push list
	display [r: radio [append list face/data]]

	click pos: r ~at~ [middle left + 10]
	list: sync list
	expect [list = reduce [true]]

	click pos
	list: sync list
	expect [list = reduce [true]]		;; shouldn't call `on-change` again when already checked
]

issue/interactive #4245 [
	"[View] CHECK treats NONE as truthy"
	;; logic: click the button, should yield false
	display [
		do [list: copy []]
		c: check data none
		b: button [c/data: none append list c/data]
	]
	click b
	list: sync list
	expect [list = reduce [false]]
]

issue/interactive #4244 [
	"[View] RADIO and CHECK faces treat only TRUE value as truthy"

	display [r: radio data 'a c: check data 'b]
	expect [r/data = true]
	expect [c/data = true]
]

;@@ TODO: #4240 - how to reliably capture that flicker?

issue/interactive #4239 [
	"[View] Transparent box turned loose doesn't honor it's parent's offset"

	;; this requires screen- (not window-) shot
	;; logic: drag the panel, check if there's a box in the expected place
	wndw: display [			;-- /tight to remove `panel` inner paddings so box doesn't stick out of it
		origin 5x5
		panel 320x300 [		;-- contain other stuff inside, so there's always a gap between it and window border - otherwise can't detect a box there
			origin 0x0 space 0x0
			sp: base magenta 20x300 loose draw [rotate 90 pen yello text 0x-20 "DRAG ME"]
			on-drag [
				face/offset/y: 0
				pr/size/x: face/parent/size/x - face/offset/x - 20 
				pr/offset/x: face/offset/x + 20 
			] 
			pr: panel 300x300 [
				origin 0x0
				box 300x300 #00FFFF01
			]
		]
	]
	shot1: capture-face/real wndw
	; expect box [where: at scrn1/wndw  offset: 0x0  size: 20x300  coverage: > 90%  color: all magenta]
	expect [box [at shot1  5x5  20x300 > 70% all magenta]]
	expect [box [at shot1 25x5 300x300  100% almost cyan]]
	drag sp [right by 200]

	shot2: capture-face/real wndw
	expect [box [at shot2 225x5 100x300 100% almost cyan]]
	;; failed test will yield that area black and cyan goes to the left 20x0-120x300
]

issue/layout #4238 [
	"GTK: draw's box and field background rendering differences between Windows and Linux"

	;; logic: whole field (not just text) should be blue, and of correct size
	;; text forced upper alignment is a limitation of Windows' native controls - I'm not checking it
	;@@ TODO: how to check rounding radius?
	shot: shoot [
		panel 100x100 red draw [box 0x0 100x100] [
			fld: field "abc" blue no-border
		]
	]

	expect [base: box [at shot center middle 100x100 > 70% all red]]
	expect [fld/size/x > 50]		;-- just a paranoid check
	expect [box [at shot/base fld/offset fld/size > 90% all blue]]
]

;@@ TODO: #4229 should be covered by base-test - port it

issue/interactive #4226 [
	"[View] FIELD is not draggable on macOS"
	should not error out

	;; logic: drag field, see if it moved
	top-window: display [size 200x50 fld: field loose]
	s1: shoot top-window
	o1: fld/offset
	expect [box [at s1 fld/offset fld/size]]

	drag fld [right by 20]
	offload [		;-- remove the (blinking) cursor from the screenshots or it will be a false positive in comparison
		fld/parent/selected: none
		loop 10 [do-events/no-wait]
	]
	s2: shoot top-window

	fld: sync fld
	expect [fld/offset/y = o1/y]
	param  [fld/offset/x - o1/x] [17 < 18 < 20 > 22 > 23]
	expect [box [at s2 fld/offset fld/size]]
]

;@@ TODO: #4213 requires specific fonts installed - how to handle?? wait until Red can be packaged with custom fonts? or ask testers to install those?

issue/interactive #4221 [		;-- /interactive to have DISPLAY
	"[View] Screenshots do not contain layered (alpha-enabled) windows"

	;; logic: make a semi-transparent window, compare built-in and Red screenshots
	display [backdrop white b: box #FF00FF50]
	s1: discard-taskbar to-image system/view/screens/1		;-- discard taskbar for auto comparison to not highlight it
	log-image s1
	s2: screenshot
	s1: capture-face/whole/with b s1		;-- exclude irrelevant areas
	s2: capture-face/whole/with b s2
	expect [s1 = s2]
]

issue/layout #4212 [
	"GTK: text face not rendering properly"

	variant 1 [
		;; logic: red text should be resized, not just moved - check for the size of the outline
		s1: shoot [origin 100x100 text 100 red "test" on-create [face/size: 180x50]]
		expect [box [at s1 100x100 180x50 > 90% all red]]
	]

	variant 2 [
		;; logic: red text should not be trimmed to text size and alignment applied
		s2: shoot [origin 100x100 t: text red "test" right]
		expect [b: box [at s2 100x100 t/size > 90% all red]]
		expect [text [aligned right in s2/b]]
	]
]

issue/layout #4211 [
	"Deep reactor works improperly with dynamically created faces"

	;; logic: `react` should copy/deep reactions, including paths - test if paths are copied
	layout lay: [b: button react [b/text]]		;-- no need to view it
	expect [reaction: react? b 'text]
	expect [not same? reaction last lay]
	expect [not same? reaction/1 first last lay]	;-- check path specifically
]

;@@ TODO: #4206 - will fix be granted for it at all?

issue/interactive #4191 [
	"GTK: face added to panel's pane appear after exiting event handler, that caused it, instead immediately."

	;; logic: face should be displayed before `showw` returns, so capture it and check for a red box

	display [
		do [
			a: make face! [
			    type: 'base color: red size: 20x20

			    showw: function [
			        parent [object!]
			        offs [pair!]
			    ] [
			        self/offset: offs
			        self/parent: parent
			        append parent/pane self
			    ]
			]
		]
	    p: panel [
	        b: button "show a" [
	        						;-- need a space (2x2) between panel edge and the box, to detect it
	            a/showw face/parent 2x2    ; square appears after wait, not before
	            i: to-image top-window
	            ; wait 3.0
	        ]
	    ]
	]
	click b
	i: sync i
	shot: capture-face/with p i							;-- get only panel from the window shot

	expect [box [at shot 2x2 20x20 100% all red]]
]

issue/compiled/interactive #4190 [
	"Crash in `fire-on-set` on facet update"
	should not crash

	exe: compile/release [
		Red [Needs: 'View]
		a: make face! [
		    type: 'base color: red size: 20x20
		    showw: function [
		        parent [object!]
		        offs [pair!]
		    ] [
		        self/offset: offs
		        self/parent: parent
		        append parent/pane self
		    ]
		]

		view [
			backdrop white
		    panel 500x500 blue [		;-- colors to make panel visible
		        button 80x20 "show a" [a/showw face/parent 30x30]
		    ]
		]
	]

	task: run exe
	settle-down 2 sec
	scrn: screenshot
	wndw: find-window-on scrn
	expect [wndw]
	expect [pnl: box [500x500 within scrn/wndw]]
	expect [btn: box [within scrn/pnl 80x20]]
	click btn
	close wndw
	; wait 1		;-- let it flush the output
	expect [not find task/output "Error"]	;-- may crash upon exiting
]

;; TODO: #4189 requires console to send the input prompt to stdout so we can check it (see 4241); otherwise, how to test it? OCR? console buffer grabbing (OS dependent)?

issue #4183 [
	"[CRASH] After using a FONT in DRAW"
	should not crash

	;; unfortunately, does not crash inside worker's try/all - so have to check the `probe`	output
	font: none			;-- make it local
	set/any 'font offload/return [
		font: make font! [name: system/view/fonts/fixed size: 20]
		view [box draw [font font text 0x0 "ABC"] rate 1 on-time [unview]]
		probe font			;-- `probe` may crash the worker, but most likely won't, because of `try`
	]
	;; `probe` outputs nothing on failure, so `font` will be unset here:
	expect [object? :font]
	expect [font/name = system/view/fonts/fixed]
	expect [font/size = 20]
]

;; TODO: for issues like #4179 - create a special category that will tell that issue is accounted for and should not have tests?

issue #4171 [
	"GTK: no error message when trying to `load` non-existent image"

	output: offload/silent [
		view [image %non-existing-image.png rate 1 on-time [unview]]
	]
	expect [
		all [
			find output "Access Error"
			find output "non-existing-image"
		]
	]
]

;; TODO: #4163 testable at all?

issue/interactive #4162 [
	"[View] `box` in a `panel` is not clipped on W7"

	;; logic: panel/box is bigger than the window, so it will be detected as window
	;; dragging of the box should not affect the detected window coordinates
	display [
		size 200x200
		at -400x-400 panel 1100x1100 [at 350x350 box loose 300x300 #ff00ff50]
	]
	settle-down 1 sec
	s1: screenshot
	box1: find-window-on s1
	expect [box1]
	param [box1/size/x] [150 < 180 < 200 > 220 > 250]

	drag box1 [left by 300]
	s2: screenshot
	box2: find-window-on s2
	expect [box2]
	param [box2/size/x] [150 < 180 < 200 > 220 > 250]
	expect [box1 = box2]
]

issue/layout #4158 [
	"[View] Rich-text tabs can be invisible"

	;; logic: extract glyph boxes, count them & check spacing
	shot: shoot [backdrop white rich-text data [font ["Verdana" 12] ["IIIIII^-IIIIII^-IIIIII"]]]
	;@@ TODO: how reliable this specific text is on other platforms, considering other fonts/metrics in use?
	;@@ should this test try to find such text that will not be tab-spaced?
	glyphs: glyphs-on shot
	expect [18 = glyphs/count]
	param [glyphs/max-distance - glyphs/min-distance] [4 < 6 < 20 > 80 > 100]		;@@ 4px is not a tab - but how big a tab should be?
]

issue #4123 [		;-- does not require any windows really
	"[VID] When `style` is set to certain type, further styles can't be defined"
	should not error out

	offload [
		style: 30%
		layout [style s1: base red style s2: base blue s1 s2]
	]
]

issue #4118 [
	"running out of memory when MOLDing or FORMing deeply nested face"
	should not error out

	;; logic: should be no error in output
	output: offload/timeout [
		layout [
			foo: base center font-size 0 rate 10
			on-time [face/rate: none probe '>>> form face probe '<<< unview]
		]
		view make face! [
		    type: 'window
		    size: foo/size + 20
		    pane: reduce collect [loop 100 [keep copy foo]]			;-- will this ever be fixed and how?
		]
	] 0:1:0

	expect [">>>^/<<<" = trim output]
	expect [not find output "Error"]
]

issue/layout #4116 [
	"[View] Regression in font application"

	;; logic: default font glyph size is ~8x9, with 30pt font ~25x29 -- big size means the font is working
	shot: shoot [
		backdrop white 
		do [f: make font! [ name: "Verdana" size: 30 ]]
		canvas: base 300x150 white draw [font f pen black text 50x50 "OOOOO"]
	]
	glyphs: glyphs-on shot
	expect [5 = glyphs/count]
	expect [glyphs/equally-sized?]
	expect [20x20 .<. glyphs/min-size .<. 30x40]	;@@ TODO: how reliable these sizes are across platforms?
]

;; #4113 - needless to test - more than covered by base-test

issue/compiled/interactive #4104 [
	"GTK: button does not respond, when compiled with libRedRT development mode (-c)"

	exe: compile/devmode [
		Red [Needs: 'View]
		view [
		    button 80x25 "test" [print ":test:"]
		]
	]

	task: run exe
	; settle-down 2 sec
	scrn: screenshot
	wndw: find-window-on scrn
	expect [wndw]
	expect [btn: box [80x25 within scrn/wndw]]
	click btn
	wait 0.3
	close wndw
	expect [task/output = ":test:^/"]
]

issue #4069 [
	"Unexpected error messages in console while running draggable window"

	output: offload [
		view/options/flags
			[h5 red 80x20 "Not frozen more" rate 5 on-time [unview]]
			[options: [drag-on: 'down]]
			'no-title
	]
	expect [not find output "Script Error"]
]

issue/compile/interactive #4061 [
	"[View] Crash & Regression: `do-event` loop stops when calling `unview`"

	variant 1 [	;; null handle
		;@@ TODO: compile a console with -r -d and run this script, see if console receives focus? or too much effort?

		;; right now I'm just compiling it and checking for 'null window handle' output
		;; logic: compile, run, do clicks, check output for warnings
		exe: compile/header/release/debug [		;-- need -d to see the warning in output
			view [
			    base 300x400 on-alt-down [
			        view/options
			        	[ base ]
			        	[ actors: object [
			        		on-unfocus: func [f e] [unview/only f]
			        	] ]
			    ]
			]
		]
		task: run exe
		; settle-down 2 sec
		s1: screenshot
		expect [wndw: find-window-on s1]
		click/right wndw
		click wndw ~at~ [left + 30]		;-- click the big base (which is partly overlapped by the small one)
		wait 0.1						;-- let it process the click
		close wndw
		; wait 0.2							;-- let it process the click

		settle-down 1 sec
		s2: screenshot
		expect [none? find-window-on s2]			;-- it should have disappeared after `unview`
		; expect [none? box [s2/wndw]]
		expect [not find task/output "WARNING"]
	]

	variant 2 [	;; crash ;; logic: capture the output, check for an error
		exe: compile/header/release/debug [
			view [
			    base 300x400 on-alt-down [
			        view/options
			        	[ base ]
			        	[ actors: object [
			        		on-created: func [f e] [unview/only f]		;-- on-created instead of on-unfocus
			        	] ]
			    ]
			]
		]
		task: run exe
		scrn: screenshot
		expect [wndw: find-window-on scrn]
		click/right wndw

		;; it may crash after right-click: look again
		settle-down 1 sec
		scrn: screenshot
		expect [wndw: box [scrn/wndw]]
		if wndw [close wndw]

		expect [not find task/output "Runtime Error"]
	]
]

issue/layout #4045 [
	"selected item in text-list hard to read (macOS)"

	;; logic: render a text that occupies big area (boxes also minimize ClearType influence)
	;;  check if text color is the same in both cases
	s1: shoot [text-list 120x50 font-name "Courier New" data ["█████"] select 1]		;-- "Courier" is very old on W7, has no box glyph
	s2: shoot [text-list 120x50                         data ["█████"] select 1]
	expect [tl1: box [120x50 within s1]]
	expect [tl2: box [120x50 within s2]]
	b1: any [							;-- try to detect a 'selected line' box
		box/image [120x10 within s1/tl1]
		box/image [120x15 within s1/tl1]
		box/image [120x20 within s1/tl1]
		box/image [120x25 within s1/tl1]
	]
	b2: any [
		box/image [120x10 within s2/tl2]
		box/image [120x15 within s2/tl2]
		box/image [120x20 within s2/tl2]
		box/image [120x25 within s2/tl2]
	]
	expect [b1]
	expect [b2]
	cs1: get-colorset b1
	cs2: get-colorset b2
	expect [cs1/1 = cs2/1]		;-- same background (cursor color)
	expect [cs1/3 = cs2/3]		;-- same text color
]

issue #4044 [
	"view opening unexpectedly on macOS"

	output: trim offload [
		win1: layout [
		    title "Win1"
		    h1 "test window 1"
		    rate 5 on-time [unview/only win1 print ["closed win1"]]
		]
		win2: layout  [
		    title "Win2"
		    h1 "test window 2"
		    rate 5 on-time [unview/only win2 print ["closed win2"]]
		]
		win3: layout  [
		    title "Win2"
		    h1 "test window 3"
		    rate 5 on-time [unview/only win3 print ["closed win3"]]
		]
		view win1
		print ["showing win2"]
		view win2
		print ["showing win3"]
		view win3
		print "Done"
	]
	;; proper order expected here:
	expect [output = "closed win1^/showing win2^/closed win2^/showing win3^/closed win3^/Done"]
]

issue/interactive #4039 [
	"GTK: crash when setting panel's size or appending it to parent's pane"
	should not crash
	should not error out

	;; logic: it swaps panel 1 for panel 2 and button tells which one is shown; click twice, check the output
	offload [
		msg: ""
		panel1: make face! [
			type: 'panel

			contents: [
				below
				text "Panel 1" 
				button 60x25 "Switch" [
					append msg "1 -> 2^/"
					remove find window/pane panel1
					append window/pane panel2
				]
			]
		]

		panel2: make face! [
			type: 'panel

			contents: [
				below
				text "Panel 2"
				button 60x25 "Switch" [
					append msg "2 -> 1^/"
					remove find window/pane panel2
					append window/pane panel1
				]
			]
		]
		window: layout []
		append window/pane layout/parent panel1/contents panel1 none
		layout/parent panel2/contents panel2 none
		view/no-wait window
		none			;-- produce less output
	]

	settle-down 1 sec
	scrn: screenshot
	expect [wndw: find-window-on scrn]
	expect [btn: box [60x25 within scrn/wndw]]
	click btn
	wait 1		;; avoid double click
	click btn
	close wndw

	msg: sync msg		;-- msg must have been updated
	expect [msg = "1 -> 2^/2 -> 1^/"]
]

issue/layout #4006 [
	"Pen 'OFF in Draw PUSH block turns the Pen off after the PUSH block on MacOS"

	;; logic: make a huge line-width so if pen is off - we know by counting red pixels
	shot: shoot [		;; coal box vs white backdrop
	    box 400x400 coal draw [
	    	line-width 10
	        pen red
	        fill-pen green
	        box 10x10 300x300
	        push [
	            pen off
	            fill-pen blue
	            box 30x30 320x320
	        ]
	        box 50x50 340x340
	    ]
	]
	param [amount-of [red on shot]] [7% < 8% < 10% > 11% > 12%]		;-- 9.5% ideally, pen off if 3%
]

issue/compile/interactive #4005 [
	"[View] regression in Windows backend"

	;; logic: it should just show 'alert' window
	exe: compile/release/debug/header [alert "test"]
	task: run exe
	scrn: screenshot
	expect [wndw: find-window-on scrn]
	close wndw
	expect [not find task/output "Runtime Error"]	;@@ TODO: make a higher level test from this?
]

issue/interactive #3980 [
	"[macOS] `layout/parent` causes access violation"
	should not crash

	display [
		do [clicked?: no]
		p: panel on-down [
			layout/parent [
				text "A: " text "B"
			] crash-box none
			clicked?: yes
		]
	    crash-box: group-box []
	]
	click p		;; worker crashed?
	expect [not crashed?]
	clicked?: sync clicked?
	expect [clicked?]
]

issue/interactive #3974 [
	"[view] not response at second run `view [button {test}]` on macOS"
	should not hang

	loop 2 [		;; 2nd iteration hangs
		display [button "test"]
		settle-down 1 sec
		expect [w: find-window-on s: screenshot]
		close w
	]
]

issue/layout #3964 [
	"Area wrapping on macOS faulty"

	offload [txt: "wrap wrap wrap wrap wrap wrap wrap wrap wrap wrap wrap"]		;-- must be longer than 100px (1 line)
	s1: shoot [size 300x200 area wrap 100 txt]
	s2: shoot [size 300x200 area wrap 200 txt on-created [face/size/x: 100]]	;-- this fails to rewrap after size change
	expect [visually-similar? s1 s2]
]

;@@ TODO: #3959 should we test for it at all?

issue/interactive #3955 [
	"`event/ctrl?` and `event/shift?` not set on `down` event"
	;; this should be better covered by the clicker test

	display [
		do [list: []]
		b: base on-down [repend list [event/flags event/ctrl? event/shift?]]
	]
	click/mods b [shift ctrl]
	list: sync list
	expect [(next list) = reduce [yes yes]]
	expect [not none? list/1]
	expect [(sort list/1) = sort [shift control down]]	;@@ TODO: generic unordered comparison of lists, with similarity metric
]

issue/interactive #3942 [
	"View: Window lost focus after a modal window close"

	;; logic: 'interactive' provides a background window; worker's window goes behind it and visually disappears - it's a bug
	w1: display [
		base cyan rate 10 on-time [
			face/rate: none
			view/flags [base red on-created [unview]] [modal]	;-- self-closing modal window
		]
	]
	settle-down 1 sec		;-- let it process events
	s: screenshot
	expect [w2: find-window-on s]
	param [w2/size/x - w1/size/x] [-10 < -1 < 4 > 10 > 20]		;-- paranoid check that it's our window that we found
]

issue/layout #3861 [
	"Height of text face not adjusting to wrapped text"

	;; logic: make 2 faces, one tall enough, one should be extended automatically - should look the same
	s1: shoot [
		backdrop white
		size 120x120
		text white 100     "111111 222222 3333333 4444444 555555 6666666"
	]
	s2: shoot [
		backdrop white
		size 120x120
		text white 100x100 "111111 222222 3333333 4444444 555555 6666666"
	]
	; expect [visually-similar? s1 s2]
	expect [s1 = s2]
]

issue/layout #3847 [
	"[draw][text] text size in draw is different when face color is specified"

	offload [
		l1: layout [backdrop white size 200x200]
		f1: make face! [
			type: 'base
			offset: 0x0
			size: 160x160
			color: white
			draw: [text 0x0 "Hi there"]
		]
		append l1/pane f1

		l2: layout [backdrop white size 200x200]
		f2: make face! [
			type: 'base
			offset: 0x0
			size: 160x160								;-- no color here
			draw: [text 0x0 "Hi there"]
		]
		append l2/pane f2

		l1: view/no-wait l1
		l2: view/no-wait l2
	]

	s1: shoot l1
	s2: shoot l2
	expect [s1 = s2]									;@@ TODO: highlight differences in images in UI
]

;; Camera doesn't capture images #3839 -- need a cam to reproduce

issue/layout #3838 [
	"Custom tab of the Tab-panel can't be selected on start"

	s: shoot [tab-panel 120x140 ["a" [base 80x80 magenta] "b" [base 80x80 cyan]] with [selected: 2]]
	expect [box [80x80 within s > 95% all cyan]]
]

;; @@ TODO: #3835 -- hard to reliably detect those little boxes: what size they are? is it always the same?

issue #3832 [
	"[VID] Cannot give multiple flags in VID dialect"

	flags: offload/return [
		flags: none
		view [fld: field all-over no-border rate 10 on-time [flags: fld/flags unview]]
		flags
	]
	expect [(sort flags) = sort [all-over no-border]]
]

;; @@ TODO: #3827 - not sure what result we should consider valid - 2nd or 3rd group of the four

issue/interactive #3823 [
	"[View] `event` gets corrupted inside an actor by another `view []`"

	;; logic: save event/offset before & after the `view`, compare
	display [
		do [list: []]
		b: base 80x80 cyan on-down [
			append list event/offset
			view [base purple rate 10 on-time [unview]]
			append list event/offset
		]
	]

	click b
	wait 0.5		;-- let `view` finish and add another offset
	list: sync list
	expect [list/1 = list/2]
	param [list/2/x] [33 < 36 < 40 > 44 > 47]		;-- becomes 0x0 on failure
	param [list/2/y] [33 < 36 < 40 > 44 > 47]
]

issue/interactive #3822 [
	{[View] `modal` flag doesn't work with layered windows}

	;; logic: register events after opening the modal child windows, check if they are ignored
	display [
		do [list: []]
		b: base 80x80 #FF000020
		on-created [ofs: face/offset + face/parent/offset siz: face/size]
		on-down [
			append list 'down
			view/options/no-wait compose [
				base 80x80 #00FF0020 on-down [unview]
			] [set 'ofs offset: ofs - (siz * 1x0) - 30x0]
		]
	]
	click b
	wait 1				;-- do not make a double click
	click b
	wait 1
	click b				;-- click 3 times instead of 2 to account for #4306
	list: sync list
	expect [list = [down]]
]

;; #3818 - dismissed for not being reproducible

issue/interactive #3815 [
	"[View] Scroller won't move by steps smaller than 1%"

	;; logic: click scroller multiple times, see if it moves
	top-window: display [scro: scroller with [steps: 1.0 / 101]]
	s1: shoot top-window
	loop 20 [click scro ~at~ [right - 5]]
	s2: shoot top-window
	expect [s1 <> s2]		;@@ TODO: check the resulting scroller offset as well?
]

issue/layout #3814 [
	"[View] rich-text metrics get corrupted by introducing new facets"

	offload [
		extend system/view/VID/styles [
			style1: [template: [type: 'rich-text junk1: junk2: 1]]
			style2: [template: [type: 'rich-text junk1: 1]]
			style3: [template: [type: 'rich-text line-spacing: handles: none junk1: junk2: 1]]
		]
		list: []
 	]
 	s0: shoot [rich-text 100x100 "A^/A^/A^/A^/A^/A" cyan on-created [append list size-text/with face "A"]]
 	s1: shoot [style1    100x100 "A^/A^/A^/A^/A^/A" cyan on-created [append list size-text/with face "A"]]
 	s2: shoot [style2    100x100 "A^/A^/A^/A^/A^/A" cyan on-created [append list size-text/with face "A"]]
 	s3: shoot [style3    100x100 "A^/A^/A^/A^/A^/A" cyan on-created [append list size-text/with face "A"]]
 	list: sync list

 	expect [list/1 = list/2]							;-- all glyphs of equal size?
 	expect [list/1 = list/3]
 	expect [list/1 = list/4]
 	param [list/2/x] [5 < 7 <  9 > 12 > 15]				;-- sane glyph size?
 	param [list/2/y] [6 < 9 < 11 > 14 > 18]
 	expect [s0 = s1]									;-- typesetting correct on all images?
 	expect [s0 = s2]
 	expect [s0 = s3]

 	offload [											;-- clean up
 		remove/key system/view/VID/styles 'style1
 		remove/key system/view/VID/styles 'style2
 		remove/key system/view/VID/styles 'style3
 	]
]

issue/layout #3813 [
	"[Draw] ignores matrix commands on rich-text surface"

	template: [
		white 100x100 draw [
			pen blue
			clip 0x0 50x50
			translate 10x10
			rotate 10 0x0
			scale 2 2
			box 0x0 60x20
			text 0x0 "X"
		]
	]

	s1: shoot (compose [base (template)])			;-- I'm not testing `base` here, supposing that it's working
	s2: shoot (compose [rich-text (template)])
	expect [visually-similar? s1 s2]
]

issue #3812 [
	"[View] `size-text/with` ignores `/with` when used on rich-text"

	offload [
		r: rtd-layout ["ab^/cd"]
		sz1: size-text r
		sz2: size-text/with r "a"
		sz3: size-text/with r "abcdefgh"
		sz4: size-text/with r "a^/^/b^/^/c^/^/d"
	]
	sz1: sync sz1
	sz2: sync sz2
	sz3: sync sz3
	sz4: sync sz4
	expect [sz1 <> sz2]
	expect [sz1 <> sz3]
	expect [sz1 <> sz4]
	expect [sz2/y = sz3/y]
	param [sz1/y] [15 < 18 < 22 > 26 > 30]		;-- should be 2 lines
	param [sz2/y] [ 7 <  9 < 11 > 13 > 15]		;-- 1 line
	expect [sz4/y > 50]
]

;@@ TODO: #3810 requires getting OS default color for tab-panel
;@@ TODO: #3809 awaits design decisions - what will the proper behavior be?
;@@ TODO: #3808 awaits design decisions - window/selected or panel/selected?
;@@ TODO: #3803 awaits design decisions - relation between drop-down/selected and user-defined values

issue #3801 [
	"view image crash on macOS"
	should not crash

	offload/timeout [
		img: make image! 600x400
		count: 0
		loop 100 [
			view/no-wait compose [image (img)]
			wait 0.01 unview
			count: count + 1
		]
	] 0:1:0
	count: sync count
	expect [count = 100]
]

issue/interactive #3795 [
	"[View] `on-menu` `event/offset` is not DPI-aware"

	;; logic: compare click and menu-click offsets, should be equal
	display [
		do [list: []]
	    b: box 100x100 #EE00EE20 with [menu: ["a"]]
	    on-down [append list event/offset]
	    on-menu [append list event/offset]
	]
	click b
	click/right/async b							;-- invoke menu
	click b ~at~ [center + 7x7]					;-- click the (only) item

	list: sync list
	expect [2 = length? list]
	expect [list/1 = list/2]
]

issue/interactive #3794 [
	"[View] Menu mutation bugs future event offsets"

	;; logic: make 2 clicks, compare offsets
	display [
		do [list: []]
		b: box #EE00EE20 with [menu: []]
		on-alt-down [
		    append list event/offset
		    change face/menu reduce [form #"A" - 1 + random 26]
	    ]
	]
	pt1: b ~at~ [center]			;-- save the points as the client offset changes (see issue comment)
	pt2: pt1 + 7x7
	click/right/async pt1 wait 1
	click pt2 wait 1
	click/right/async pt1 wait 1
	click pt2 wait 1

	list: sync list
	expect [2 = length? list]
	expect [list/1 = list/2]
]

issue/interactive #3793 [
	"[View] Unstoppable wheel!!"

	;; logic: do wheel events, see that they are not triggered
	face:
		variant 1 [[area 100x20 "a^/b^/c^/d^/e"]]
		variant 2 [[drop-list 100x20 data ["a" "b" "c" "d" "e" "f"]]]
		variant 3 [[drop-down 100x20 data ["a" "b" "c" "d" "e" "f"]]]
		variant 4 [[text-list 100x20 data ["a" "b" "c" "d" "e" "f"]]]
	display compose [
		do [
			list: []
			insert-event-func evfun: func [_ ev] [if ev/type = 'wheel ['stop]]
		]
		(face) focus on-wheel [append list "ROLLED OVER"]
	]
	leaving [offload [remove-event-func :evfun]]		;-- cleanup

	roll-the-wheel up
	list: sync list
	expect [empty? list]
]

issue/layout #3789 [
	"[Draw] `qcurv` doesn't work, at all"

	;; it's hard to test that the result is correct without embedding images..
	;; logic: simply compare it to the buggy (box-like) result (see the issue description)

	bug-box: shoot [
		base 250x250 draw [
			scale 10 10 pen linear cyan purple
			shape [move 5x5 line 20x5 20x20 5x20]
		]
	]
	bug-curv: shoot [
		base 250x250 draw [
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurve 20x5 20x20 qcurv 5x20 line 5x5]
		]
	]

	curv1: shoot [
		base 250x250 draw [		; feeding a single point
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurv 20x5 qcurv 20x20 qcurv 5x20 qcurv 5x5 move 5x5]
		] 
	]
	curv2: shoot [
		base 250x250 draw [		; feeding pairs of points
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurv 20x5 20x20 qcurv 5x20 5x5 move 5x5]
		] 
	]
	curv3: shoot [
		base 250x250 draw [		; feeding a bunch
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurv 20x5 20x20 5x20 5x5 move 5x5]
		] 
	]

	curv4: shoot [
		base 250x250 draw [
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurve 20x5 20x20 qcurv 5x20 qcurv 5x5]
		] 
	]
	curv5: shoot [
		base 250x250 draw [
			scale 10 10 pen linear cyan purple 
			shape [move 5x5 qcurve 20x5 20x20 qcurv 5x20 5x5]
		] 
	]

	expect [curv1 = curv2]
	expect [curv1 = curv3]
	expect [curv1 <> bug-box]
	expect [curv4 = curv5]
	expect [curv4 <> bug-curv]
]

;; #3779 -- produced sounds can't be tested

issue/interactive #3776 [
	"Buttons image property doesn't update on screen"

	top-window: display [
		do [
			img: system/words/draw 64x64 [		;-- workaround for #4312
				fill-pen pattern 32x32 [
					scale 4 4 pen off
					fill-pen black box 0x0 4x4 box 4x4 8x8
					fill-pen white box 0x4 4x8 box 4x0 8x4
				]
				box 0x0 64x64
			]
			more: reduce [
				make image! 64x64
				none
			]
		]
		b: button img [face/image: take more]
	]
	s1: shoot top-window
	click b
	s2: shoot top-window
	click b
	s3: shoot top-window
	expect [not visually-similar? s1 s2]
	expect [not visually-similar? s1 s3]
]

issue/layout #3765 [
	"[CRASH] on `focus` being set inside `layout`"
	should not crash

	i1: shoot [do [layout [button focus]]]
	expect [image? i1]				;-- won't be no image if crashes
]

issue #3762 [
	"[CRASH] in `layout/parent/only`"
	should not crash

	output: offload [
		w: view/no-wait []
		layout/only/parent [field] w none
	]
	expect [not find output "Error"]
]

issue/layout #3760 [
	"Height of text face isn't correctly calculated"

	s1: shoot [text "one^/two^/three^/four" 200 red]
	s2: shoot [text "one^/two^/three^/four" 200 red white]
	; expect [s1/size = s2/size]			;-- 'white' should not affect the size
	;@@ it affects it though, see issue comment; let it produce a warning:
	param [s1/size/y - s2/size/y] [-8 < -2 < 0 > 2 > 8]
]

issue/compiled #3753 [
	"[View] CRASH in `set-focus` with field & area on W8+"

	exe: compile/header/release/debug
		variant 1 [ [view [a: area  on-created [set-focus a] rate 10 on-time [quit]]] ]
		variant 2 [ [view [a: field on-created [set-focus a] rate 10 on-time [quit]]] ]
	task: run/wait exe 10
	expect [not find task/output "Error"]
]

issue/layout #3751 [
	"black color rich-text with fill-pen does not draw correctly"

	;; logic: draw 3 chars, see that they are drawn (buggy version is all white)
	s: shoot/tight [
		rich-text draw compose [
			fill-pen white
			text 10x10 (rtd-layout [black "█ █ █"])
		]
	]
	gs: glyphs-on s
	expect [3 = gs/count]
]

issue/interactive #3741 [
	"[View] Regression: `on-over` gets an invalid `event/offset` when `away?`"

	;; logic: track the offsets of over event
	move-pointer 0x0				;-- let it not be under the base initially
	display [
		do [list: []]
		b: base 100x100 on-over [append list event/offset]
	]
	move-pointer pos: b ~at~ [center]
	move-pointer pos - 100x0
	list: sync list
	expect [2 = length? list]
	param [list/1/x] [ 45 <  47 <  50 >  53 >  55]
	param [list/1/y] [ 45 <  47 <  50 >  53 >  55]
	param [list/2/x] [-55 < -53 < -50 > -47 > -45]
	param [list/2/y] [ 45 <  47 <  50 >  53 >  55]
]

issue/compiled #3735 [
	"[Crash] in RTD-LAYOUT after RECYCLE"
	should not crash

	exe: compile/devmode/header [
		recycle
		rtd-layout reduce [""]
	]
	task: run/wait exe 5
	expect [not find task/output "Error"]
]

issue/interactive #3730 [
	"Can't change attributes of text in VID box"
	
	;; logic: display invisible text, make it visible, check the attributes of it
	display [
		backdrop black
		b: box  "| | |"   font-color black font-size 30
		t: text "| | | |" font-color black font-size 30
	]
	offload [
		b/font/size:  t/font/size: 10			;-- reduce size rather than grow (face size won't grow anyway)
		b/font/color: t/font/color: green
	]
	sb: shoot/real b				;-- use real appearance else it gives correct to-image on W7 whilst being displayed incorrectly
	st: shoot/real t
	gs-b: glyphs-on sb
	gs-t: glyphs-on st
	expect [3 = gs-b/count]
	expect [4 = gs-t/count]
	param [gs-b/min-size/y] [9 < 11 < 13 > 15 > 17]		;-- it's 38px with font=30, 13px with font=10
	param [gs-t/min-size/y] [9 < 11 < 13 > 15 > 17]
]

;; #3731 - problem was in react, not in View
;; #3726 - see test-focus-events.red custom test

;; @@ TODO: #3727 - requires some fonts installed on the system, how to automate?
;; @@ TODO: #3726 - requires some fonts installed on the system, how to automate?

issue/layout #3725 [
	"[View] `draw [text ...]` on layered base face applies DPI-factor twice"

	;; logic: display text using various methods, compare
	;; this also suffers from #4253 bug, displaying "A" or "AB" instead of "ABC"
	init: [
		backdrop white
		;; use `set` or it will crash when syncing the font back
		do [set 'font1 make font! [name: system/view/fonts/fixed size: 30 color: black]]
	]
	;; using shoot/real as `to-image` conceals the double zoom effect!
	gs1: glyphs-on s1: shoot/real (compose [
		(init)
		base 120x80 "A B C" white left top font font1
	])
	gs2: glyphs-on s2: shoot/real (compose [
		(init)
		base 120x80 white draw [font font1 text 0x0 "A B C"]
	])
	gs3: glyphs-on s3: shoot/real (compose [
		(init)
		base 120x80 white draw [text 0x0 "A B C"]
	])
	gs4: glyphs-on s4: shoot/real (compose [
		(init)
		box 120x80 "A B C"       left top font font1
	])
	gs5: glyphs-on s5: shoot/real (compose [
		(init)
		box 120x80        draw [font font1 text 0x0 "A B C"]
	])
	gs6: glyphs-on s6: shoot/real (compose [
		(init)
		box 120x80        draw [text 0x0 "A B C"]
	])

	expect [visually-similar? s1 s2]		;-- base: text vs draw
	expect [visually-similar? s4 s5]		;-- box:  text vs draw
	expect [visually-similar? s1 s4]		;-- base vs box text
	expect [visually-similar? s2 s5]		;-- base vs box draw
	expect [visually-similar? s3 s6]		;-- base vs box draw

	expect [3 = gs1/count]			;-- all letters were displayed, none eaten?
	expect [3 = gs2/count]
	expect [3 = gs3/count]
	expect [3 = gs4/count]
	expect [3 = gs5/count]
	expect [3 = gs6/count]
	
	;; proper big height: 26px, small (draw default): 10px
	param [gs1/min-size/y] [20 < 22 < 26 > 30 > 32]
	param [gs2/min-size/y] [20 < 22 < 26 > 30 > 32]
	param [gs3/min-size/y] [ 7 <  8 < 10 > 12 > 13]
	param [gs4/min-size/y] [20 < 22 < 26 > 30 > 32]
	param [gs5/min-size/y] [20 < 22 < 26 > 30 > 32]
	param [gs6/min-size/y] [ 7 <  8 < 10 > 12 > 13]
]

issue/interactive #3724 [
	"[View] `screen/*/font` assignment breaks the code flow"

	;; logic: check that on-created event doesn't fork with screen/font: assignment
	display [
		do [list: ""]
		style puddle: base on-created [
			append list ">"
			system/view/screens/1/font: make font! []
			append list "<"
		]
		puddle puddle
	]
	expect [list = "><><"]			;-- ">><<" is a bug
]

issue/interactive #3723 [
	"[View] leftover font objects are spawning faces uncontrollably"

	;; logic: create 2 bases, verify that only 2 were created
	offload [
		system/view/VID/styles/bomb: [
			template: [
				type: 'base
				font: make font! []
				actors: [
					on-created: func [f] [
						append list "+"
						system/view/screens/1/font: copy f/font  ;-- this is the culprit line
					]
					on-down: function [f e] [
						append f/parent/pane make-face 'bomb
					]
				]
			]
		]
	]
	leaving [offload [remove/key system/view/VID/styles 'bomb]]	;-- cleanup

	top-window: display [
		size 200x100
		do [list: ""]
		b: bomb cyan 50x50
	]
	click b
	close top-window
	list: sync list
	expect [list = "++"]
]

issue/interactive #3722 [
	"[View] `event/window` returns a wrong face under very specific circumstances"
	
	display [
		do [list: []]
		b: base #FF007001 on-down [append list event/window/type]
	]
	click b
	list: sync list
	expect [list = [window]]		;-- [base] is a bug
]

;; #3714 - should be tested in quick-test as a general regression test

issue #3713 [
	"Malignant output from react/link"

	;; logic: make it throw an error during react/linked reaction; check the output length
	output: toolset/offload/silent [
		view [
			base with [
				react/link/later func [f p] [f/offset/y: p/offset/y load ")"] [self parent]
			] rate 3 on-time [unview]
		]
	]
	param [length? output] [50 < 200 < 600 > 1000 > 1200]
]

issue/interactive #3693 [
	"[View] actors format inconsistency between VID and make-face"

	;; logic: track events, 'actors' type (object!) & contents (should merge template & layout)
	offload [
		system/view/VID/styles/square3693: [
			template: [
				type: 'base
				color: green
				size: 100x100
				actors: [on-created: func [f e] [append list 'created!]]
			]
		]
		down-handler: function [f e] [
			append append append list
				'clicked!
				type?/word f/actors
				sort words-of f/actors
			append f/parent/pane f2: make-face/offset 'square3693 f/offset + 110x0
			append append list
				type?/word f2/actors
				sort words-of f2/actors
		]
	]
	leaving [offload [remove/key system/view/VID/styles 'square3693]]		;-- cleanup

	display [
		size 400x150
		do [list: []]
		sq: square3693 on-down :down-handler
	]
	click sq
	list: sync list
	expect [list = [created! clicked! object! on-created on-down created! object! on-created]]
]

issue/layout #3691 [
	"Color disabled in rich-text data"

	s: shoot [rich-text 40x40 data [s [red " █ █"]]]
	param [amount-of [red on s]] [1% < 1.5% < 2.5% > 5% > 6%]	;-- will be black if buggy
]

issue/interactive #3682 [	;-- interactive to make it exclusive so no more windows are open
	"[View] `do-events` isn't considering the absence of windows"

	output: offload/silent [
		unview/all
		do-events
	]
	expect [not find output "Error"]
]

issue/interactive #3677 [		;@@ TODO: finish this one - it so heavily suffers from #4291 that it's impossible to test!!
	"image doesn't move with group-box"

	;; logic: move the group-box, see if the sub-face has moved
	offload [img: make image! reduce [100x100 red]]
	face: variant 1 [[image img]]
	      variant 2 [[base #FF000001]]
	top-window: display compose/deep [
		backdrop white  size 400x200
		gb: group-box loose [b: button [gb/offset/x: gb/offset/x + 100] i: (face)]
	]
	s: shoot/real top-window
	expect [box [around s/i > 90% almost red]]
	click b
	i2: sync i
	s: shoot/real top-window
	expect [b2: box [around s/i2 > 90% almost red]]
	expect [b2/offset/x > 200]				;-- ensure the test system didn't degrade and adds `gb` offset to `i` offset
]

issue #3675 [
	"[View] `to-image` can't shoot an image face"

	;; not using `shoot` here as it's not guaranteed to resort to `to-image`
	s: offload/return [
		to image! view/no-wait [backdrop black image 50x50 rate 3 on-time [unview]]
	]
	expect [s]
	expect [box [50x50 within s 100% all white]]
]

issue #3668 [
	"VID `default` overruns provided text"
	
	txt: offload/return [
		view [
			field "Provided" default 'Default
			rate 3 on-time [txt: face/text unview/only event/window]
		]
		txt
	]
	expect [txt = "Provided"]
]

issue #3661 [
	"Screen grabbing isn't DPI aware yet"
	
	sz1: offload/return [i: to image! system/view/screens/1  i/size]
	sz2: units-to-pixels system/view/screens/1/size
	expect [sz1 - sz2 .<. 5x5]		;-- allow some rounding error
]

issue/interactive #3656 [			;-- planned to be fixed in 0.9.x
	"access violation on setting PANE facet to non-SERIES! value"
	should not crash	;@@ TODO: should this produce an automatic main-worker/alive? test at the end ? (in case `click` does not detect it)
						;@@ TODO: also ensure all crash-tests run in an exclusive mode (not parallelized)

	display [b: button [face/pane: 'boom]]
	click b
]

issue/interactive #3619 [
	"access violation on probing of EVENT/PICKED from incorrectly specified MENU facet"
	should not crash

	variant 1 [
		display [
		    p: panel
		        with [menu: ["abcdef"]]
		        on-menu [r: event/picked]
		]
		click/right/async p
		click p ~at~ [center + 7x7]
	]
	variant 2 [
		top-window: display/with [
			at 0x0 b: base
		    on-menu [r: event/picked]
		][	menu: ["abcdef"]
		]
		click b ~at~ [left top + 20x-10]		;@@ TODO: how portable this layout is? will menu item always stay above the base?
	]
	r: sync r
	expect [none? r]
]

;@@ TODO: if #3580 fix produces any new tests, add them here

;; #3576 does not require a test

issue #3564 [
	"DRAW re-orders BOX coordinates"

	spec: [box 10x0 20x10 box 20x0 10x10]
	x: offload/return compose/only [
		draw 100x100 x: (spec)
		x
	]
	expect [x = spec]		;-- becomes 10x0 20x10 in buggy version
]

issue/interactive #3563 [
	"Line-breaks in area on Windows add to calculated length 1 for each line-break"

	;; logic: select till the end; last char's index should equal text length
	variant 1 [
		top-window: display [
			do [sel: none]
			ar: area "1^/2^/3" 100x100 on-select [sel: face/selected]
		]
		drag ar ~at~ [top + 5] ar ~at~ [bottom - 10]	;-- multiline selection
		sel: sync sel
		expect [sel/2 = length? "1^/2^/3"]
	]

	;; logic: select till the end; last char's index should equal text length
	variant 2 [
		top-window: display [
			do [sel: none]
			ar: area "12345^/" 100x100 on-select [sel: face/selected]
		]
		click/double ar ~at~ [top left + 7x7]	;-- select word only
		sel: sync sel
		expect [sel = 1x5]
	]
]

;; #3557 does not require a test
;; #3546 - dismissed

issue/layout #3545 [
	{GUI displays the word "Button" after a checkbox on macOS}

	s1: shoot [check 100]
	s2: shoot [check 100 ""]
	expect [s1 = s2]
]

issue/interactive #3543 [
	"odd behavior of the layout on macOS"

	;; logic: click the button 2 times - if it becomes obstructed, it won't react the 2nd time
	display [
		do [list: []]
		tools: panel []
		return
		at 0x50 area: area 210x200
		at 150x0 h: button "hide" [
			append list h/text
			tools/visible?: not tools/visible?
			either h/text = "hide" [
				area/offset/y: area/offset/y - 50
				tools/parent/size/y: tools/parent/size/y - 50
				h/text: "show"
			][
				h/text: "hide"
				area/offset/y: area/offset/y + 50
				tools/parent/size/y: tools/parent/size/y + 50
			]
		]
	]
	click h
	wait 1			;-- no double clicks!
	click h
	list: sync list
	expect [list = ["hide" "show"]]
]

issue/interactive #3542 [
	"The rich-text face is not updated when changing its text facet"

	;; logic: trigger face changes by moving pointer; verify that they occurred
	move-pointer 0x0
	display [
		t: rich-text "Simple example here" 
	    with [data: compose [1x6 bold 16x7 250.0.0]] 
	    on-over [
	        change/part at face/text 16 pick ["away" "over"] event/away? tail face/text 
		]
	]
	s1: shoot t
	move-pointer t ~at~ [center]
	s2: shoot t
	move-pointer 0x0
	s3: shoot t
	expect [s1 <> s2]
	expect [s1 <> s3]
	expect [s2 <> s3]
]

;;@@ TODO: 3530 - this one will be hard to test automatically; may require recording & replay of user input, and analysis of all frames

;; #3526 - I couldn't reproduce the bug with any build

;; #3504 - a draw issue, should be tested in quick-test

issue #3486 [
	"Smooth cubic bezier `curv` (in `shape` dialect) after another `curv` not smooth"

	i: draw 250x250 [
		scale 0.5 0.5
		line-width 10
		shape [
			move 10x10
			curv 0x500 250x250 250x490 490x250 
			move 10x10
		] 
	]
	i1: get-image-part i xy: 120x80  200x120 - xy		;-- should contain the curve
	i2: get-image-part i xy: 135x125 180x250 - xy		;-- should be white
	i3: get-image-part i xy: 150x165 250x250 - xy		;-- should be white
	expect [10% < amount-of [somewhat black on i1]]
	expect [80% < amount-of [all white on i1]]
	expect [100% = amount-of [all white on i2]]
	expect [100% = amount-of [all white on i3]]
]

issue/layout #3473 [
	"About diaglog with wrong background in Red gui console"

	shot: shoot/real [
		size 200x200 backdrop coal
		text font-color white "x" 150x150
	]
	expect [99% < amount-of [coal on shot]]
]

issue/interactive #3466 [
	"invalid window positioning after it has been minimized+restored"

	top-window: display [backdrop black image]
	s1: shoot/real top-window
	minimize top-window
	restore top-window
	s2: shoot/real top-window
	expect [s1 = s2]
]

issue/interactive #3465 [
	"transparent `base` won't render text with `to-image`"

	top-window: display [
		backdrop white b: box glass black "text text"
	]
	img: offload/return [to image! top-window]		;-- use raw `to-image` instead of `shoot` here
	expect [image? :img]
	expect [not image-isochromatic? img]
]

issue/layout #3448 [
	"VID: system colors override in a panel"

	;; logic: compare colorsets within a panel and without it
	s1: shoot [text font-name "Verdana" font-size 20 "ooo u ooo oo ooo u oooo"]
	g1: glyphs-on s1
	expect [17 = g1/count]

	s2: shoot [panel [text font-name "Verdana" font-size 20 "ooo u ooo oo ooo u oooo"]]
	g2: glyphs-on s2
	expect [17 = g2/count]

	s3: shoot [
		do [clr: system/view/metrics/colors/text]
		panel [text clr font-name "Verdana" font-size 20 "ooo u ooo oo ooo u oooo"]		;-- both text and background of the same color
	]

	expect [    matching-colorsets? s1 s2 10%]		;-- fails if text color is not applied inside a panel
	expect [not matching-colorsets? s2 s3 10%]		;-- fails if background is not applied
]


;; #3446 - covered by test #3563

issue #3445 [
	"draw `line` gradient issues"

	;; logic: rely on working `shape` sub-dialect
	i1: draw 200x200 [line-width 20 pen linear blue red        line 9x9 190x190  circle 99x99 90 ]
	i2: draw 200x200 [line-width 20 pen linear blue red shape [line 9x9 190x190] circle 99x99 90 ]

	i3: draw 200x200 [line-width 20 pen linear blue red circle 99x99 40        line 9x9 190x190  ]
	i4: draw 200x200 [line-width 20 pen linear blue red circle 99x99 40 shape [line 9x9 190x190] ]

	i5: draw 250x250 [line-width 20 pen linear cyan purple box 10x10 50x50            curve 10x10 240x10 240x240 ]
	i6: draw 250x250 [line-width 20 pen linear cyan purple box 10x10 50x50 shape [move 10x10 curv 240x10 240x240 move 10x10] ]

	i7: draw 250x250 [line-width 20 pen linear cyan purple            curve 10x10 240x10 240x240 ]
	i8: draw 250x250 [line-width 20 pen linear cyan purple shape [move 10x10 curv 240x10 240x240 move 10x10] ]

	expect [i1 = i2]
	expect [i3 = i4]
	expect [i5 = i6]
	expect [i7 = i8]
]

issue #3433 [
	"draw `fill-pen` isn't being reset properly"

	slice: [		;-- this should not affect the final result (it does on the buggy builds)
		fill-pen red
		fill-pen radial glass blue glass
	]
	proto: [
		pen off
		scale (s: 20) (s)

		(slice)
		fill-pen red
		box 0x0 (b / s)
		fill-pen radial glass blue glass
		box 0x0 (b / s)
	]
	s1: draw b: 200x200 compose/deep proto			;-- with the slice
	slice: []
	s2: draw b: 200x200 compose/deep proto			;-- without it
	expect [s1 = s2]
]

issue #3432 [
	"regression: default `draw` matrix is not an identity matrix"

	;; logic: red box should totally overlap the blue box, so no blue color is expected
	im: draw 400x400 [line-width 5 pen blue box 10x10 190x190 reset-matrix pen red box 10x10 190x190]
	expect [0% = amount-of [blue on im]]
]

issue/interactive #3430 [
	"invisible window appears when using the alpha channel"
	;@@ TODO: this test is only relevant to W7, and Alt+F4 may not make any sense on other platform
	;;        so either use platform-specific key combos or automatically succeed on those platforms

	top-window: display [base 100x100 focus #FF00FF]
	s1: shoot/real/whole top-window
	sim-key/mods F4 [alt]
	top-window: sync top-window
	expect [none? top-window/state]			;-- closed after Alt-F4 ? (should always succeed)
	
	top-window: display [base 100x100 focus #FF00FF01]
	s2: shoot/real/whole top-window
	sim-key/mods F4 [alt]
	top-window: sync top-window
	expect [none? top-window/state]			;-- closed after Alt-F4 ? (detects the bug)
	
	expect [visually-similar? s1 s2]		;-- this may also detect the inactive title bar thing; or may not - depends on title bar colors
]

issue/interactive #3421 [
	"read-clipboard stops working after view/unview"

	;; logic: second read-clipboard fails in the issue report
	r1: offload/return [
		write-clipboard "test"
		read-clipboard
	]
	display [b: button "ok" [unview]]
	click b
	r2: offload/return [read-clipboard]
	expect [r1 = "test"]
	expect [r2 = "test"]
]

issue/interactive #3420 [
	"Bug: set-focus crashes console and compiled script, when closing popup window"
	should not crash

	;; I've no idea why this layout is so complex, but I couldn't reproduce the crash on W7 in old builds
	display [
	    panel [
	        f1: field 200x20 "Hello, I am assisting with crash test"
	        return
	        b1: button "Press Me First" [
	            view/no-wait [
	                b3: button "First step to Crash" [
	                    set-focus f1
	                    unview
	                ]
	            ]
	        ]
	        b2: button "Press Me Second" [
	            view/no-wait [
	                text "Do you think this will cause crash?"
	                return
	                b4: button "Yes" [
	                    unview
	                ]
	            ]
	        ]
	    ]
	]
	click b1
	b3: sync b3
	click b3
	click b2
	b4: sync b4
	click b4		;-- during this it's supposed to crash...
]

;; #3415 - unfortunately the author never expressed what "image loses something" means.. can't test it
;; #3401 - dismissed; never reproduced

issue/interactive #3400 [
	"field does not work properly when view its parent window twice"

	offload [
		pin: ""
		pin-dlg: has [dlg][
			dlg: layout [
				pin-show: field "" btn: button "Add" [
					append pin-show/text "*"
					pin: copy pin-show/text
				]
			]
			wnd: view/no-wait/flags dlg 'modal
		]
		pin-dlg
	]
	click btn: sync btn
	s1: shoot/real pin-show		;-- this should have a single asterisk
	close wnd: sync wnd

	offload [
		clear pin
		pin-dlg
	]
	click btn: sync btn
	s2: shoot/real pin-show		;-- this should have two asterisks
	close wnd: sync wnd
	pin: sync pin

	expect [s1 <> s2]
	expect [pin = "**"]
]

issue #3394 [
	"Copy part of a face gives an error"	;-- incorrect title

	img1: draw 81x81 [circle 40x40 30]
	img2: copy/part at img1 0x0 81x81		;-- this failed on MacOS
	expect [img2 = img1]
]

issue/interactive #3353 [
	"REPLACE on text-list data corrupts the display"

	;; logic: do a `replace`, shoot, compare to a 'ready' layout
	display [
		tl1: text-list data ["a 1" "b 1"]
		b1: button [replace tl1/data/1 "1" "456"]
	]
	click b1
	s1: shoot tl1

	display [
		tl2: text-list data ["a 456" "b 1"]
		b2: button focus
	]
	s2: shoot tl2

	expect [s1 = s2]
]

issue #3349 [
	"VIEW Camera: Access Violation in Red --cli and error bug in GUI Console"
	should not crash
	;; don't know how to test the "error bug in GUI Console" part
	;; so just testing if the worker crashes

	;; logic: 0 is an invalid index, should return an error
	output: offload/silent [
		view [camera select 0]
	]
	expect [find output "Error"]
]

;; #3341 - dismissed

issue/interactive #3336 [
	"regression: size-text result is incorrect with fixed-size fonts"
	;; this issue requires both a floating-point pair! type and a `size-text` implementation independent of the face borders
	;@@ TODO: will this ever be fixed and how?

	;; logic: success criterion is to be able to measure text size from a single cell size
	display [
		do [fnt: make font! [name: system/view/fonts/fixed  size: 12]]
		a: area font fnt
	]
	cell:  offload/return [size-text/with a "o"]
	two:   offload/return [size-text/with a "xx"]
	four:  offload/return [size-text/with a "WWWW"]
	lines: offload/return [size-text/with a "x^/x^/x^/x"]
	expect [cell/x * cell/y > 0]
	expect [cell * 2x1 = two]
	expect [cell * 4x1 = four]
	expect [cell * 1x4 = lines]
]

issue/layout #3330 [
	"Rich text does not take new-lines into account"
	;; turns out not only 'bold', but font size also did not apply

	;; logic: second 'o' becomes tiny when it bugs, so size/y is expected to be ~50px
	s: shoot [backdrop white rich-text data [font 50 [b "o^/o" /b] ] ]
	expect [text [35x110 10% in s]]
]

;; #3311 - hard to reproduce automatically, and unlikely to go unnoticed

issue/interactive #3300 [
	"Regression in VID styles"

	display [
		do [list: []]
		style bbox: base 20x20 draw [pen gray box 0x0 19x19]
		on-down [append list 'on-down]
		b1: bbox #000000 b2: bbox #002b36 b3: bbox #073642
	]
	click b1 click b2 click b3
	list: sync list
	expect [list = [on-down on-down on-down]]	;-- only a single event in the buggy build
]

issue/interactive #3289 [
	"Words in actors in user defined styles are bound to face"

	;; logic: face/offset should not change
	display [
		do [list: []]
		style x: base red 100x100 on-down [
			append list face/offset 
			offset: 0 
			append list face/offset
		]
		b: x
	]
	click b
	list: sync list
	expect [2 = length? list]
	expect [list/1 = list/2]
]

;; #3288 - covered by #3349 test

issue/interactive #3279 [
	"'check' value not changed on clicking"

	display [
		do [list: []]
		c: check [append list face/data]
	]
	click c
	wait 1		;; no double clicks
	click c
	list: sync list
	expect [2 = length? list]		;-- not 3 events, nor zero
	expect [list/1 xor list/2]		;-- different states
]

;; #3278 - dismissed
;; #3275 - dismissed

;@@ TODO: how #3270 will be fixed? what is the proper behavior?

issue/interactive #3264 [
	"Radio widget turned off does not generate any event"

	;; logic: click on R2 should trigger on-change of R1 => detect it
	display [
		do [list: []]
		r1: radio "R1" yes [append list 'ok]
		r2: radio "R2"
	]
	click r2
	list: sync list
	expect [list = [ok]]
]

issue/layout #3247 [
	"VID: unexpected override of system default colors with black on white"

	s1: shoot [field                 area]
	s2: shoot [field italic          area italic]
	s3: shoot [field font-color blue area font-color blue]
	expect [s1 = s2]
	expect [s1 = s3]
]

;; #3244 - need a cam to reproduce
;; #3234 - dismissed 

issue/layout #3225 [
	"TEXT in DRAW does not honour TRANSLATE command"

	s: shoot/tight [base 200x100 draw [translate 50x30 text 0x0 "Text"]]
	area: object [offset: 50x30 size: 60x30]
	expect [text [in s/area aligned left top]]		;-- area will be empty if translation doesn't work
]

;; #3220 - will be covered by almost any test out there

issue/interactive #3213 [
	"Image! outside re-opened window"

	;; logic: capture image in a new place, see if it displayed right there
	offload [
		lay: layout [canvas: image 100x100 draw [pen cyan fill-pen cyan box 20x20 80x80]]
		view/no-wait lay
		unview/only lay
		top-window: view/no-wait/options lay [offset: 50x50]
	]
	canvas: sync canvas
	s: shoot/real canvas
	param [amount-of [cyan on s]]  [32% < 34% < 36% > 37% > 39%]
	param [amount-of [white on s]] [55% < 58% < 64% > 65% > 67%]	;-- 2px of rounding (of box and of capture) total to 4% error
]

;@@ TODO: too many bugs here, incl. #4337 - finish the test once it's fixed
; issue/interactive #3207 [
; 	"request-file bug in MacOS 10.13.2 and 10.13.3 High Sierra"
; 	;@@ TODO: how portable is this way of issue reproduction?
; 	;@@ TODO: is should be possible to write a higher level test for this; this code is temporary only

; 	task: jobs/send-main [file: request-file/file %./]
; 	wait 1		;-- let it display the dialog
; 	sim-string/async "log.txt"
; 	sim-key/async enter
; 	output: jobs/wait-for-task/max task 3
; 	?? output
; 	file: sync file
; 	?? file
; 	expect [empty? find/last/tail file %log.txt]
; ]



issue/interactive #3199 [
	"The on-unfocus event is not properly triggered on macOs"
	;; NOTE: this may never be fixed(?), but still should be considered a deficiency

	;; logic: TAB key should traverse the whole layout
	display [
		do [
			transfert-focus: func [evt prev-face next-face][
				if evt/key = tab [
					either evt/shift? [set-focus prev-face][set-focus next-face]
				]
			]
			list: []
		]
	    tf1: field focus
	        on-key      [transfert-focus event cb2 tf2]
	        on-unfocus  [append list "-tf1"]
	    tf2: field
	        on-key      [transfert-focus event tf1 cb1]
	        on-unfocus  [append list "-tf2"]
	    cb1: drop-list data ["One" "Two"] select 1
	        on-key      [transfert-focus event tf2 cb2]
	        on-unfocus  [append list "-cb1"]
	    cb2: drop-list data ["One" "Two"] select 1
	        on-key      [transfert-focus event cb1 tf1]
	        on-unfocus  [append list "-cb2"]
	]
	loop 4 [sim-key tab]
	list: sync list
	expect [list = ["-tf1" "-tf2" "-cb1" "-cb2"]]
]

;@@ TODO: will #3193 be granted?

issue/layout #3180 [
	"Background interferes with `text` in `view`"

	s1: shoot [backdrop white base white    "split-^/text"]
	s2: shoot [backdrop white box #FFFFFF01 "split-^/text"]
	expect [visually-similar? s1 s2]
]

;; #3178 - dismissed
;@@ TODO: do a manual events test for base & other faces?

;; #3176 - requires a camera to reproduce

issue/interactive #3173 [
	"View on-over doesn't trigger when using origin 0x0 and --cli"

	move-pointer 0x0
	top-window: display [
		do [list: []]
	    origin 0x0
	    base 200x200 blue on-over [append list 'ok]
	]
	loop 2 [
		wait 0.5			;-- let it detect the event
		move-pointer top-window ~at~ [center]
		wait 0.5			;-- let it detect the event
		move-pointer 0x0
	]
	wait 0.5				;-- let it detect the event
	list: sync list
	expect [list = [ok ok ok ok]]		;-- 2 times in and 2 out = 4 events
]

issue/interactive #3168 [
	"Tab key is lost when Shift key is pressed on macOS"

	display [
		do [list: []]
		field focus
		on-key [repend list [event/shift? event/key]]
	]
	sim-key/mods tab [shift]
	list: sync list
	expect [list = reduce [yes #"^-"]]		;-- may also fail due to #4338 and yield [no #"^-"]
]

issue/interactive #3167 [
	"submenus not appearing on MacOS"
	;@@ TODO: coordinates may be unportable - check on other platforms
	;@@ TODO: test compiled version too?

	;; logic: click on a submenu item - it should work
	top-window: display/with [
		size 100x0
		on-menu [append list event/picked]
		do [list: []]
	][	menu: ["item1" ["item2" ["item3" item3]]]
	]
	click/async top-window ~at~ [bottom left + 20x-10]		;-- /async, since menu will block it
	wait 0.2
	click/async top-window ~at~ [bottom left + 20x10]
	wait 0.2
	click top-window ~at~ [bottom left + 100x10]
	list: sync list
	expect [list = [item3]]
]

issue/layout #3165 [
	"Cannot drag face when display is scaled (Win10)"	;-- and W7

	;; logic: display boxes of different sizes, see if any are not transparent (because transparent parts prevent dragging)
	shots: []
	repeat x 10 [
		size: 151 + x * 1x1
		append shots shot: shoot/tight/real (compose/deep [
			backdrop black
			box 200x200 loose draw [
				fill-pen white box 10x10 (size + 10x10)
			]
		])
		expect [box [size at shot 10x10 > 90% all white]]
	]
]

issue/interactive #3164 [
	"VID: view [tab-panel] throws error"
	should not error out

	display [tab-panel]
]

;; #3160 - dismissed

issue/interactive #3153 [
	"`drop-down` data unmodifiable"
	should not error out

	display [
		dd: drop-down focus data ["A" "B" "C"]
		on-enter [append face/data copy face/text]
	]
	sim-key #"D" sim-key enter
	dd: sync dd
	expect [dd/data = ["A" "B" "C" "D"]]
]

issue/interactive #3152 [
	"[Wish] support explicitly setting the radio button data to false"
	should not error out

	display [radio false]
]

issue #3131 [
	"Functions inside face! objects are called during creation"

	list: offload/return [
		list: []
		make face! [
		    type: 'base
		    size: 100x100
		    f: does [append list "1"]
		    e: does [append list "2"]
		]
		list
	]
	expect [list = []]
]

issue/interactive #3130 [		;-- can't reproduce "put the PC to sleep part"..
	"VID: camera - GUI Console freeze when select is omitted in view [camera select 1]"
	should not crash
	should not hang
	should not error out

	display [camera 1]
]

issue #3129 [
	"React errors keep being re-thrown"

	output: offload/silent [
		view [ a: field b: field react [ bb/text: a/text ] ]
	]
	expect [find output "Error"]
	output: offload [
		unview/only view/no-wait [ a: field b: field react [ b/text: a/text ] ]
	]
]

issue #3126 [			;-- similar to #3349, but here with positive index
	"VID: camera - selecting any index other than 1 crashes GUI Console"
	should not crash

	output: offload/silent [
		view [camera select 100]
	]
	expect [find output "Error"]
]

issue #3122 [
	"Cannot define functions inside face! object"

	output: offload/silent [
		system/view/debug?: yes
		test: make face! [
		    type:  'base
		    myfunc: does [ 'nothing ]
		]
	]
	offload [system/view/debug?: no]		;-- cleanup

	expect [not find output "Error"]		;-- will be also debug output
	test: sync test
	expect ['nothing = test/myfunc]
]

issue/interactive #3121 [
	"View 'area' face crash on setting `disable` option"
	should not crash

	display [a: area disabled  focus 200x300]
]

issue #3120 [
	"VID: style error in tab-panel"

	;; logic: view block is invalid, but an error should be informative
	output: offload/silent [
		view/no-wait [
			size 800x600
			origin 0x0 space 0x0
			tab-panel 800x600 [
				style fld: field 600   ;- error
				"Home " [ 
					backdrop crimson
					below
					space 0x0
					h4  "Enter  expression:" 
					fld
				]
				"Help " [backdrop crimson ]
			]
		]
	]
	expect [find output "Error"]
	expect [find output "invalid syntax"]	;-- not just `copy` error
]

;@@ TODO: #3116 - test like that is unreliable; should be a custom test that will try various fonts/labels
