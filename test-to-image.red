Red [
	title:   "to-image manual test"
	author:  @hiiamboris
	license: 'BSD-3
]

;; since to-image is of no use right now, have to use an alternate capture route and test it

;@@ TODO: test to-image vs capture-face/real instead! - for self-testing and to-image evaluation
;@@ TODO: check that to-image result is pixel-precise (not scaled by dpi) - a window of 100px size should result in 100px image
test-toimage: function ["Ensures to-image is working as expected"] [
	log-trace "--- Started to-image test ---"
	scope [
		; #where's-my-error?
		bad: [] good: []
		check: func [face word][
			log-trace #composite "Checking to-image (word)..."
			append either image-empty? to-image face [bad][good] word
		]

		scope [											;-- test `window` face separately
			v: view/no-wait []
			leaving [unview/only v]
			check v 'window
		]

		words: exclude words-of system/view/VID/styles [;-- other faces to test
			window			;-- already tested
			camera			;-- can't be reliably tested against the black background
			calendar		;-- not yet official
			rich-text		;@@ TODO: add it! catch the crash (#4269)
			scroller		;@@ TODO: add it! catch the crash (#4269)
		]
		log-trace #composite "Styles to test to-image on: (mold words)"
		panic-if [empty? words] "Can't find VID styles list!"

		color: blue					;-- need a color different from window background
		if color = system/view/metrics/colors/panel [color: magenta]
		foreach w words [
			scope [
				v: view/no-wait compose [f: (w) "text" color]
				leaving [unview/only v]
				until [do-events/no-wait]
				check f w
			]
		]
		log-trace #composite "to-image test succeeded for (mold good)"
		log-trace #composite "to-image test failed for (mold bad)"

		bad-amnt:   100% * (length? bad)  / (1 + length? words)		;-- '1' to account for 'window'
		good-amnt:  100% * (length? good) / (1 + length? words)
		eval-results-group [
			"To-image trustworthiness"
			;; generally bad-amnt + good-amnt <> 100% in case of errors with `view`
			param [bad-amnt]      [ 0% <  0% <   0% >   5% > 20%  "to-image is too unreliable!"]
			param [good-amnt]     [80% < 95% < 100% > 100% > 100% "to-image is too unreliable!"]
			expect [find good 'window]					;-- most important
			expect [find good 'base]					;-- also important
		]
	]
	log-trace "--- Ended to-image test ---"
]
test-toimage
log-review

