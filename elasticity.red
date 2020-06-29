Red [
	title:   "Elastic UI provider"
	purpose: "Automatic handling of resize GUI events"
	author:   @hiiamboris
	license:  BSD-3
	usage:   {
		#include %elasticity.red
		view/flags elastic [
			VID face declaration #anchor
			panel #anchor [
				more faces with #anchors or without them
			]
		] 'resize

		Supported anchors are:
			#ignore = #ignore-x #ignore-y     -- [default if no anchor provided] - ignored by the geometry manager (fixed size & offset)
			#fix    = #fix-x    #fix-y        -- size is fixed, offset is scaled proportionally to window size 
			#scale  = #scale-x  #scale-y      -- both size and offset are scaled proportionally to window size 
			#fill   = #fill-x   #fill-y       -- same as #scale but fills the available space and avoids collision (with fixed faces)

		TODO: detect destroyed faces somehow and forget?
		TODO: how to be friendly to manual resize of panels? they produce no resize events to hook to
		  I could create reactions for `size` facet of all panels, but this may be too much overhead
		  alternatively, I could export `handle-resize` for manual invocation
	}
	needs:    view
]


context [
	abs: :absolute
	->:  make op! func [a b] [select/same :a :b]
	|=:  make op! func [a b] [append :a :b]
	|=1: make op! func [a b] [append/only :a :b]
	maybe: func [:w [set-path!] v][
		w: as path! w									;-- workaround for #4448
		if :v <> get/any w [set/any w :v]				;-- this version returns none if it doesn't change the value!
	]

	;; grouped by axis
	anchors: [ x: [ignore-x fix-x fill-x scale-x] y: [ignore-y fix-y fill-y scale-y] ]
	macros: [
		fix    [fix-x    fix-y   ]
		fill   [fill-x   fill-y  ]
		scale  [scale-x  scale-y ]
		ignore [ignore-x ignore-y]						;-- already default ;@@ TODO: change defaults with a hashtag?
	]
	anchors*: compose [(anchors/x) (anchors/y) (extract macros 2)]

	anchor-of: function ['type [word!] "X or Y" bl [block!] "anchor words block"] [
		s: form any [last intersect anchors/:type bl  anchors/:type/1]
		to word! replace replace s "-x" "" "-y" ""
	]

	set 'elastic function [												;-- recursive: enters panel
		"Preprocess layout block containing anchors"
		layout [block!]
		/local w
	][
		fix-styles														;-- useful when defining own styles after importing the elasticity
		styles: copy system/view/VID/styles
		groups: collect [
			foreach [name spec] styles [
				if spec/template/type = 'panel [keep name]
			]
		]
		align: copy []													;-- accumulator for anchor words
		flush: does [													;-- places the accumulated anchors into a with block
			if empty? align [return []]
			foreach [m v] macros [replace/all align m v]
			align: reduce [anchor-of x align  anchor-of y align]
			expr: compose/only [anchors: (copy align)]
			either with [
				tail with |= expr
			][	compose/only [with (expr)]
			]
		]
		parse fix: layout [any [
			'style set w set-word! (put styles to word! w yes)			;-- a new style declared - consider it too
		|	'with set with block!										;-- use provided `with` block instead of overriding it
		|	['data | 'extra] skip										;-- skip data blocks and words
		|	set w word! if (styles/:w)									;-- found a new widget
			(insert fix b: flush n: length? b) n skip fix: 				;-- fix the previous one and remember a new fix position
			(style: w  with: none  clear align)							;-- reset the style and accumulators
		|	remove [set a issue! if (attempt [find anchors* a: to word! a])]	;-- acceptable anchor found; attempt defends against #608-like issues
			(align |= a)												;-- save it
		|	if (find groups style) set b block! (elastic b)				;-- recursively process panels
		|	skip
		] end (insert fix flush)]
		layout															;-- chain the result into view or whatever
	]


	geometries: make hash! []			;-- holds the first known geometry of each face; map does not allow objects so using hash
	margins: make hash! []				;-- cache for margins

	check-geometry: function [fa [object!]] [			;-- checks if face's original geometry is known and returns it
		unless geom: geometries -> fa [
			;; remember the initial geometry
			pa: fa/parent
			unless fa/offset [return reduce [no none]]	;@@ TODO: or issue a warning about this?
			repend geometries [fa geom: compose [
				offset:   (fa/offset)
				size:     (fa/size)
				area:     (pa/size)						;-- required for newly created faces
				origin:   (								;-- avoid / 0x0 : when pa/size = fa/size, set origin to center
					a: fa/offset * pa/size  b: pa/size - fa/size
					as-pair
						any [attempt [a/x / b/x] pa/size/x / 2]
						any [attempt [a/y / b/y] pa/size/y / 2]
				)
			]]
			return reduce [no geom]
		]
		reduce [yes geom]
	]

	paddings-of: function [
		"Calculate paddings of face FA within the known box list GEOMETRIES"
		fa [object!] geometries [hash!]
	][
		fgeom: geometries -> fa
		pgeom: any [geometries -> pa: fa/parent pa]		;-- for screen - uses itself
		e: fgeom/size + s: fgeom/offset
		r1: s  r2: pgeom/size - e						;-- start with min distances (x y) to parent bounds
		foreach x [x y] [								;-- ignore negative margins (clipped by the parent)
			if r1/:x < 0 [r1/:x: 1000]
			if r2/:x < 0 [r2/:x: 1000]
		]
		if all [r1 = 1000x1000 r2 = r1] [r1: r2: 0x0]	;-- fully clipped, no meaningful margin data: default to 0x0
		foreach f' pa/pane [							;-- try to find closer faces
			g': any [geometries -> f'  f']
			e': g'/size + s': g'/offset
			foreach [x y] [x y y x] [
				if all [s'/:y < e/:y  e'/:y > s/:y] [					;-- shares same horizontal / vertical
					if 0 <= dist: s/:x - e'/:x [r1/:x: min r1/:x dist]	;-- neighbor left / above
					if 0 <= dist: s'/:x - e/:x [r2/:x: min r2/:x dist]	;-- neighbor right / below
				]
			]
		]
		reduce [max 0x0 r1  max 0x0 r2]					;-- treat negative margins as 0 (in case face is bigger than it's pane)
	]

	original-margin: function [
		"Calculate first known margin (min proximity to other faces) of face FA"
		fa [object!]
	][
		unless r: select/same margins fa [
			pads: paddings-of fa geometries
			r: min pads/1 pads/2
			repend margins [fa r: min r/x r/y]
		]
		r
	]

	dist?: func [xy1 [pair!] xy2 [pair!]] [
		xy1: xy1 - xy2
		xy1: xy1 * xy1
		xy1/x + xy1/y ** 0.5
	]

	intersect-boxes: function [g1 [block! object!] g2 [block! object!]] [
		o1: g1/offset  o2: g2/offset  s1: g1/size  s2: g2/size
		x1: max o1/x o2/x  x2: min o1/x + s1/x o2/x + s2/x
		y1: max o1/y o2/y  y2: min o1/y + s1/y o2/y + s2/y
		all [
			x1 < x2			;-- return none if zero intersection
			y1 < y2
			compose [offset: (as-pair x1 y1) size: (as-pair x2 - x1 y2 - y1)]
		]
	]

	corners-of: function [geom [block! object!]] [
		o: geom/offset s: geom/size
		reduce [o  s * 1x0 + o  s + o  s * 0x1 + o]
	]

	center-of: func [geom [block! object!]] [geom/size / 2 + geom/offset]

	clip: function [
		"Clip box G1 with box G2, in place"
		g1 [block! object!] g2 [block! object!]
		/only axis [word! none!] "Restrict clipping to single axis X/Y"
	][
		unless g2: intersect-boxes g1 g2 [return yes]	;-- no intersection? - no need to clip

		;; choose the center to clip from
		center1: g1/origin								;-- ideally it's the origin
		; center1: g1/size / 2 + g1/offset
		corners1: corners-of g1
		while [within? center1 g2/offset g2/size + 1] [		;-- but if it's inside the other face
			center1: corners1/1							;-- try using any of it's corners
			unless center1 [return no]					;-- if no outside point found, do not clip the face at all
			corners1: next corners1
		]

		center2: center-of g2
		nearest: first sort/skip/compare collect [		;-- clip with nearest of four corners of g2 sorted by proximity
			foreach c corners-of g2 [keep reduce [c  dist? c center1]]
		] 2 2

		vec: center2 - center1							;-- direction to the clipping face
		axis: any [
			axis
			either (abs vec/x) >= (abs vec/y) ['x]['y]	;-- axis if not given determined by vec direction
		]

		;; clip the g1 in place
		either vec/:axis >= 0 [							;-- to the right/bottom
			new: nearest/:axis - g1/offset/:axis
			if new <= 0 [return no]						;-- no way to sanely clip it, so don't
			g1/size/:axis: new
		][												;-- to the left/top
			new: g1/size/:axis - nearest/:axis + g1/offset/:axis
			if new <= 0 [return no]						;-- no way to sanely clip it, so don't
			g1/size/:axis:   new
			g1/offset/:axis: nearest/:axis
		]
		yes												;-- clipping succeeded
	]

	exclude-face: func [pane [block!] face [object!]] [head remove find/same copy pane face]

	fill: function [
		"Try to expand face FA within the known box list GEOMETRIES', return new geometry without origin"
		fa [object!] geometries' [hash!] "When does not contain required face - face's real geometry is used"
		/only axis [word!] "Restrict expansion to single axis X/Y"
	][
		pa: fa/parent

		;; clip face to remove any overlaps
		geom: geometries' -> fa									;-- start with it's current geometry
		bad?: no												;-- catastrophic overlap indicator - do not use paddings
		foreach fa' exclude-face pa/pane fa [
			geo': any [geometries' -> fa'  fa']
			bad?: bad? or not clip/only geom geo' axis
		]

		;; multiple clippings may reduce the face too much: try to expand it now
		unless bad? [
			margin: (original-margin fa) * pa/size / max 1x1 geom/area	;-- scale original margins to current parent size

			;; can't reliably expand along 2 axes at once, only one by one (X then Y?):
			foreach x [x y] [
				all [axis axis <> x continue]					;-- do not expand over forbidden axes
				pads: paddings-of fa geometries'
				geom/offset/:x: geom/offset/:x - pads/1/:x
				geom/size/:x: geom/size/:x + pads/1/:x + pads/2/:x

				;; try to subtract margins from the face now that it's expanded
				if geom/size/:x > (margin/:x * 2) [				;-- face is still nonzero after subtraction?
					geom/size/:x: geom/size/:x - (margin/:x * 2)
					geom/offset/:x: geom/offset/:x + margin/:x
				]
			]
		]
		geom
	]

	handle-resize: function [
		"Resize all child faces of face PA when it was resized"
		pa [object!] "Parent face"
		/local size offset area origin					;-- used by `do bind`
	][
		; print ["-ENTERING-" pa/type pa/size "AT" pa/offset]
		pending: make hash! []
		to-fill: make hash! []							;-- faces to correct after placement

		;; first just rescale/reposition faces, save into `pending` list
		foreach fa pa/pane [
			anks: select fa 'anchors
			unless block? :anks [continue]				;-- hijacked? or custom style without anchors? - ignore it
			if anks = [ignore ignore] [continue]		;-- does not require any action
			set [x-anchor y-anchor] anks

			unless geom: second check-geometry fa [continue]		;-- skip uninitialized faces
			do bind geom 'local										;-- start with the original geometry
			foreach [x anchor] compose [x (x-anchor) y (y-anchor)] [
				if anchor = 'ignore [
					offset/:x: fa/offset/:x							;-- use current geometry, not the one remembered
					size/:x:   fa/size/:x
					continue
				]
				scale: 1.0 * pa/size/:x / max 1 area/:x				;-- scale everything compared to the initial size
				origin/:x: to integer! origin/:x * scale
				size/:x: either anchor = 'fix [size/:x] [to integer! size/:x * scale]
				offset/:x: to integer! origin/:x * (pa/size/:x - size/:x) / max 1 pa/size/:x
				if anchor = 'fill [									;-- schedule the expansion for fill-anchors
					pos: all [x = 'y  find/same/tail to-fill fa]	;-- `put` reinvention
					either pos [ insert pos x ][ repend to-fill [fa x] ]
				]
			]
			repend pending [fa compose [offset: (offset) size: (size) area: (area) origin: (origin)]]
		]

		;; now try to clip & expand `fill` faces after all other ones are positioned
		forall to-fill [
			fa: to-fill/1  to-fill: next to-fill
			geom': pending -> fa
			either find/match to-fill [y x] [			;-- clip/expand over both axes at once
				new': fill fa pending
				; change geom' new'				- this crashes - see #4087, so..
				geom'/offset: new'/offset  geom'/size: new'/size
				to-fill: next to-fill
			][											;-- clip/expand over single axis
				new': fill/only fa pending x: to-fill/1
				geom'/offset/:x: new'/offset/:x
				geom'/size/:x:   new'/size/:x
			]
		]

		old: system/view/auto-sync?
		maybe system/view/auto-sync?: no
		foreach [fa geom'] pending [					;-- commit the changes
			; print [{OFFSET} fa/offset {->} geom'/offset "FOR" fa/type "OF" fa/size]
			maybe fa/offset: geom'/offset
			unless fa/size = geom'/size [
				if panel?: not empty? fa/pane [			;-- remember old child geometries before the resize
					foreach f' fa/pane [check-geometry f']
				]
				maybe fa/size: geom'/size
				if panel? [handle-resize fa]			;-- descend into child faces and resize them
			]
		]
		maybe system/view/auto-sync?: old
		if pa/type = 'window [show pa]
	]

	fix-styles: function ["Ensures every style contains the anchors facet"] [
		foreach [name style] system/view/VID/styles [
			unless any [
				name = 'window							;-- exclude window as it is unaffected anyway and to escape #4396
				find/case style/template [anchors:]		;-- exclude styles already containing the anchor block
			][
				append style/template [anchors: [ignore ignore]]
			]
		]
	]

	evt-func: function [fa [object!] ev [event!]] [
		all [
			find [resizing resize] ev/type				;-- resize event
			first check-geometry fa						;-- on a face which geometry is already known (saves it otherwise)
			fa/type = 'window							;-- it's a window (it's always a window?)
			handle-resize fa							;-- resize it
		]
		none											;-- the event can be processed by other handlers
	]

	unless find/same system/view/handlers :evt-func [	;-- multiple includes protection
		fix-styles
		insert-event-func :evt-func
	]
]

