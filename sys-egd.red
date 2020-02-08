Red [
	title:   "low-level edge detection algorithms"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
	
	#include %/d/devel/red/red-view-test/sys-image-lock.reds

	edges: context [

		; image-pick: func [								;-- for 32 bit images only (assumes stride = width)
		; 	imdt	[image-data!]
		; 	x		[integer!]
		; 	y		[integer!]
		; 	return: [integer!]
		; 	/local
		; 		i	[integer!]
		; 		p	[int-ptr!]
		; ][
		; 	i: y * imdt/width + x * 4
		; 	p: as int-ptr! imdt/data + i
		; 	p/1 and FFFFFFh
		; ]

		contrast: func [
			a		[integer!]
			b		[integer!]
			return:	[float32!]
			/local
				a1 [integer!] a2 [integer!] a3 [integer!]
				b1 [integer!] b2 [integer!] b3 [integer!]
				c1 [integer!] c2 [integer!] c3 [integer!]
		][
			a1: a        and FFh
			a2: a >>> 8  and FFh
			a3: a >>> 16 and FFh
			b1: b        and FFh
			b2: b >>> 8  and FFh
			b3: b >>> 16 and FFh
			c1: either b1 >= a1 [b1 - a1][a1 - b1]
			c2: either b2 >= a2 [b2 - a2][a2 - b2]
			c3: either b3 >= a3 [b3 - a3][a3 - b3]
			if c2 > c1 [c1: c2]
			if c3 > c1 [c1: c3]
			(as float32! c1) / as float32! 255.0
		]


		fill-contrasts: func [
			imdt	[image-data!]
			/local
				size	[integer!]
				x		[integer!]
				w		[integer!]
				ph		[float32-ptr!]
				pv		[float32-ptr!]
				p1		[int-ptr!]
				p1+		[int-ptr!]
				p2		[int-ptr!]
		][
			w: imdt/width
			size: w * imdt/height * size? float32!
			ph: as float32-ptr! allocate size
			pv: as float32-ptr! allocate size
			imdt/h-contrasts: ph
			imdt/v-contrasts: pv
			p1: as int-ptr! imdt/data
			loop imdt/height - 1 [
				p1+: p1 + 1
				p2:  p1 + w
				x: 0
				loop w - 1 [
					x: x + 1
					ph/x: contrast p1/x p1+/x
					pv/x: contrast p1/x p2/x
				]
				ph/w: zero32
				pv/w: contrast p1/w p2/w
				p1: p1 + w  ph: ph + w  pv: pv + w
			]
			x: 1 loop w [ph/x: zero32  pv/x: zero32  x: x + 1]
		]

		free-contrasts: func [
			imdt	[image-data!]
		][
			free as byte-ptr! imdt/h-contrasts
			free as byte-ptr! imdt/v-contrasts
		]

		;; ===  edge extraction and unification parameters (constants)  ===
		;; allow 10% pixels to be non-contrast - this limits unification over subcontrast regions
		;; (this is loosely applied - is reset after every unification)
		#define min-density  0.9
		;; min average contrast of all edge pixels for it to be accepted - this lowers growth over non-contrast regions	
		#define min-contrast 0.1		;-- macos default skin requires this to be low
		;; consider only edges 10px long and longer (including outliers) - this selects edges of interest (otherwise all text glyphs will be included)
		#define min-length   10
		;; do not unify edges separated by more than 10px - this prevents very contrast regions from unifying from long distances
		#define max-tear     10	
		;@@ TODO: maybe allow setting some of these parameters as arguments?

		collect-edges: func [
			imdt		[image-data!]
			into		[red-block!]
			vertical?	[logic!]
			/local
				nlines	[integer!]			;-- count of scan-lines (vertical or horizontal)
				npoints	[integer!]			;-- count of points inside each scan-line, excluding marginal points where contrast can't be determined
				ln		[integer!]			;-- scan-line index (vertical or horizontal)
				pt		[integer!]			;-- point index inside the scan-line
				i		[integer!]			;-- index
				is		[integer!]			;-- index of segment
				w		[integer!]			;-- width
				h		[integer!]			;-- height
				size	[integer!]			;-- w * h
				c		[float32!]			;-- contrast
				csum	[float32!]			;-- sum of contrasts
				cs		[float32-ptr!]		;-- contrasts list
				cp		[float32-ptr!]		;-- pointer to contrasts list
				cp1		[float32-ptr!]		;--  LL MM RR    LL->MM contrast    it goes with this figure over the whole image
				cp2		[float32-ptr!]		;--     DD       MM->RR contrast    comparing MM->DD with maximum of LL->MM and MM->RR
				cp3		[float32-ptr!]		;--  (pixels)    MM->DD contrast    thus ensuring contrast gradient is pointed towards DD
				s		[integer!]			;-- start of the segment (0-based)
				s1		[integer!]			;-- ..of segment 1
				s2		[integer!]			;-- ..of segment 2
				e		[integer!]			;-- end of the segment (e = s + 1 for segments of 1 pixel)
				e1		[integer!]			;-- ..of segment 1
				e2		[integer!]			;-- ..of segment 2
				ns		[integer!]			;-- count of segments
				segs	[int-ptr!]			;-- segments list (start end ...)
				sp		[int-ptr!]			;-- pointer to segments list
				segcs	[float32-ptr!]		;-- segments mean contrast list (contrast ...)
				scsp	[float32-ptr!]		;-- pointer to mean contrast list
				tear	[integer!]			;-- gap between 2 adjacent segments
				lim		[integer!]			;-- max number of pixels 2 adjacent segments can grow according to min-density rule
		][
			w: imdt/width  h: imdt/height
			size: either vertical? [h][w]
			cs: as float32-ptr! allocate size * size? float32-ptr!				;-- contrast gradients list
			segs: as int-ptr! allocate size + 1 * size? integer!				;-- candidate segments list
			segcs: as float32-ptr! allocate size * (size? float32!) / 2 + 1		;-- segments mean contrast list
			cs/1: zero32  cs/w: zero32					;-- marginal contrasts are undefined
			
			;; init pointers to pixels of a T-shape
			either vertical? [
				cp1: imdt/v-contrasts
				cp2: cp1 + w
				cp3: imdt/h-contrasts + w
				nlines:  w - 1
				npoints: h - 2
			][
				cp1: imdt/h-contrasts
				cp2: cp1 + 1
				cp3: imdt/v-contrasts + 1
				nlines:  h - 1
				npoints: w - 2
			]

			;; loop over all scan-lines
			ln: 0 loop nlines [
				ln: ln + 1
				sp: segs
				s: -1	;-- <0 when out of segment
				e: -1
				scsp: segcs
				csum: zero32
				;; collect segments of subsequent edge points inside scan-line
				pt: 0 loop npoints [
					pt: pt + 1
					i: either vertical? [w][1]
					i: pt - 1 * i + 1
					c: either cp2/i >= cp1/i [cp2/i][cp1/i]
					c: cp3/i - c
					if c < zero32 [c: zero32]
					cs/pt: c

					either c >= as float32! min-contrast [		;-- mark the start of contiguous segment of acceptable contrast
						if s < 0 [s: pt  csum: zero32]
						e: pt + 1
						csum: csum + c
					][											;-- mark the end
						if s >= 0 [
							sp/1: s
							sp/2: e
							sp: sp + 2
							; scsp/1: csum / (as float32! e - s)	;@@ this doesn't work - #4224
							c: as float32! e - s				;@@ temporary workaround
							scsp/1: csum / c
							; if scsp/1 > as float32! 1.0 [probe ["added segment " s " " e " (" scsp/1 ")"]]
							; probe ["added segment " s " " e " (" scsp/1 ")"]
							scsp: scsp + 1
							s: -1
						]
					]
				]
				;-- finish the last open segment (if any)
				if s >= 0 [
					sp/1: s
					sp/2: e
					sp: sp + 2
					c: as float32! e - s
					scsp/1: csum / c
					scsp: scsp + 1
					s: -1
				]

				either vertical? [								;-- move the pointers to the next scan-line
					cp1: cp1 + 1
					cp2: cp2 + 1
					cp3: cp3 + 1
				][
					cp1: cp1 + w
					cp2: cp2 + w
					cp3: cp3 + w
				]
				
				;; ===  unite the segments now (should I also grow them? it'll be slower likely)  ===
				;; each segment has growth potential:
				;; - (it's length) / min-density  - no more than this count of pixels can be added to it
				;; - it's mean contrast must not go below min-contrast
				;; - segments separated by more than max-tear cannot be united
				ns: (as-integer sp - segs) / (size? integer!) / 2		;-- segments count
				sp: segs - 2
				is: 0 loop ns - 1 [
					is: is + 1
					sp: sp + 2
					s1: sp/1 e1: sp/2
					s2: sp/3 e2: sp/4

					tear: s2 - e1
					if tear > max-tear [continue]	;-- too distant to be unified

					lim: as-integer (as float32! e1 - s1 + e2 - s2) / as float32! min-density
					if lim < tear [continue]		;-- density will be too low after unification

					cp: cs + s2
					csum: cp/tear
					i: 1 loop tear - 1 [csum: csum + cp/i i: i + 1]		;-- mean contrast of the gap
					i: is + 1
					csum: csum + (segcs/is * (e1 - s1)) + (segcs/i * (e2 - s2))
					c: csum / (e2 - s1 + tear)
					if c < as float32! min-contrast [continue]			;-- unification would lower mean contrast too much

					sp/3: sp/1				;-- save unified segment
					sp/1: -1 sp/2: -1		;-- remove old segment
					segcs/i: c				;-- update it's mean contrast
					; if c > as float32! 1.0 [probe ["unified into " c]]
				]

				;; now add segments to resulting block, only those of min-length or longer
				sp: segs
				is: 1 loop ns [
					if all [sp/1 >= 0  sp/2 - sp/1 >= min-length] [
						; probe [segcs/is ": " ln + 1 " " sp/1 + 1 "-" sp/2]
						assert segcs/is <= as float32! 1.0
						percent/rs-make-at ALLOC_TAIL(into) as float! segcs/is
						integer/make-in into ln + 1
						integer/make-in into sp/1 + 1
						integer/make-in into sp/2
					]
					is: is + 1
					sp: sp + 2
				]
			]
			free as byte-ptr! segcs
			free as byte-ptr! segs
			free as byte-ptr! cs
		]

		collect-all-edges: func [
			im		[red-image!]
			horz	[red-block!]
			vert	[red-block!]
			/local
				imdt [image-data! value]
		][
			if any [
				im/size and FFFFh = 0
				im/size >>> 16 = 0
			] [exit]									;-- avoid crashes and failures with an empty image
			imdt/img: im
			image-lock imdt								;-- almost free
			fill-contrasts imdt							;-- fill takes ~50% time
			collect-edges imdt horz no					;-- collects take ~50% time
			collect-edges imdt vert yes
			free-contrasts imdt
			image-release imdt
		]
	]
]

find-edges*: routine [
	"Find horizontal and vertical edges in an image and append them to given blocks"
	im		[image!]
	horz	[block!]
	vert	[block!]
][
	edges/collect-all-edges im horz vert
]

contrast: routine [
	"Compare colors A and B for being visually distinctive"
	a		[tuple!]
	b		[tuple!]
	return: [float!] "0=same color, 1=max contrast"
][
	as float! edges/contrast a/array1 b/array1
]
