Red [
	title:   "box function manual test"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %dope.red
#include %visuals.red

;;@@ TODO: unified interface for custom tests, to automatically call them

test-box: function [][
	log-trace "--- Started box function test ---"
	scope [

		ppu: (units-to-pixels 1000) / 1000.0			;-- pixels per unit
		img: draw 200x200 * ppu compose [
			scale (ppu) (ppu)							;-- scale it according to DPI, as on real screenshots
			pen gold
			fill-pen magenta
			box 50x50 150x150
			fill-pen cyan
			box 100x100 150x150
			box 100x100 140x120
		]
		area1:    object [offset: 50x50 size: 100x100]
		area-bad: object [offset: 30x30 size: 70x70]
		wndw:  make face! [type: 'window offset: 500x500 size: 300x300 parent: system/view/screens/1]
		area2: make face! [type: 'base   offset:  50x50  size: 100x100 parent: wndw]
		area3: make face! [type: 'base   offset:  50x50  size:  40x20  parent: area2]

		; =spec=: [
		; 	[	=where=
		; 		opt [if (find [at on] where-op) [=anchors= | =offset=]]		;-- only allow position for at/on
		; 		opt [if (where-op <> 'around) =size=]						;-- disable size in 'around' mode (size equals area/size)
		; 	|	=size= =where= if (where-op <> 'around)						;-- in `around` mode this is invalid as it has size
		; 		opt [if (find [at on] where-op) [=anchors= | =offset=]]
		; 	]
		; 	opt [=coverage= =coloration= | =coloration= =coverage=]
		; ]

		eval-results-group/key [
			"box dialect func"

			;; just check if boxes are found
			expect [box [around img/area1]]
			expect [box [around img/area2]]
			expect [box [around img/area3]]		;-- area3 also plugs in area2/offset
			expect [not box [around img/area-bad]]
			
			;; is 'around the default mode?
			expect [box [img/area1]]
			expect [box [img/area2]]

			;; 'at test
			expect [box [100x100 at img 50x50]]
			expect [box [at img 50x50 100x100]]
			expect [box [100x100 on img 50x50]]
			expect [box [on img 50x50 100x100]]
			expect [box [100x100 at img 50x50   75% all magenta]]
			expect [box [at img 50x50 100x100 > 20% all cyan]]

			;; 'within test
			expect [box [100x100 within img]]
			expect [box [within img 50x50]]
			expect [box [100x100 inside img]]
			expect [box [inside img 50x50]]
			expect [box [within img 40x20 100% almost cyan]]
			expect [box [within img 50x50 > 95% all cyan]]
			expect [not box [within img 50x50 >= 100% all cyan]]

			;; usage of a box result in box dialect
			expect [b1: box [100x100 within img]]
			expect [    box [40x20 within img/b1]]
			expect [    box [40x20 at img/b1 50x50]]
			expect [not box [50x20 at img/b1 50x50]]

			;; coverage test
			expect [box [img/area1 75% all magenta]]
			expect [box [img/area1 75% almost magenta]]
			expect [box [img/area1 75% somewhat 255.20.255]]
			expect [box [img/area1 ~= 75% all magenta]]
			expect [box [img/area1 >= 74% all magenta]]
			expect [box [img/area1 >  50% all magenta]]
			expect [box [img/area1 <= 76% all magenta]]
			expect [box [img/area1 <  80% all magenta]]
			expect [not box [img/area1 80% all magenta]]
			expect [not box [img/area1 70% all magenta]]

			;; anchors test
			expect [box [at img/area1 bottom right 50x50]]
			expect [box [at img/area1 right bottom 50x50]]
			expect [box [at img/area1 bottom 50x50]]
			expect [box [at img/area1 right 50x50]]
			expect [box [at img center middle 100x100]]
			expect [box [at img middle 100x100]]
			expect [box [at img center 100x100]]
			expect [not box [at img right 50x50]]
			expect [not box [at img/area1 center 50x50]]

			;; common errors
			expect [error? try [box [none]]]						;-- image is none
			expect [error? try [box [img/none]]]					;-- area is none
			expect [error? try [box [200x200 around img/area1]]]	;-- size in both area and spec

		] "MANUAL/BOX"
	]
	log-trace "--- Ended box function test ---"
]

test-box
log-review
