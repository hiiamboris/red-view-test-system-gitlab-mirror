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
	sync list
	expect [list = reduce [true]]

	click pos
	sync list
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
	sync list
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
	sync fld
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
	pnl/offset: pnl/offset + wndw/offset		;@@ TODO: complex paths like scrn/wndw/pnl ?
	expect [btn: box [within scrn/pnl 80x20]]
	click btn/size / 2 + btn/offset + pnl/offset	;@@ TODO: let boxes carry an absolute offset too!
	close wndw		;@@ required when window was not created by the worker?
	;@@ TODO: check the worker output for crash signs
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
	boxes: find-glyph-boxes shot
	expect [18 * 2 = length? boxes]
	expect [(min-glyph-distance boxes) + 4 > max-glyph-distance boxes]		;@@ 4px is not a tab - but how big a tab should be?
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
	boxes: find-glyph-boxes shot
	expect [5 * 2 = length? boxes]				;@@ TODO: higher-level tests than this and than glyph-boxes; declarative!!
	expect [equally-sized? boxes]
	expect [within? min-glyph-size boxes 20x20 10x20]	;@@ TODO: how reliable these sizes are across platforms?
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

	run/output exe %4104out.txt
	; settle-down 2 sec
	scrn: screenshot
	wndw: find-window-on scrn
	expect [wndw]
	expect [btn: box [80x25 within scrn/wndw]]
	click btn
	wait 0.3
	close wndw
	output: read %4104out.txt
	expect [output = ":test:^/"]
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
		exe: compile/release/debug [		;-- need -d to see the warning in output
			Red [needs: view]
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
		run/output exe %out4061.txt			;@@ TODO: automatically save output? make `exe-output` a reading function?
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
		output: read %out4061.txt
		expect [not find output "WARNING"]
	]

	variant 2 [	;; crash ;; logic: capture the output, check for an error
		exe: compile/release/debug [
			Red [needs: view]
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
		run/output exe %out4061-2.txt
		scrn: screenshot
		expect [wndw: find-window-on scrn]
		click/right wndw

		;; it may crash after right-click: look again
		settle-down 1 sec
		scrn: screenshot
		expect [wndw: box [scrn/wndw]]
		if wndw [close wndw]

		output: read %out4061-2.txt
		expect [not find output "Runtime Error"]
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
	exe: compile/release/debug [Red [Needs: View] alert "test"]
	run/output exe %4005out.txt
	scrn: screenshot
	expect [wndw: find-window-on scrn]
	close wndw
	output: read %4005out.txt						;@@ TODO: auto output capture
	expect [not find output "Runtime Error"]	;@@ TODO: make a higher level test from this?
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
	sync list
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

;@@ TODO: make all artifact file names sorted by issue so they can be navigated even with thousands of issues tested
