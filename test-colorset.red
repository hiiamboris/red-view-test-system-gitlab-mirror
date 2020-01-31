Red [
	title:   "colorset function manual test"
	author:  @hiiamboris
	license: 'BSD-3
]


test-colorset: function [][
	log-trace "--- Started colorset function test ---"
	scope [
		cs1: get-colorset im1: make image! 1x1
		cs2: get-colorset im2: make image! 3x3
		cs3: get-colorset im3: draw 100x100 [line-width 5 pen blue circle 50x50 30 30]
		cs4: get-colorset im4: draw 100x100 [line-width 3 pen blue circle 50x50 30 30]
		cs5: get-colorset im5: draw 100x100 [line-width 3 pen green circle 50x50 30 30]
		cs6: get-colorset im6: draw 100x100 [line-width 3 pen red circle 50x50 30 30]
		sorted?: func [cs][cs = sort/skip/compare/reverse cs 2 2]
		n-colors?: func [cs][(length? cs) / 2]
		bg-color?: func [cs][cs/1]
		fg-color?: func [cs][cs/3]
		bg-space?: func [cs][100% * cs/2 / sum extract next cs 2]
		fg-space?: func [cs][100% * cs/4 / sum extract next cs 2]
		; red-of:   :first   red?:   func [c][ (c/1 - max c/2 c/3) / 255.0 ]
		; green-of: :second  green?: func [c][ (c/2 - max c/1 c/3) / 255.0 ]
		; blue-of:  :third   blue?:  func [c][ (c/3 - max c/1 c/2) / 255.0 ]

		eval-results-group [
			"get-colorset func"
			param-exact [sorted? cs1] yes
			param-exact [sorted? cs2] yes
			param-exact [sorted? cs3] yes
			param-exact [sorted? cs4] yes
			param-exact [sorted? cs5] yes
			param-exact [sorted? cs6] yes

			param-exact [n-colors? cs1] 1
			param-exact [n-colors? cs2] 1
			;; some kind of magic optimization keeps color count at 33
			;; but in the worst case it's reasonable to expect a minimum of:
			;;  - all gradations of blue (512 in total)
			;;  - double circle length (~376 pixels)
			;; lower margin is 2 colors: blue and white, no antialias
			param [n-colors? cs3] [2 < 10 < 33 > 100 > 400]
			param [n-colors? cs4] [2 < 10 < 33 > 100 > 400]
			param [n-colors? cs5] [2 < 10 < 33 > 100 > 400]
			param [n-colors? cs6] [2 < 10 < 33 > 100 > 400]

			;@@ TODO: UI to inspect blames!
			param-exact/blame [bg-color? cs3] white [cs3 im3]
			param-exact/blame [bg-color? cs4] white [cs4 im4]
			param-exact/blame [bg-color? cs5] white [cs5 im5]
			param-exact/blame [bg-color? cs6] white [cs6 im6]
			param-exact/blame [fg-color? cs3] blue  [cs3 im3]
			param-exact/blame [fg-color? cs4] blue  [cs4 im4]
			param-exact/blame [fg-color? cs5] green [cs5 im5]
			param-exact/blame [fg-color? cs6] red   [cs6 im6]

			param [bg-space? cs3] [87% < 88% <  90% > 92% > 93%]
			param [bg-space? cs4] [90% < 91% <  92% > 94% > 95%]
			param [bg-space? cs5] [90% < 91% <  92% > 94% > 95%]
			param [bg-space? cs6] [90% < 91% <  92% > 94% > 95%]
			param [fg-space? cs3] [ 5% <  6% < 7.5% >  9% > 10%]
			param [fg-space? cs4] [ 2% <  3% <   5% >  7% >  8%]
			param [fg-space? cs5] [ 2% <  3% <   5% >  7% >  8%]
			param [fg-space? cs6] [ 2% <  3% <   5% >  7% >  8%]

			param-exact [(fg-space? cs4) = (fg-space? cs5)] yes
			param-exact [(fg-space? cs4) = (fg-space? cs6)] yes
		]
	]
	log-trace "--- Ended colorset function test ---"
]
test-colorset

