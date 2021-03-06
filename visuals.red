Red [
	title:   "doping mark two"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %include.red

; #include %/d/devel/red/common/show-trace.red
include %common/contrast-with.red
include %common/do-queued-events.red
include %common/explore.red
do %relativity.red			;@@ BUG: required after `explore.red` which loads other more simple relativity version!
include %dope.red
include %boxes.red
include %elasticity.red


;@@ TODO: show images as thumbnails in the log
once visuals-ctx: context [

	activate: func [face [object!]] [
		#assert [any [handle? face/state/1 integer? face/state/1]]
		activate* face/state/1
	]

	minimize: func [face [object!]] [
		#assert [any [handle? face/state/1 integer? face/state/1]]
		minimize* face/state/1
	]

	restore: func [face [object!]] [
		#assert [any [handle? face/state/1 integer? face/state/1]]
		restore* face/state/1
	]



	;; default `face?` doesn't work on loaded stuff as it compare by object class id ):
	quacks-like-face?: func [o] [
		all [
			object? :o
			empty? exclude exclude words-of face! words-of o [on-change* on-deep-change*]		;-- mold does not return on*change* 
		]
	]

	;@@ TODO: when out of memory, re-run the clicker and continue where left off! because images are heavy and can't be known if in use


	screenshot: has ["Grab a screenshot without the taskbar"] [capture/no-taskbar]		;-- no refinements for it

	gen-name-for-capture: does [#composite %"(current-key)-capture-(timestamp).png"]

	save-capture: function [im [image!] /as name [file! string!]] [
		#assert [0 < length? im "cannot save an empty capture!"]
		name: any [all [name copy name] gen-name-for-capture]
		part: skip tail name -4
		i: 0
		while [exists? name] [
			append clear part rejoin ["-" i: i + 1 ".png"]
		]
		save/as name im 'png
		name
	]

	;@@ TODO: automatic screen capture test as well, and check the RAM growth, and also the desktop (or artificial) background color
	capture: function [
		"Capture the screen or a part of"
		/into im [image! none!] "Use an existing image buffer (none allocates a new one and is synonymous to no /into)"
		/area nw [pair!] se [pair!] "Specify north-west and south-east corners rather than the whole screen"
		/real "NW and SE are in pixels (default: units)"
		/no-save "Do NOT save the image automatically"
		/no-taskbar "Try to remove the taskbar from the screenshot when shooting the whole screen"
	][
		#assert [any [not area  nw/x < se/x]]
		#assert [any [not area  nw/y < se/y]]
		#assert [any [area  not real]]		;-- cannot use /real without /area
		if all [area not real] [
			nw: units-to-pixels nw
			se: units-to-pixels se
		]
		im: grab-screenshot* im nw attempt [se - nw]
		#assert [0 < length? im "empty capture detected!"]
		if all [no-taskbar  not area] [im: discard-taskbar im]
		unless no-save [log-image im]
		im
	]


	;; alternative to (broken and limited) `to-image face`
	capture-face: function [
		"Capture an image of the FACE (like to-image, but reliable)"
		face [object!]
		/real "Get real on-screen appearance (could be overlapped!)"		;-- use `activate` before this!
		/whole "Include non-client area (only has effect if face is a window)"
		/with img [image!] "Provide an already captured whole window image to crop from"
	][
		#assert [quacks-like-face? face]
		#assert [not all [real with]]		;-- /with makes /real meaningless

		wndw: either window?: face/type = 'window [face][window-of face]

		either real [
			pix-ofs: client-offset-of face
			either window? [
				pix-sz: size-of wndw							;-- need precise non-rounded size of it
				brdr: borders-of wndw
				either whole
					[pix-ofs: pix-ofs - brdr/1]					;-- translate client offset to nonclient offset
					[pix-sz:  pix-sz  - brdr/1 - brdr/2]		;-- contract the capture size
			][
				pix-sz: size-of face
			]
			#assert [0 < pix-sz/x]
			#assert [0 < pix-sz/y]
			capture/area/real pix-ofs pix-ofs + pix-sz			;-- `capture` saves and logs the result
		][
			#assert [any [img  face? wndw]]						;-- if it just 'quacks-like', to-image branch will crash
			img: any [img to-image wndw]
			brdr: borders-of wndw
			either window? [
				unless whole [img: get-image-part img brdr/1 img/size - brdr/2 - brdr/1]
			][
				pix-ofs: (client-offset-of face) - (client-offset-of wndw) + brdr/1
				pix-sz: size-of face
				img: get-image-part img pix-ofs pix-sz
			]
			#assert [0 < length? img]
			log-image img										;-- manually save and log the result
			img
		]
	]


	image-monochromatic?: image-isochromatic?: func [image [image!]] [
		2 >= length? get-colorset image
	]

	image-empty?: function [
		"Check if the IMAGE is empty (that is isochromatic and of window background color)"
		image [image!]
	][
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


	;; the moment worker (another process) displays a view, the taskbar pops up over the background
	;; we don't want to analyze taskbar contents, so have cut it off programmatically
	;@@ TODO: the logic will be different for other platforms
	discard-taskbar: function [
		"Get part of the screenshot without the taskbar"
		shot [image!]
		/local he ve
	][
		set [he ve] find-edges shot
		;; - not considering the extreme "taskbar of half of the screen size" conditions here!
		;; - it's important to choose the farthest line from the screen corner as edges are tripled usually
		;; @@ what about widget panels? can they also jump on top of the background?
		ss: shot/size
		reserve: ss - units-to-pixels 50		;@@ ok to have 50px reserve? 2px must work in most setups
		band: units-to-pixels 100
		foreach [x y edges] [x y he y x ve] [
			chosen: dist: 0
			foreach [pro y0 x1 x2] get edges [					;-- find where to cut from
				all [
					x2 - x1 >= reserve/:x						;-- wide enough edge
					any [band >= d: y0  band >= d: ss/:y - y0]	;-- close enough to screen corners
					d > dist									;-- further than the chosen line from the corners
					dist: d  chosen: y0							;-- choose it
				]
			]
			if dist > 2 [										;-- 2px is too small for taskbar
				ofs: chosen * mask: select [x 0x1 y 1x0] x
				return either chosen <= band [
					get-image-part  shot  ofs  ss - ofs				;-- cut from the top/left
				][	get-image-part  shot  0x0  ss - (ss * mask - ofs)	;-- from the bottom/right
				]
			]
		]
		shot
	]


	;; right now simple - just chooses a box with the biggest area, no less than 50x50 (otherwise detects taskbar)
	find-window-on: function [
		"On a solid background - find a window (return it as object [size: offset:]); or none"
		image	[image!]
	][
		; save/as %buggy-image.png image 'png
		r: object [size: base: 0x0 offset: none]
		foreach [_ xy1 xy2] find-boxes find-edges image [
			size: pixels-to-units xy2 - xy1 + 1
			if r/size/x * r/size/y < (size/x * size/y) [
				r/size: size
				r/offset: pixels-to-units xy1
			]
		]
		log-artifact object [
			type: 'window
			box: r
			key: current-key
		]
		all [
			r/offset
			r/size/x >= 50
			r/size/y >= 50
			r
		]
	]


	imprint-edges: function [
		"Imprints edges into an image"
		im		[image!]
		edges	[block!]
	][
		~:  make op! :as-pair
		++: make op! :at
		foreach [prob y x1 x2] edges/1 [
			for x x1 x2 [i: im ++ (x ~ y) i/1: 1.0 - prob * i/1 + (prob * contrast-with i/1)]
		]
		foreach [prob x y1 y2] edges/2 [
			for y y1 y2 [i: im ++ (x ~ y) i/1: 1.0 - prob * i/1 + (prob * contrast-with i/1)]
		]
		im
	]

	imprint-boxes: function [
		"Imprints boxes into an image"
		im		[image!]
		bxs		[block!]
		color	[tuple!]		;-- has to be opaque, else inversion negates itself
	][
		~:  make op! :as-pair
		++: make op! :at
		foreach [prob xy1 xy2] bxs [
			y1: xy1/y  y2: xy2/y
			x1: xy1/x  x2: xy2/x
			prob2: 1.0 - prob
			for x x1 x2 [
				i: im ++ (x ~ y1) i/1: prob * color + (prob2 * i/1)
				i: im ++ (x ~ y2) i/1: prob * color + (prob2 * i/1)
			]
			for y y1 y2 [
				i: im ++ (x1 ~ y) i/1: prob * color + (prob2 * i/1)
				i: im ++ (x2 ~ y) i/1: prob * color + (prob2 * i/1)
			]
		]
		im
	]


	;; colors are matched strictly! only coverage is allowed to diverge
	matching-colorsets?: function [
		"Check if images IM1 and IM2 have similar color sets"
		im1		[image!]
		im2		[image!]
		fuzz	[percent!] "Coverage comparison fuzziness, absolute (0% = strict)"
	][
		cs1: get-colorset im1
		cs2: get-colorset im2
		tot1: im1/size/x * im1/size/y
		tot2: im2/size/x * im2/size/y
		foreach [cs1 cs2 tot1 tot2] reduce [cs1 cs2 tot1 tot2  cs2 cs1 tot2 tot1] [		;-- match cs1 to cs2, then cs2 to cs1
			foreach [clr cnt1] cs1 [
				amnt1: 100% * cnt1 / tot1
				if amnt1 <= fuzz [break]		;-- other colors are insignificant
				in2: find/skip cs2 clr 2
				cnt2: in2/2
				amnt2: 100% * cnt2 / tot2
				if any [
					none? cnt2					;-- matching color not found
					fuzz < abs amnt2 - amnt1	;-- covered area is too different
				] [return no]
				remove/part in2 2				;-- do not match this color again
			]
		]
		yes
	]


	;@@ TODO: test this function in tests - draw is quite unreliable
	get-image-part: func [img [image!] ofs [pair!] size [pair!] /into tgt [image!]] [
		either tgt [
			draw tgt compose [image img crop (ofs) (size)]
		][	copy/part skip img ofs size
		]
	]


	;@@ TODO: replace these with the table/reflection
	zoom-factor?: function [
		"Determine the maximum zoom factor that allows to fit SRC-SIZE within DST-SIZE"
		src-size [pair!] dst-size [pair!]
	][
		min 1.0 * dst-size/x / max 1 src-size/x			;-- use the narrowest dimension
			1.0 * dst-size/y / max 1 src-size/y
	]

	scale-to-fit: function [
		"Upscale or downscale the image IMG to fit specific SIZE"
		img [image!]
		size [pair!]
	][
		ratio: zoom-factor? img/size size
		case [
			ratio >= 2.0 [upscale img to integer! ratio]
			ratio >= 1.0 [img]
			{less than 1.0} [								;-- downscale proportionally
				new-size: img/size * ratio
				foreach x [x y] [							;-- rounding correction; all pixels have to be visible
					if new-size/:x / ratio < img/size/:x [new-size/:x: new-size/:x + 1]
				]
				draw new-size compose [
					scale (ratio) (ratio) image img
				]
			]
		]
	]


	mix-images: function [im1 [image!] im2 [image!] offs1 [pair!] offs2 [pair!] amnt1 [percent! float!]] [
		cache: [#[none]]
		im2: either all [cache/1 cache/1/size = im2/size]
			[ draw cache/1 [image im2 0x0] ]		;@@ im2 should be opaque for this to work!
			[ cache/1: copy im2 ]
		im2/alpha: max 0 min 255 round/to 255 * amnt1 1
		draw im1/size compose [image im1 (offs1) image im2 (offs2)]
	]



	; ;@@ BUG: this will eat a lot of RAM - TODO: use this after GC can collect images
	; blur3x3: function [im [image!]] [
	; 	im-1: mix-images
	; 		mix-images im im -1x-1  1x1 50% 
	; 		mix-images im im  1x-1 -1x1 50% 
	; 		0x0 0x0 50%
	; 	im-2: mix-images
	; 		mix-images im im -1x0 1x0 50% 
	; 		mix-images im im 0x-1 0x1 50% 
	; 		0x0 0x0 50%
	; 	mix-images
	; 		mix-images im-1 im-2 0x0 0x0 33.3%
	; 		im 0x0 0x0 75%
	; ]


	; ;@@ BUG: this is not a proper blur, as each next image gets composed with the whole stack of previous images
	blur3x3: function [im [image!]] [
		im-1: copy im  im-1/alpha: 255 - 25
		im-2: copy im  im-2/alpha: 255 - 50
		draw copy im [
			image im-2 -1x0
			image im-2  1x0
			image im-2  0x1
			image im-2  0x-1
			image im-1 -1x-1
			image im-1  1x-1
			image im-1 -1x1
			image im-1  1x1
		]
	]


	;@@ TODO: routine or RedCV? also this needs calibration (I only checked it on a few simple images)
	;-- sensitive to both changes in overall brightness (1) and individual "outlier" pixels (2):
	;-- 1) sum of normalized pixel differences (NPD), checked against `fuzz` * area
	;-- 2) sum of squares of NPD *exceeding* given `fuzz`, checked against `fuzz` * area
	visually-similar?: function [
		"Loosely compare two images for equality"
		im1 [image!]
		im2 [image!]
		/with fuzz [percent! float!] "Comparison fuzziness (0% = strict, default = 10%)"
	][
		; #assert [im1/size = im2/size]
		unless im1/size = im2/size [ERROR "Images are expected to be of equal size, got (im1/size) and (im2/size)"]
		default fuzz: 10%
		if fuzz = 0% [fuzz: 0.01%]						;-- no zero division
		im1: blur3x3 im1								;-- blur images to lessen the effect of image offsets due to possible rounding errors
		im2: blur3x3 im2
		sum1: 0.0 sum2: 0.0 sumcsq: 0.0
		area: im1/size/x * im1/size/y
		max-sumcsq: 1.0 * fuzz * area					;-- sum of squares of pixel contrasts, allowing each pixel to have up to fuzz=contrast
		repeat i length? im1 [
			px1: im1/:i  px2: im2/:i
			sum1: sum1 + px1/1 + px1/2 + px1/3
			sum2: sum2 + px2/1 + px2/2 + px2/3
			c: (contrast px1 px2) / fuzz				;-- using custom 'contrast' definition sensitive to c >> fuzz
			sumcsq: c * c + sumcsq
			if sumcsq > max-sumcsq [
				; ? sumcsq ? max-sumcsq 
				return no
			]
		]
		; ? sumcsq ? max-sumcsq 
		sum-white: area * 3 * 255.0						;-- 3 for R,G,B, 255 for max brightness
		dif: (abs sum2 - sum1) / sum-white				;-- relative difference in overall brightness
		; ? dif
		dif <= (fuzz ** 2)
	]

	; ;@@ BUG: this is not a proper blur, as each next image gets composed with the whole stack of previous images
	; blur5x5: function [im [image!]] [
	; 	im-1:  copy im  im-1/alpha:  255 - 1
	; 	im-4:  copy im  im-4/alpha:  255 - 4
	; 	im-6:  copy im  im-6/alpha:  255 - 6
	; 	im-16: copy im  im-16/alpha: 255 - 16
	; 	im-24: copy im  im-24/alpha: 255 - 24
	; 	draw copy im [
	; 		image im-24 -1x0
	; 		image im-24  1x0
	; 		image im-24  0x1
	; 		image im-24  0x-1
	; 		image im-16 -1x-1
	; 		image im-16  1x-1
	; 		image im-16 -1x1
	; 		image im-16  1x1
	; 		image im-6   0x2
	; 		image im-6   0x-2
	; 		image im-6  -2x0
	; 		image im-6   2x0
	; 		image im-4  -2x-1
	; 		image im-4   2x1
	; 		image im-4  -1x-2
	; 		image im-4   1x2
	; 		image im-4   2x-1
	; 		image im-4  -2x1
	; 		image im-4   1x-2
	; 		image im-4  -1x2
	; 		image im-1  -2x-2
	; 		image im-1   2x2
	; 		image im-1  -2x2
	; 		image im-1   2x-2
	; 	]
	; ]


	explore-artifact: function [art [object!]] [
		;@@ TODO: add & show artifact time
		explore-value: function [v /name txt /local k] [
			case [
				object? o: :v [
					exp-map: copy #()
					if all [in o 'type  o/type = 'box] [
						exp-map/edges: [if edges [explore imprint-edges copy image edges]]
						exp-map/boxes: [if boxes [explore imprint-boxes copy image boxes magenta]]
						exp-map/box:   [if box   [explore imprint-boxes copy image reduce [100% box/1 box/1 + box/2] cyan]]
					]
					view/flags/options elastic map-each [k v] to block! o [
						compose/deep/only [
							text 60 (rejoin [k ":"])
							button 300 left (mold-part/flat :v 70) #fill-x
							on-click [
								either act: select exp-map (to lit-word! k)
									[do with o act]
									[explore-value/name quote (:v) (form k)]
							]
							return
						]
					] 'resize [
						text: #composite "Artifact (any [attempt [o/key] txt])"
						actors: object [
							on-key-up: func [fa ev] [if ev/key = #"^[" [unview/only fa]]	;-- make it ESC-closable
						]
					]
				]
				block? b: :v [
					view/flags/options elastic compose [
						area 300x200 #scale (mold/part :v 100000)
					] 'resize [
						text: #composite {Block "(txt)"}
						actors: object [
							on-key-up: func [fa ev] [if ev/key = #"^[" [unview/only fa]]	;-- make it ESC-closable
						]
					]
				]
				image? i: (v) [			;-- evaluates if it's a function - by design!
					explore/title i #composite {Image "(any [txt i/size])"}
				]
			]
		]
		explore-value art
	]


	glyphs-on: function [img [image!]] [
		bxs: find-glyph-boxes img
		#assert [block? bxs]
		#assert [even? length? bxs]

		object compose [
			found?: not empty? bxs
			count: (length? bxs) / 2
			offset:         glyphs-offset       bxs
			size:           glyphs-total-size   bxs
			min-size:		min-glyph-size		bxs
			max-size:		max-glyph-size		bxs
			min-distance:	min-glyph-distance	bxs
			max-distance:	max-glyph-distance	bxs
			equally-sized?:	all [found? glyphs-equally-sized? bxs]
		]
	]


	; ?????????????????? DIALECTIC STUFF ??????????????????


	to-screen: func [
		"Translate POINT from face or box into screen coordinates (in units)"
		point [pair!]
		from [object!]
	][
		either quacks-like-face? from [
			face-to-screen point from
		][
			point + from/offset + any [attempt [from/base] 0x0]
		]
	]

	~at~: make op!
	face-at: function [
		"Return a screen coordinate of a described POINT in a FACE"
		face	[object!] "Can be a box as well"
		point	[pair! block!] "Offset or [anchor +/- pair/integer ...]"
		/local v-anchor h-anchor v-oper h-oper v-offset h-offset
	][
		if pair? point [return to-screen point face]

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
		to-screen xy face
	]


	context [
		stack-friendly
		coerce: func ['word [word!] type [datatype!] /local r] [
			if any [word? get/any word path? get/any word] [set/any word get/any get word]
			;@@ TODO: log-trace coercions?
			r: type = type? get/any word
			; unless r [log-trace #composite "coerce: (word) -> (mold-part/flat get/any word 40) [expected: (type)]"]
			:r
		]

		u->p: :units-to-pixels
		p->u: :pixels-to-units


		;; uses `coerce`
		set 'amount-of function [
			"Count the amount (%) of COLOR on an IMAGE"
			spec	[block!] "E.g. [red on img], [almost blue on img]"
			/local clr cnt
		][
			unless parse/case spec [
				set verb opt ['somewhat | 'almost | 'all] (default verb: 'all)
				[	set color issue! (color: to tuple! color)
				|	set color [tuple! | word!] if (coerce color tuple!)
				]
				'on					;@@ TODO: any more verbs applicable?
				set image [image! | word!] if (coerce image image!)
			] [ERROR "amount-of: invalid color selection spec (mold spec)"]

			req-match: select [all 99% almost 90% somewhat 75%] verb	;-- required similarity of image colors to the one provided
			cs: get-colorset image
			total: image/size/x * image/size/y
			0% + sum map-each [clr cnt] cs [				;-- count coverage of matching colors; 0% so it always returns %
				match: 100% - contrast clr color
				either match < req-match [0%][100% * cnt / total]
			]
		]


		stack-friendly
		parse-box-spec: function [
			"Internal. Parse box dialect spec block into an object"
			spec [block!]
			/local
				color-op h-anchor v-anchor w
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
				(default where-op: 'around)			;-- default to 'around' mode
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
				set cover-op opt ['~= | '> | '< | '<= | '>=]
				set coverage percent!
				(default cover-op: '~=)
			]

			=coloration=: [
				opt quote color:
				set color-op ['all | 'almost | 'somewhat]
				set color [tuple! | word! | path!]
				if (coerce color tuple!)
			]

			=spec=: [
				[	=where=
					opt [if (find [at on] where-op) [=anchors= | =offset=]]		;-- only allow position for at/on
					opt [if (where-op <> 'around) =size=]						;-- disable size in 'around' mode (size equals area/size)
				|	=size= =where= if (where-op <> 'around)						;-- in `around` mode this is invalid as it has size
					opt [if (find [at on] where-op) [=anchors= | =offset=]]
				]
				opt [=coverage= =coloration= | =coloration= =coverage=]
			]

			unless parse/case spec =spec= [ERROR "Invalid box spec: (mold spec)"]	;@@ TODO: better error report (like area=none)

			image: where
			if quacks-like-face? area [
				;; face doesn't have a `base` offset, so should be translated properly
				area: object compose [
					offset: (face-to-window 0x0 area)
					size: (area/size)
				]
			]

			words: [where-op image area h-anchor v-anchor offset size cover-op coverage color-op color]
			object map-each/eval w words [[to set-word! w 'quote get w]]
		]

		stack-friendly
		test-coverage: function [
			"Internal. Test coverage and coloration of an IMAGE given SPEC"
			image	[image!]
			spec	[object!] "Only /coverage /cover-op /color /color-op are used"
			/part offset [pair!] size [pair!] "Specify a region only (in PIXELS!)"
			/artifact art [object!] "Save processing info into ARTIFACT"
			/local color count
		][
			unless spec/color [return yes]			;-- if no color info specified - it's an automatic match
			#assert [all [spec/coverage spec/cover-op spec/color-op]]
			cov: object [image: colorset: reduced: amount: result: none]
			if artifact [art/coverage: cov]

			if part [image: get-image-part image offset + 1x1 size - 3x3]
			cov/image: image
			;@@ TODO: maybe exclude borders? eat a pixel from all sides? to account for scaling inaccuracies

			cov/colorset: cs: get-colorset image
			;; tip: using 99% for `all` because of GDI+ bugs, which were fixed by making brush alpha = 254 (see #3165)
			req-match: select [all 99% almost 90% somewhat 75%] spec/color-op		;-- required similarity of image colors to the one provided
			total: image/size/x * image/size/y
			cov/amount: coverage: sum map-each [color count] cs [		;-- count coverage of matching colors
				match: 100% - contrast color spec/color
				either match < req-match [0%][100% * count / total]
			]
			;@@ TODO: reflect this in the artifact! 
			cov/result: do cov/reduced: reduce [coverage spec/cover-op spec/coverage]	;-- test the coverage requirement ;@@ TODO: log this if it fails?
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
			/image "Return an image snapshot of the box instead"
			/local art
		][
			return-image?: image
			log-artifact art: object compose/only [
				type: 'box
				spec: (copy spec)
				spec-obj: image: coverage: box: boxes: edges: result: none
				key: current-key
			]
			art/spec-obj: spec: parse-box-spec spec
			#assert [spec/image]
			#assert [spec/where-op]

			bestbox: function [image area] [
				#assert [object? area]
				art/edges: edges: find-edges image
				xy2: area/size + xy1: area/offset + any [attempt [area/base] 0x0]
				set [prob xy1 xy2]  fit-box  edges  u->p xy1  u->p xy2
				all [										;-- return none or [offset size]
					0 <> prob								;-- 0% = no match
					reduce [xy1  xy2 - xy1]					;-- return real pixels - for possible image cropping
				]
			]

			scan4box: function [image box-size /anchors h v] [
				art/boxes: boxes: find-boxes art/edges: find-edges image
				all [
					box: either anchors
						[find-box/anchors boxes u->p box-size h v image/size]
						[find-box         boxes u->p box-size]
					reduce [box/2 box/3 - box/2]		;-- return [offset size]
				]
			]

			art/image: image: spec/image
			base: any [attempt [spec/area/base] 0x0]

			either spec/where-op = 'around [
				area: spec/area			;-- `area` defines a box on an `image`
				#assert [none? spec/offset]
			][
				if spec/area [			;-- won't be needing the whole image; crop it
					art/image: image: get-image-part
						image
						-1x-1 + u->p base: spec/area/offset + base		;-- 1x1 margin to make box detection more reliable (it needs 1px edges)
						1x1   + u->p spec/area/size
				]
				area: spec				;-- else use offset & size from spec itself
			]
			art/box: box: either area/offset [		;-- no need to extract all boxes - have size and offset
				#assert [none? spec/h-anchor]		;-- anchors only make sense without offset
				#assert [none? spec/v-anchor]
				bestbox image area
			][										;-- without offset we look for a box of a specific size among all boxes
				switch spec/where-op [
					inside within [scan4box image spec/size]
					at on [scan4box/anchors image spec/size spec/h-anchor spec/v-anchor]
				]
			]
			art/result: all [
				set [offset size] box
				test-coverage/part/artifact image spec offset size art
				either return-image?
					[get-image-part image offset size]
					[object compose [offset: (p->u offset) size: (p->u size) base: (base)]]		;-- should be scaled, for compatibility with faces
			]
		]
		;@@ TODO: test set for `box` as it's too easy to break!
		;@@ TODO: assertions have to appear in the log too!


		;@@ TODO: so far there's only one instance of this; write more tests using `text`; how the dialect will look like?
		set 'parse-text-spec function [
			"Internal. Parse text dialect spec block into an object"
			spec [block!]
			/local
				color-op h-anchor v-anchor w
		][
			=v-anchor=: [set v-anchor ['top | 'middle | 'bottom]]
			=h-anchor=: [set h-anchor ['left | 'center | 'right]]
			=h+v-anchors=: [=h-anchor= opt =v-anchor= | =v-anchor= opt =h-anchor=]
			=anchors=: [
				opt [quote anchors: | quote anchor:]
				=h+v-anchors=
			]
			=align=: ['aligned =anchors=]

			=where=: [
				opt quote where:
				set where-op opt ['in | 'within | 'inside]		;-- all are the same
				[
					ahead path! into [set where word! set area word!]
					if (coerce area object!)
				|	set where word! (area: none)
				]
				if (coerce where image!)
				(default where-op: 'in)						;-- default to 'in' mode; allow op-less `where: image` expression
			]

			=size=: [
				opt quote size:
				set size pair! set fuzziness opt percent!
				(default fuzziness: 1%)
			]

			=spec=: [
				opt =size=  [opt =align= =where= | =where= opt =align=] end
			|	opt =align= [opt =size=  =where= | =where= opt =size=] end
			|	=where= [opt =align= opt =size= | opt =size= opt =align=] end
			]

			unless parse/case spec =spec= [ERROR "Invalid text spec: (mold spec)"]

			#assert [image? where]
			image: where

			words: [where-op image area h-anchor v-anchor size fuzziness]
			object map-each/eval w words [[to set-word! w 'quote get w]]
		]

		;@@ TODO: better name? this is too common
		;@@ TODO: describe it's spec; make manual tests
		;; example: text [100x100 left in image/area], text [in image] ...
		set 'text function [
			"Verify text alignment and size with the provided SPEC"
			spec [block!]
		][
			log-artifact art: object compose/only [
				type: 'text
				spec: (copy spec)
				spec-obj: image: box: expected-size: found-size: result: none
				key: current-key
			]
			art/spec-obj: spec: parse-text-spec spec
			art/image: image: either spec/area [	;-- won't be needing the whole image; crop it
				get-image-part
					spec/image
					u->p spec/area/offset + any [attempt [spec/area/base] 0x0]
					u->p spec/area/size
			] [spec/image]
			art/box: box: get-text-box image
			art/found-size: fsize: p->u box/2 - box/1
			if any [empty? box  fsize = 0x0] [return art/result: none]		;-- no text found!

			size-valid?: yes
			if art/expected-size: esize: spec/size [
				min-size: 1.0 - spec/fuzziness * esize
				max-size: 1.0 + spec/fuzziness * esize
				size-valid?: min-size .<=. fsize .<=. max-size
			]
			
			align-valid?: yes
			if any [spec/h-anchor spec/v-anchor] [
				align-valid?: check-alignment box/1 box/2 image/size spec/h-anchor spec/v-anchor
			]
			if art/result: all [align-valid? size-valid?] [art]		;-- return the artifact for inspection; or none
		]
	]

	import self
]


; s: screenshot
; box [30x20 within s]
; print mold/flat message-log
; map-each [x [string!]] message-log [? x]
; map-each [x [object!]] message-log [? x]
; log-review
; explore-artifact first find message-log object!

; i: to image! view/no-wait [area "abcd^/abcd^/abcd^/abcd^/abcd"]