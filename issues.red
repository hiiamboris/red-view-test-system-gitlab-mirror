Red [
	title:   "test set for individual issues"
	author:  @hiiamboris
	license: 'BSD-3
]

; #where's-my-error?

;@@ TODO: separate file(s) for manual tests (clicker etc..)

;@@ TODO: always use a fixed (white?) backdrop for windows - to screen out system settings ? will this play well with custom font colors?
;@@ `display` should do/events until on-create actors finish
;@@ TODO: clear reactions after every test
;@@ `close` should do platform-specific window closing action
;@@ TODO: console wherer one can play with tests: run a single test easily or a few, receiving a FULL report
;@@ TODO: `issue` should check if test numbers do not repeat and should be able to tell a list of covered issues
;@@ TODO: think in what cases it's possible to make screenshots (for later comparison and changes detection) and how!! important!
;@@ TODO: copy/deep tests body
;; issue /types define what capabilities are given to the code: can it compile? can it interact?
;; point is not just clear definition, but that /compile & /layout can be parallelized but should not use screen-shots or actions

;; TIP: issues title is mostly for informational purpose:
;;   first, when debugging an issue - it makes clear what we're looking for
;;   second, when an issue fails this info can be displayed to provide the person running tests with a context for failure

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
	expect [fld/size/x > 50]
	expect [box [at shot/base fld/offset fld/size > 90% all blue]]
]

;@@ TODO: #4229 should be covered by base-test - port it

issue/interactive #4226 [
	"[View] FIELD is not draggable on macOS"

	;; logic: drag field, see if it moved
	should not error out		;@@ TODO: check worker's (out of order) output for errors
	w: display [size 200x50 fld: field loose]
	s1: shoot w
	o1: fld/offset
	expect [box [at s1 fld/offset fld/size]]
	drag fld [right by 20]
	s2: shoot w
	fld: sync fld
	expect [fld/offset/y = o1/y]
	param  [fld/offset/x - o1/x] [17 < 18 < 20 > 22 > 23]
	expect [box [at s2 fld/offset fld/size]]
]

;@@ TODO: #4213 requires specific fonts installed - how to handle?? wait until Red can be packaged with custom fonts? or ask testers to install those?

issue/interactive #4221 [		;-- /interactive to have DISPLAY
	"[View] Screenshots do not contain layered (alpha-enabled) windows"

	;; logic: make a semi-transparent window, compare built-in and Red screenshots
	display [box #FF00FF50]
	s1: to-image system/view/screens/1
	log-image s1
	s2: screenshot
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
	; pnl/offset: pnl/offset + wndw/offset		;@@ TODO: complex paths like scrn/wndw/pnl ?
	expect [btn: box [within scrn/pnl 80x20]]
	click btn
	; click btn/size / 2 + btn/offset + pnl/offset	;@@ TODO: let boxes carry an absolute offset too!
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
	expect [find output "Access Error: cannot open: %non-existing-image.png"]
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
	expect [glyphs/min-distance + 4 > glyphs/max-distance]		;@@ 4px is not a tab - but how big a tab should be?
]

issue #4123 [		;-- does not require any windows really
	"[VID] When `style` is set to certain type, further styles can't be defined"
	should not error out

	style: 30%
	layout [style s1: base red style s2: base blue s1 s2]
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

issue/deadlock/interactive #3974 [
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

	s1: shoot [
		base white 100x100 draw [			;-- I'm not testing `base` here, supposing that it's working
			pen blue
			clip 0x0 50x50
			translate 10x10
			rotate 10 0x0
			scale 2 2
			box 0x0 60x20
			text 0x0 "X"
		]
	]
	s2: shoot [
		rich-text white 100x100 draw [
			pen blue
			clip 0x0 50x50
			translate 10x10
			rotate 10 0x0
			scale 2 2
			box 0x0 60x20
			text 0x0 "X"
		]
	]
	expect [visually-similar? s1 s2]
]

issue #3812 [
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
	roll-the-wheel up
	list: sync list
	expect [empty? list]
	offload [remove-event-func :evfun]		;-- cleanup
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
	;@@ it affects it though, see issue comment; let it produce a warning
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
