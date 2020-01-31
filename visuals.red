Red [
	title:   "doping mark two"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %boxes.red
#include %dope.red

; #where's-my-error?

do-queued-events: does [
	loop 100 [unless do-events/no-wait [break]]		;-- limit to 100 in case of a deadlock
]


activate: func [face [object!]] [
	activate* face/state/1
]


;@@ default `face?` doesn't work on loaded stuff ):
quacks-like-face?: func [o] [
	empty? exclude exclude words-of face! words-of o [on-change* on-deep-change*]		;-- mold does not return on*change* 
]

;@@ TODO: when out of memory, re-run the clicker and continue where left off! because images are heavy and can't be known if in use


screenshot: does [capture]		;-- no refinements for it

;@@ TODO: automatic screen capture test as well, and check the RAM growth, and also the desktop (or artificial) background color
capture: func [
	"Capture the screen or a part of"
	/into im [image! none!] "Use an existing image buffer (none allocates a new one and is synonymous to no /into)"
	/area nw [pair!] se [pair!] "Specify north-west and south-east corners rather than the whole screen"
	/real "NW and SE are in pixels (default: units)"
	/local dpi
][
	#assert [any [not area  nw/x < se/x]]
	#assert [any [not area  nw/y < se/y]]
	#assert [any [area  not real]]		;-- cannot use /real without /area
	if all [area not real] [
		nw: units-to-pixels nw
		se: units-to-pixels se
	]
	grab-screenshot* im nw attempt [se - nw]
]

;; two alternatives to (broken) `to-image face`:
;; - using `to-image window` and
;; - using `capture` (reliable but requires no overlapping)
;; NOTE: does not include the non-client area when used on windows (contrary to to-image)
capture-face: function [
	"Capture an image of the FACE (like to-image)"
	face [object!]
	/real "Get real on-screen appearance (could be overlapped!)"
	/with img [image!] "Provide an already captured whole window image"
][
	win: window-of face
	#assert [any [handle? win/state/1 integer? win/state/1]]		;-- handle must be set!
	bor: borders-of win
	siz: units-to-pixels face/size
	either real [
		ofs: get-client-offset face/state/1
		capture/area/real ofs ofs + siz
	][
		default img: [to-image win]
		ofs: bor/1 + units-to-pixels face-to-window 0x0 face
		get-image-part img ofs siz
	]
]

;; `to-image window` alternative
capture-window: function [
	"Capture an image of the WINDOW"
	window [object!]
	/real "Get real on-screen appearance (could be overlapped!)"
][
	#assert ['window = window/type]
	either real [
		bor: borders-of window
		; siz: units-to-pixels window/size		;-- has a rounding error of up to 1px
		img: to-image window  siz: img/size		;-- use the size provided by to-image
		ofs: get-client-offset window/state/1
		capture/area/real ofs - bor/1 ofs - bor/1 + siz
		; capture/area/real ofs - bor/1 ofs + siz + bor/2
	][
		to-image window
	]
]


image-isochromatic?: func [image [image!]] [
	2 >= length? get-colorset image
]

image-empty?: function [image [image!]] [
	col: system/view/metrics/colors
	#assert [col/window]	;-- these should be defined by the backend	
	#assert [col/panel]
	all [
		2 >= length? cs: get-colorset image
		any [cs/1 = col/panel  cs/1 = col/window]
	]
]


find-edges: func [
	"Returns 2 blocks of edges [horizontal vertical] detected on the image"
	im [image!]
	/local h v
][
	h: make block! 100
	v: make block! 100
	find-edges* im h v
	reduce [h v]
]


;; right now simple - just chooses a box with the biggest area
find-window-on: function [
	"On a solid background - find a window (return it as object [size: offset:]); or none"
	image	[image!]
][
	r: object [size: 0x0 offset: none]
	foreach [_ offset size] find-boxes find-edges image [
		if r/size/x * r/size/y < (size/x * size/y) [
			r/size: size
			r/offset: offset
		]
	]
	all [r/offset r]
]


imprint-edges: function [
	"Imprints edges into an image"
	im		[image!]
	edges	[block!]
	color	[tuple!]
][
	foreach [prob y x1 x2] edges/1 [
		for x x1 x2 [poke im as-pair x y color * prob]
	]
	foreach [prob x y1 y2] edges/2 [
		for y y1 y2 [poke im as-pair x y color * prob]
	]
]

imprint-boxes: function [
	"Imprints boxes into an image"
	im		[image!]
	bxs		[block!]
	color	[tuple!]
][
	foreach [prob xy1 xy2] bxs [
		y1: xy1/y  y2: xy2/y
		x1: xy1/x  x2: xy2/x
		c: color * prob
		for x x1 x2 [
			poke im as-pair x y1 c
			poke im as-pair x y2 c
		]
		for y y1 y2 [
			poke im as-pair x1 y c
			poke im as-pair x2 y c
		]
	]
]


;@@ TODO: test this function in tests - draw is quite unreliable
get-image-part: func [img [image!] ofs [pair!] size [pair!] /into tgt [image!]] [
	draw any [tgt size] compose [image img crop (ofs) (size)]
]


;@@ TODO: automatic zoom/exploration window for failed tests
upscale: function [image [image!] by [number!] /into tgt [image!]] [
	cache: [0x0]										;-- somewhat faster this way
	either cache/1 <> image/size [
		clear change cache image/size
		box: compose [pen coal box 0x0 (by * 1x1)]
		xyloop xy image [
			append cache compose/only [
				fill-pen (image/:xy)
				translate (xy - 1x1 * by)
				(box)
			]
		]
	][
		i: 3
		foreach c image [
			cache/:i: c
			i: i + 5
		]
	]
	draw any [tgt image/size * by] next cache
]


explore: function [
	"Opens up a window to explore an image in detail"
	im [image!]
][
	factor: 5		;-- low values generate too much latency
	scr: system/view/screens/1/size
	im2: make image! scr * 3x6 / 10
	sz2: im2/size + (factor * 2 - 1) / factor / 2
	im3: make image! sz2 * 2
	ofs-scale*100: 100 * im/size / sz1: scr * 0.6
	r: reactor [center: 0x0]
	view compose [
		part:  image (im2/size) im2
		whole: image (sz1) (im)
		all-over on-over [r/center: event/offset]
		react [
			im3/rgb: coal								;-- fill the background
			part/image:
				upscale/into
					get-image-part/into im r/center * ofs-scale*100 / 100 - sz2 sz2 * 2 im3
					factor
					im2
		]
	]
]


; ██████ DIALECTIC STUFF ██████


~at~: make op!
face-at: function [
	"Return a screen coordinate of a described POINT in a FACE"
	face	[object!]
	point	[pair! block!] "Offset or [anchor +/- pair/integer ...]"
	/local v-anchor h-anchor v-oper h-oper v-offset h-offset
][
	if pair? point [return face-to-screen point face]

	=v-anchor=: [set v-anchor ['top | 'middle | 'bottom] opt =v-offset=]
	=h-anchor=: [set h-anchor ['left | 'center | 'right] opt =h-offset=]
	=anchors=: [opt [=h-anchor= opt =v-anchor= | =v-anchor= opt =h-anchor=]]
	=v-offset=: [set v-oper ['+ | '-]  set v-offset [integer! | pair!]]
	=h-offset=: [set h-oper ['+ | '-]  set h-offset [integer! | pair!]]
	unless parse point =anchors= [ERROR "Invalid `at` block: (point)"]

	xy: face/size / 2		;-- default position - center/middle
	if v-anchor [
		xy/y: switch v-anchor [
			top		[1]
			middle	[face/size/y / 2]
			bottom	[face/size/y]
		]
	]
	if h-anchor [
		xy/x: switch h-anchor [
			left	[1]
			center	[face/size/x / 2]
			right	[face/size/x]
		]
	]
	if integer? v-offset [v-offset: 0x1 * v-offset]
	if integer? h-offset [h-offset: 1x0 * h-offset]
	if v-oper [xy: xy + do reduce [0x0 v-oper v-offset]]
	if h-oper [xy: xy + do reduce [0x0 h-oper h-offset]]
	face-to-screen xy face
]


context [
	coerce: func ['word [word!] type [datatype!]] [
		if any [word? get word path? get word] [set word get get word]
		;@@ TODO: log-trace coercions?
		type = type? get word
	]


	;; uses `coerce`
	set 'amount-of function [
		"Count the amount (%) of COLOR on an IMAGE"
		spec	[block!] "E.g. [red on img], [almost blue on img]"
	][
		unless parse/case spec [
			set verb opt ['almost | 'all] (default verb: ['all])
			[	set color issue! (color: to tuple! color)
			|	set color [tuple! | word!] if (coerce color tuple!)
			]
			'on					;@@ TODO: any more verbs applicable?
			set image [image! | word!] if (coerce image image!)
		] [ERROR "amount-of: invalid color selection spec (mold spec)"]

		req-match: select [all 100% almost 90%] verb		;-- required similarity of image colors to the one provided
		cs: get-colorset image
		total: image/size/x * image/size/y
		0% + sum map-each [clr cnt] cs [				;-- count coverage of matching colors; 0% so it always returns %
			match: 100% - contrast clr color
			either match < req-match [0%][100% * cnt / total]
		]
	]


	box-parse: function [
		"Internal. Parse box dialect spec block into an object"
		spec [block!]
		/local
			where-op color-op cover-op
			h-anchor v-anchor
	][
		=where=: [
			opt quote where:
			set where-op opt ['at | 'on | 'within | 'inside | 'around]
			[
				ahead path! into [set where word! set area word!]
				if (coerce area object!)
			|	set where word! (area: none)
			]
			if (coerce where image!)
			(if none? where-op [where-op: 'around])		;-- default to 'around' mode
		]
		
		=offset=: [
			opt quote offset:
			set offset [pair! | word! | path!]
			if (coerce offset pair!)
		]

		=v-anchor=: [set v-anchor ['top | 'middle | 'bottom]]
		=h-anchor=: [set h-anchor ['left | 'center | 'right]]
		=h+v-anchors=: [=h-anchor= opt =v-anchor= | =v-anchor= opt =h-anchor=]
		=anchors=: [
			opt [quote anchors: | quote anchor:]
			=h+v-anchors=
		]

		=size=: [
			opt quote size:
			set size [pair! | word! | path!]
			if (coerce size pair!)
		]

		=coverage=: [
			opt quote coverage:
			set cover-op opt ['= | '> | '< | '<= | '>=]
			set coverage percent!
		]

		=coloration=: [
			opt quote color:
			set color-op ['all | 'almost]	;@@ more? `somewhat`?
			set color [tuple! | word! | path!]
			if (coerce color tuple!)
		]

		=spec=: [
			[	=where=
				opt [if (find [at on] where-op) [=anchors= | =offset=]]		;-- only allow position for at/on
				opt [if (where-op <> 'around) =size=]						;-- disable size in 'around' mode (size equals area/size)
			|	=size= =where= if (where-op <> 'around)
				opt [if (find [at on] where-op) [=anchors= | =offset=]]
			]
			opt [=coverage= =coloration= | =coloration= =coverage=]
		]

		unless parse/case spec =spec= [ERROR "Invalid box spec: (mold spec)"]

		either path? where [
			set [image area] as block! where
			if 2 < length? where [ERROR "Invalid box spec (mold spec): extra path items in (where)"]
		][image: where]

		foreach [word type] [
			image  image!
			area   object!		;-- can be result of `box` or face!
			size   pair!
			offset pair!
			color  tuple!
		][
			type: get type
			word: get word
			if any [word? :word path? :word] [
				value: get word
				unless type = type? :value [
					ERROR "Invalid box spec (mold spec): (word) evaluates to (mold type? :value), expected (mold type)"
				]
			]
		]

		words: [where-op image area h-anchor v-anchor offset size cover-op coverage color-op color]
		object map-each/eval w words [[to set-word! w 'quote get w]]
	]

	test-coverage: function [
		"Internal. Test coverage and coloration of an IMAGE given SPEC"
		image	[image!]
		spec	[object!] "Only /coverage /cover-op /color /color-op are used"
		/part offset [pair!] size [pair!] "Specify a region only"
	][
		unless spec/color [return yes]			;-- if no color info specified - it's an automatic match
		#assert [all [spec/coverage spec/cover-op spec/color-op]]

		if part [image: get-image-part offset size]
		;@@ TODO: maybe exclude borders? eat a pixel from all sides? to account for scaling inaccuracies

		cs: get-colorset image
		req-match: select [all 100% almost 90%] spec/color-op		;-- required similarity of image colors to the one provided
		total: image/size/x * image/size/y
		coverage: sum map-each [color count] cs [					;-- count coverage of matching colors
			match: 100% - contrast color spec/color
			either match < req-match [0%][100% * count / total]
		]
		do reduce [coverage cover-op spec/coverage]					;-- test the coverage requirement ;@@ TODO: log this if it fails?
	]


	comment {
		BOX FORMAT ("AREA") (returned by `box` func): [offset [pair!] size [pair!]]
		BOX SPEC (accepted by `box` func):
		size: pair!
		offset: pair!
		dimensions: offset [pair!] size [pair!] - can be words/paths evaluating to pairs
		location:   `at`/`on`/`within` area [word! path!] offset/anchors - first word in path is an image, second (if present) can be another box or face
			(without prefix) area [word! path!] - fetches offset and size from `area` - for existence checking of a specific box
		anchors: top/left/center/middle/right/bottom - specify the relative positioning (vs absolute offset) (relative positions are less restrictive!)
		coloration: operator [> < =] coverage [percent!] `all`/`almost` color [tuple!] - operator defaults to `=`, can be omitted
	}

	set 'box function [
		"Find a box on an image given some characteristics"
		spec [block!]
	][
		spec: box-parse spec
		#assert [spec/image]
		#assert [spec/where-op]

		u->p: :units-to-pixels
		p->u: :pixels-to-units

		bestbox: function [image area] [
			#assert [object? area]
			edges: find-edges image
			xy2: area/size + xy1: area/offset
			set [prob xy1 xy2]  fit-box  edges  u->p xy1  u->p xy2
			all [										;-- return none or [offset size]
				0 <> prob								;-- 0% = no match
				reduce [xy1  xy2 - xy1]					;-- return real pixels - for possible image cropping
			]
		]

		scan4box: function [image box-size /anchors h v] [
			boxes: find-boxes find-edges image
			all [
				box: either anchors
					[find-box/anchors boxes u->p box-size h v image/size]
					[find-box         boxes u->p box-size]
				reduce [box/2 box/3 - box/2]		;-- return [offset size]
			]
		]

		image: spec/image

		either spec/where-op = 'around [
			area: spec/area			;-- `area` defines a box on an `image`
			#assert [none? spec/offset]
		][
			if spec/area [			;-- won't be needing the whole image; crop it
				image: get-image-part
					image
					u->p spec/area/offset
					u->p spec/area/size
			]
			area: spec				;-- else use offset & size from spec itself
		]

		either spec/offset [				;-- no need to extract all boxes - have size and offset
			#assert [none? spec/h-anchor]		;-- anchors only make sense without offset
			#assert [none? spec/v-anchor]
			all [
				set [offset size] bestbox image area
				test-coverage/part image spec offset size
				object compose [offset: (p->u offset) size: (p->u size)]		;-- should be scaled, for compatibility with faces
			]
		][									;-- without offset we look for a box of a specific size among all boxes
			box: switch spec/where-op [
				inside within [scan4box image spec/size]
				at on [scan4box/anchors image spec/size h-anchor v-anchor]
			]
			all [
				set [offset size] box
				image: get-image-part image offset size
				test-coverage image spec
				object compose [offset: (p->u offset) size: (p->u size)]
			]
		]
	]

]