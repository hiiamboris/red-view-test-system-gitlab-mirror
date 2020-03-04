Red [
	title:   "box & glyph detection mezzanines"
	author:  @hiiamboris
	license: 'BSD-3
]


{
	BOX formats:
	found glyphs:     [xy1 xy2 ..]
	boxes from edges: [probability xy1 xy2 ..]
	box dialect result (not here): object [size: .. offset: ..  ...]
}

boxes-ctx: context [
	;@@ TODO: R/S version? this one takes 0.5 sec; up to 10 sec!!

	set 'find-boxes function [edges [block!]] [
		find-boxes* edges/1 edges/2
	]

	set 'check-alignment function [
		"Verify if box XY1-XY2 inside TOTAL size is aligned according to given anchors"
		xy1 [pair!] xy2 [pair!] total [pair!] h-anchor [word! none!] v-anchor [word! none!]
	][
		;; center requires balance of low and high margin
		;; low / high require closeness to the edge
		mo: 6 * system/view/metrics/dpi / 96	;-- anchors 'max offset': how far from the edge box can be located
		plo: abs xy1  phi: abs total - xy2		;-- paddings: low (left/top), high (right/bottom)
		oc: abs xy1 + xy2 - total				;-- asymmetry - double offset of box center from the area center
		all [
			h-anchor
			any switch h-anchor [
				left   [[plo/x > mo  phi/x - plo/x < mo]]		;-- too far from left, closer or relatively equidistant to right
				center [[oc/x > mo]]							;-- not symmetrically placed around center
				right  [[phi/x > mo  plo/x - phi/x < mo]]		;-- too far from right, closer or relatively equidistant to left
			]
			return no
		]
		all [
			v-anchor
			any switch v-anchor [
				top    [[plo/y > mo  phi/y - plo/y < mo]]		;-- too far from top, closer or relatively equidistant to bottom
				middle [[oc/y > mo]]							;-- not symmetrically placed around center
				bottom [[phi/y > mo  plo/y - phi/y < mo]]		;-- too far from bottom, closer or relatively equidistant to top
			]
			return no
		]
		yes
	]

	set 'find-box function [
		"Look for a box of specific SIZE in BOXES; return the best matching box"
		boxes [block!] size [pair!]
		/anchors
			h-anchor [word! none!]
			v-anchor [word! none!]
			total [pair!] "Total area size (for anchors)"		;@@ TODO: this is ugly
	][
		max-mismatch:   5			;-- how far box size (x/y) can go off from the requested one (pixels)
		abs: :absolute
		best: reduce [max-mismatch + 1 0.0 none none]
		foreach [prob xy1 xy2] boxes [
			diff: absolute xy2 - xy1 - size
			mismatch: max diff/x diff/y			;@@ or sum it?
			if any [
				mismatch > best/1									;-- a better match is already found
				all [mismatch = best/1  prob <= best/2]				;-- equal match of better probability is already found
			] [continue]
			all [
				anchors
				not check-alignment xy1 xy2 total h-anchor v-anchor
				continue
			]
			repend clear best [mismatch prob xy1 xy2]
		]
		if best/1 > max-mismatch [return none]
		next best		;@@ copy?
	]

	;; returns fitness of the box given by 2 pairs into the edges arrays: 0% if no match, 100% if perfect match
	set 'fit-box function [edges [block!] xy1 [pair!] xy2 [pair!] /local hpos vpos prob x y x1 x2 y1 y2] [
		h-edges: edges/1
		v-edges: edges/2
		ssize: units-to-pixels system/view/screens/1/size
		width:  ssize/x
		height: ssize/y
		max-abs-ext: 8			;-- maximum edge extension length (absolute)
		max-rel-ext: 50%		;-- maximum edge extension length (relative) - increase to detect smaller boxes, decrease to filter em out
		max-proximity: 5		;-- most important: how far lines given by the box can be away from the edge lines
		extend: function ['x1 [word!] 'x2 [word!]] [
			ext: min max-abs-ext to integer! max-rel-ext * subtract get x2 get x1
			reduce [subtract get x1 ext  add get x2 ext]
		]

		not-found: reduce [0% xy1 xy2]

		;; find top edge that fits best
		best-prox: 1 + max-proximity
		for-each [hpos: prob y x1 x2] h-edges [
			prox: absolute y - xy1/y
			unless prox <= max-proximity [continue]					;-- edge should go near the box margin
			set [x1' x2'] extend x1 x2 width
			unless all [x1' <= xy1/x  xy2/x <= x2'] [continue]		;-- should cover the whole box width
			if prox >= best-prox [continue]							;-- a better candidate exists
			best-prox: prox
			best-hpos: hpos
			best-top: reduce [prox prob y x1 x2 x1' x2']
		]
		if none? best-top [return not-found]

		;; find bottom edge that fits best
		best-prox: 1 + max-proximity
		foreach [prob y x1 x2] at h-edges best-hpos + 4 [
			prox: absolute y - xy2/y
			unless prox <= max-proximity [continue]					;-- edge should go near the box margin
			set [x1' x2'] extend x1 x2 width
			unless all [x1' <= xy1/x  xy2/x <= x2'] [continue]		;-- should cover the whole box width
			if prox >= best-prox [continue]							;-- a better candidate exists
			best-prox: prox
			best-bot: reduce [prox prob y x1 x2 x1' x2']
		]
		if none? best-bot [return not-found]

		;; find left edge that fits best
		best-prox: 1 + max-proximity
		for-each [vpos: prob x y1 y2] v-edges [
			prox: absolute x - xy1/x
			unless prox <= max-proximity [continue]					;-- edge should go near the box margin
			set [y1' y2'] extend y1 y2 height
			unless all [y1' <= xy1/y  xy2/y <= y2'] [continue]		;-- should cover the whole box width
			if prox >= best-prox [continue]							;-- a better candidate exists
			best-prox: prox
			best-vpos: vpos
			best-lef: reduce [prox prob x y1 y2 y1' y2']
		]
		if none? best-lef [return not-found]

		;; find right edge that fits best
		best-prox: 1 + max-proximity
		foreach [prob x y1 y2] at v-edges best-vpos + 4 [
			prox: absolute x - xy2/x
			unless prox <= max-proximity [continue]					;-- edge should go near the box margin
			set [y1' y2'] extend y1 y2 height
			unless all [y1' <= xy1/y  xy2/y <= y2'] [continue]		;-- should cover the whole box width
			if prox >= best-prox [continue]							;-- a better candidate exists
			best-prox: prox
			best-rig: reduce [prox prob x y1 y2 y1' y2']
		]
		if none? best-rig [return not-found]

		part: func [a x b /local d] [
			d: either a <= b [max 0 x - a][min 0 x - a]
			sqrt 1.0 - (1.0 * d / (b - a))							;-- nonlinear probability - first pixels almost for free
		]
		probs: clear []		;-- take average contrast over the whole box perimeter (simple 1/4 vs precise)
		xprob: func [blk /local prox prob y x1 x2 x1' x2'] [
			set [prox prob y x1 x2 x1' x2'] blk
			append probs prob
			(part 0 prox max-proximity + 1) * (part x1 xy1/x x1' - 1) * (part x2 xy2/x x2' + 1)
		]
		yprob: func [blk /local prox prob y x1 x2 x1' x2'] [
			set [prox prob y x1 x2 x1' x2'] blk
			append probs prob
			(part 0 prox max-proximity + 1) * (part x1 xy1/y x1' - 1) * (part x2 xy2/y x2' + 1)
		]

		r: 100%				;-- multiply so if one margin is zero-prob, whole box is zero-prob
		foreach b reduce [best-top best-bot] [r: r * xprob b]
		foreach b reduce [best-lef best-rig] [r: r * yprob b]
		reduce [
			r * (sum probs) / 4
			as-pair best-lef/3 best-top/3
			as-pair best-rig/3 best-bot/3
		]
	]



	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; what I tested: "abcdefghijklmnopqrstuvwxyz1234567890!-_*+/\~@#$%&^^()=[]{}':;,.?<>"
	;; good: "bdeghilopqsz123567890!-*+~@$%^^()=':;,.<>" - mostly separated ('!1:.' are particularily great)
	;; bad: "4amntuvx#[]{}?" - may not be separated (e.g. arial draws '{}' as a single glyph, etc.)
	;; worst: "cfjkrwy\/_&" - overhang onto each other's space
	good-chars: "bdeghilopqsz123567890!-*+~@$%^^()=':;,.<>"
	ideal-chars: "0135689eos'.,:;!$"

	;; More detailed stats for 2%/20% (incl. 12pt) for all tested fonts:
	;  last chars play well even with the worst chars, but everything after 's' is okay: "s,eo;06985$'3.:1!" or "0135689eos'.,:;!$"
	;    char   glitch count
	;     #"_" 1289 
	;     #"f" 1093 
	;     #"w" 643 
	;     #"\" 565 
	;     #"u" 558 
	;     #"y" 553 
	;     #"/" 548 
	;     #"v" 547 
	;     #"j" 530 
	;     #"k" 516 
	;     #"x" 501 
	;     #"t" 491 
	;     #"r" 461 
	;     #"#" 414 
	;     #"m" 334 
	;     #"n" 327 
	;     #"h" 309 
	;     #"g" 304 
	;     #"z" 274 
	;     #"4" 274 
	;     #"^^" 266 
	;     #"~" 239 
	;     #"a" 223 
	;     #"+" 204 
	;     #"l" 202 
	;     #"i" 200 
	;     #"p" 197 
	;     #"*" 188 
	;     #"b" 186 
	;     #"d" 183 
	;     #"&" 177 
	;     #"{" 158 
	;     #"}" 154 
	;     #"=" 151 
	;     #"@" 146 
	;     #"q" 144 
	;     #"%" 122 
	;     #">" 115 
	;     #"<" 113 
	;     #"2" 106 
	;     #"-" 104 
	;     #"(" 104 
	;     #")" 103 
	;     #"]" 100 
	;     #"7" 97 
	;     #"?" 90 
	;     #"c" 73 
	;     #"[" 73 
	;     #"s" 70 
	;     #"," 65 
	;     #"e" 62 
	;     #"o" 62 
	;     #";" 60 
	;     #"0" 57 
	;     #"6" 57 
	;     #"9" 57 
	;     #"8" 56 
	;     #"5" 55 
	;     #"$" 49 
	;     #"'" 46 
	;     #"3" 44 
	;     #"." 30 
	;     #":" 29 
	;     #"1" 23 
	;     #"!" 23

	;; Font choice:
	;; Verdana - excellent, full separation at >= 8pt (except glitches with '4' on 13-14pt)
	;; Courier New - very good, mostly separated at >= 12pt, some glitches at 'dbh'
	;; Lucida Console - good, >=16pt usually separated, double check it
	;; Arial, Tahoma - moderate, >= 20pt but glitch-prone, double/triple check them
	;; Sylfaen - bad, >= 30pt, should be double/triple checked with other glyphs
	;; Times New Roman - worst, >= 40pt, should be double/triple checked with other glyphs

	ideal-string?: func [
		"Check string characters for being ideally fit for glyph box extraction"
		s [string!]
	][
		empty? exclude s ideal-chars
	]

	good-string?: func [
		"Check string characters for being a good fit for glyph box extraction"
		s [string!]
	][
		empty? exclude s good-chars
	]

	string-fitness?: function [
		"Measure string fitness for glyph extraction (0 = can't be worse, >= 0.5 = okay, 1 = best)"
		s [string!]
	][
		ideal-cs: charset ideal-chars
		good-cs: charset good-chars
		n-ideal: 0 n-good: 0 n-bad: 0
		foreach c s [
			case [
				find ideal-cs c [n-ideal: n-ideal + 1]
				find good-cs c  [n-good:  n-good  + 1]
				'else           [n-bad:   n-bad   + 1]
			]
		]
		100% / (length? s) * either n-bad > 0
			[n-ideal + n-good / 2.0]		;-- don't go over 0.5 in presence of a bad char
			[n-good / 2.0 + n-ideal]
	]
	assert [100% = string-fitness? "!!!"]
	assert [0%   = string-fitness? "www"]
	assert [50%  > string-fitness? "!!!j!!!"]

	set 'get-background-color function [im [image!]] [
		max-fill: 0
		vsets: clear []
		repeat x im/size/x [
			append/only vsets cs: get-vline-colorset im x
			if cs/2 > max-fill [set [bgnd max-fill] cs]			;-- background color is the one with longest line
			if max-fill = im/size/y [break]						;-- found it
		]
		if max-fill < (90% * im/size/y) [return none]			;-- result is too unreliable to be used ;@@ TODO: 70%? 90%? 100%?
		;; another way is to choose background as > 50% of area, or the most prevalent color - but probably makes less sense
		bgnd
	]


	{
		Warning: 'text' is not a strict category. `text "█"` is indistinguishable from `base NxM`
		Current implementation just finds the area covered by anything-but-background.
		Ideally I would measure median color of each X and Y line, then subtract that from the image
		to emphasize the (noisy) text vs background, but that's not a top priority.
		Just use shoot/tight or any other means to discard the frame from the image and it'll work.
	}

	;@@ TODO: warning when used not on a solid background (e.g. when there's a frame) - or better: make it ignore that frame
	;;   it is possible to detect text by finding an area where colorsets are changing often
	;@@ TODO: maybe make some boxes lower (to distinguish upper/lower case letters)
	;; should I provide xy1,xy2? or just crop the image?
	set 'find-glyph-boxes function [im [image!] /local bgnd x1 x2] [
		min-contrast: 20%										;-- below this - treat pixel as background (20% seems best)
		min-weight: 2%											;-- min % of line height that is considered part of a glyph (2% seems best)

		max-fill: 0
		vsets: clear []
		repeat x im/size/x [
			append/only vsets cs: get-vline-colorset im x
			if cs/2 > max-fill [set [bgnd max-fill] cs]			;-- background color is the one with longest line
		]
		if max-fill < (90% * im/size/y) [return copy []]		;-- result is too unreliable to be used ;@@ TODO: 70%? 90%? 100%?
		;; another way is to choose background as > 50% of area, or the most prevalent color - but probably makes less sense

		hsets: clear []
		repeat x im/size/y [append/only hsets cs: get-hline-colorset im x]

		y-range: im/size/y * 1x0
		prev: no
		repeat i length? hsets [
			occupied: no
			foreach [clr amnt] hsets/:i [
				if occupied: min-contrast <= contrast clr bgnd [break]
			]
			if occupied <> prev [
				either occupied
					[ if y-range/1     > i [y-range/1: i] ]
					[ if y-range/2 + 1 < i [y-range/2: i - 1] ]
			]
			prev: occupied
		]
		if occupied [			;-- last line was occupied
			y-range/2: im/size/y
		]
		if y-range/1 > y-range/2 [return copy []]	;-- no text detected

		prev: no
		x-ranges: clear []
		min-weight: min-weight * (y-range/2 - y-range/1 + 1)
		repeat i length? vsets [
			weight: 0%
			occupied: no
			foreach [clr amnt] vsets/:i [
				if min-contrast <= c: contrast clr bgnd [
					weight: weight + (c - min-contrast * amnt)
					if weight >= min-weight [occupied: yes break]
				]
			]
			if occupied <> prev [append x-ranges i - make integer! prev]
			prev: occupied
		]

		map-each/eval [x1 x2] x-ranges [[
			as-pair x1 y-range/1
			as-pair any [x2 im/size/x] y-range/2		;-- `any` in case a box began but never ended
		]]
	]

	hsets-of: function [im [image!]] [
		also hsets: copy []
			repeat x im/size/y [append/only hsets get-hline-colorset im x]
	]

	vsets-of: function [im [image!]] [
		also vsets: copy []
			repeat y im/size/x [append/only vsets get-vline-colorset im y]
	]

	;@@ TODO: maybe enhance this that it actually looks for text-specific properties (line thickness, kerning..), not just counts pixels?
	set 'get-text-box function [
		"Return the text box dimensions [xy1 xy2] of a text on an image IM"
		im [image!] /local bgnd x1 x2
	][
		min-contrast: 20%										;-- below this - treat pixel as background (20% seems best)

		max-fill: 0
		vsets: vsets-of im
		foreach cs vsets [
			if cs/2 > max-fill [set [bgnd max-fill] cs]			;-- background color is the one with longest line
			if max-fill = im/size/y [break]						;-- found it
		]
		if max-fill < (90% * im/size/y) [return copy []]		;-- result is too unreliable to be used ;@@ TODO: 70%? 90%? 100%?
		;; another way is to choose background as > 50% of area, or the most prevalent color - but probably makes less sense
		;@@ TODO: or maybe use both metrics and if they don't match - issue a warning

		hsets: hsets-of im

		y-range: 1x1
		x-range: 1x1
		foreach [i1 i2 sets dst] compose [
			1 (length? hsets) hsets y-range/1
			(length? hsets) 1 hsets y-range/2
			1 (length? vsets) vsets x-range/1
			(length? vsets) 1 vsets x-range/2
		] [
			for i i1 i2 [
				occupied?: no
				foreach [clr amnt] pick get sets i [
					if occupied?: min-contrast <= contrast clr bgnd [break]
				]
				if occupied? [set dst i break]
			]
		]

		#assert [x-range/1 <= x-range/2]
		#assert [y-range/1 <= y-range/2]
		reduce [
			as-pair x-range/1 y-range/1
			as-pair x-range/2 y-range/2
		]
	]


	min+max-glyph-distance: function [boxes [block!] /local e1] [
		#assert [even? length? boxes]
		set [_ e1] boxes
		min-dist: 1e10
		max-dist: -1
		foreach [s2 e2] skip boxes 2 [
			min-dist: min min-dist dist: s2/x + 1 - e1/x
			max-dist: max max-dist dist
			e1: e2
		]
		reduce [min-dist max-dist]
	]

	min+max-glyph-size: function [boxes [block!]] [
		#assert [even? length? boxes]
		min-area: 1e10
		max-area: -1
		min-size: max-size: none
		foreach [s e] boxes [
			size: e - s + 1x1
			area: size/x * size/y
			if area < min-area [min-area: area  min-size: size]
			if area > max-area [max-area: area  max-size: size]
		]
		reduce [min-size max-size]
	]

	;; these are meant to be used in tests as they return scaled results

	set 'min-glyph-distance function [boxes [block!]] [
		r: first min+max-glyph-distance boxes
		all [r < 1e10  pixels-to-units r]
	]

	set 'max-glyph-distance function [boxes [block!]] [
		r: second min+max-glyph-distance boxes
		all [r >= 0  pixels-to-units r]
	]

	set 'min-glyph-size function [boxes [block!]] [
		r: first min+max-glyph-size boxes
		all [r  pixels-to-units r]
	]

	set 'max-glyph-size function [boxes [block!]] [
		r: second min+max-glyph-size boxes
		all [r  pixels-to-units r]
	]

	set 'glyphs-equally-sized? function [boxes [block!]] [
		assert [not empty? boxes]		;-- undefined for that
		set [s e] boxes
		size: e - s
		foreach [s e] skip boxes 2 [
			ds: absolute e - s - size
			if 2 < max ds/x ds/y [return no]		;@@ OK to have 2px difference?
		]
		yes
	]

	; ;@@ TODO: always test fonts separation for used fonts?
	; alphabet: "bdeghilopqsz123567890!-*+~@$%^^()=':;,.<>"
	; foreach font-name ["Arial" "Tahoma" "Verdana" "Courier New" "Lucida Console"][; "Sylfaen" "Times New Roman"] [
	; 	font: make font! [name: font-name size: 100]
	; 	s: "00"
	; 	foreach a alphabet [
	; 		s/1: a
	; 		foreach b alphabet [
	; 			s/2: b
	; 			gc: glyph-count? s font
	; 			if gc <> 2 [			;-- longer is buggy too
	; 				either gc < 2
	; 					[print [font-name mold s "---"]]
	; 					[print [font-name mold s "+++"]]
	; 			]
	; 		]
	; 	]
	; ]
]
