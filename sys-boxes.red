Red [
	title:   "low-level box detection algorithms"
	author:  @hiiamboris
	license: 'BSD-3
]


#system [
	;-- minimum acceptable values for macos (due to rounding): 6px and 40% (to detect buttons/titlebar which are slim but very round)
	#define abs-ext  8			;-- maximum edge extension length (absolute)
	#define rel-ext  0.5		;-- maximum edge extension length (relative) - increase to detect smaller boxes, decrease to filter em out
	#define min-size 10			;-- do not make boxes smaller than 10x10
	#define edge-size 4			;-- [probability x y1 y2] - item count

	extend-edge: func [			;-- extends edge given by x1 & x2 by minimum of (x2 - x1 * rel-ext) and (abs-ext)
		x1	[int-ptr!]
		x2	[int-ptr!]
		lim	[integer!]			;-- do not exceed 1 (min) and lim (max)
		/local
			v1	[integer!]
			v2	[integer!]
			ext	[integer!]
			fl	[float!]
	][
		v1: x1/value  v2: x2/value
		fl: as-float v2 - v1 + 1
		ext: as-integer rel-ext * fl
		if ext > abs-ext [ext: abs-ext]
		v1: v1 - ext  if v1 < 1   [v1: 1]
		v2: v2 + ext  if v2 > lim [v2: lim]
		x1/value: v1  x2/value: v2
	]
]

;; TIP: avoid checkered/grid-like background like plague with this :D
find-boxes*: routine [
	h-edges		[block!]
	v-edges		[block!]
	return:		[block!]
	/local
		n-hedges	[integer!]
		n-vedges	[integer!]
		n-edges		[integer!]
		boxes		[red-block!]
		ip			[red-integer!]
		fp			[red-float!]
		v-head		[red-integer!]
		v-end		[red-integer!]
		h-end		[red-integer!]
		top-pos		[red-integer!]
		bot-pos		[red-integer!]
		lef-pos		[red-integer!]
		rig-pos		[red-integer!]
		top-x1		[integer!]
		top-x2		[integer!]
		top-x1'		[integer!]
		top-x2'		[integer!]
		top-y		[integer!]
		bot-x1'		[integer!]
		bot-x2'		[integer!]
		bot-y		[integer!]
		x1			[integer!]
		x2			[integer!]
		lef-y1'		[integer!]
		lef-y2'		[integer!]
		lef-x		[integer!]
		rig-y1'		[integer!]
		rig-y2'		[integer!]
		rig-x		[integer!]
		dx			[integer!]
		dy			[integer!]
		prob		[float!]
		fl			[float!]
][
	n-hedges: (block/rs-length? h-edges) / 4
	n-vedges: (block/rs-length? v-edges) / 4
	;; there's no min or max predictable number of boxes produced, so it's just a starting point
	boxes: block/push-only* n-hedges + n-vedges / 4

	v-head:  as red-integer! block/rs-head v-edges
	v-end:   as red-integer! block/rs-tail v-edges
	h-end:   as red-integer! block/rs-tail h-edges
	top-pos: as red-integer! block/rs-head h-edges
	while [top-pos < h-end] [
		ip: top-pos + 1  top-y:  ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
		ip: top-pos + 2  top-x1: ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
		ip: top-pos + 3  top-x2: ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
		top-x1': top-x1  top-x2': top-x2
		extend-edge :top-x1' :top-x2' gui/screen-size-x

		bot-pos: top-pos + edge-size		;-- start from the next edge (they are sorted in ascending order)
		while [bot-pos < h-end] [
			ip: bot-pos + 1  bot-y:   ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
			if bot-y - top-y < min-size [
				bot-pos: bot-pos + edge-size
				continue
			]
			ip: bot-pos + 2  bot-x1': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
			ip: bot-pos + 3  bot-x2': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER

			;; intersection (common part, not extended yet)
			x1: either top-x1 >= bot-x1' [top-x1][bot-x1']		;-- max
			x2: either top-x2 <= bot-x2' [top-x2][bot-x2']		;-- min
			unless x2 - x1 >= min-size [
				bot-pos: bot-pos + edge-size
				continue
			]

			;; extend edges corners for better intersection with verticals
			extend-edge :bot-x1' :bot-x2' gui/screen-size-x
			x1: either top-x1' >= bot-x1' [top-x1'][bot-x1']	;-- max
			x2: either top-x2' <= bot-x2' [top-x2'][bot-x2']	;-- min

			lef-pos: v-head
			while [lef-pos < v-end] [			;-- find an intersecting orthogonal edge
				ip: lef-pos + 1  lef-x:   ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
				unless all [x1 <= lef-x  lef-x <= x2] [		;-- edge should intersect with both hlines
					lef-pos: lef-pos + edge-size
					continue
				]
				ip: lef-pos + 2  lef-y1': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
				ip: lef-pos + 3  lef-y2': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
				extend-edge :lef-y1' :lef-y2' gui/screen-size-y
				unless all [top-y >= lef-y1'  bot-y <= lef-y2'] [	;-- left vline should touch both low and high hlines
					lef-pos: lef-pos + edge-size
					continue
				]

				rig-pos: lef-pos + edge-size		;-- start from the next edge (they are sorted in ascending order)
				while [rig-pos < v-end] [
					ip: rig-pos + 1  rig-x:   ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
					dx: rig-x - lef-x
					if any [
						dx < min-size				;-- inter-edge distance shouldn't be too short
						x1 > rig-x  x2 < rig-x		;-- edge should intersect with both hlines
					][
						rig-pos: rig-pos + edge-size
						continue
					]
					ip: rig-pos + 2  rig-y1': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
					ip: rig-pos + 3  rig-y2': ip/value  assert TYPE_OF(ip) = TYPE_INTEGER
					extend-edge :rig-y1' :rig-y2' gui/screen-size-y
					unless all [top-y >= rig-y1'  bot-y <= rig-y2'] [	;-- right vline should touch both low and high hlines
						rig-pos: rig-pos + edge-size
						continue
					]

					assert any [TYPE_OF(top-pos) = TYPE_FLOAT  TYPE_OF(top-pos) = TYPE_PERCENT]
					assert any [TYPE_OF(bot-pos) = TYPE_FLOAT  TYPE_OF(bot-pos) = TYPE_PERCENT]
					assert any [TYPE_OF(lef-pos) = TYPE_FLOAT  TYPE_OF(lef-pos) = TYPE_PERCENT]
					assert any [TYPE_OF(rig-pos) = TYPE_FLOAT  TYPE_OF(rig-pos) = TYPE_PERCENT]
					dy: bot-y - top-y
					fp: as red-float! top-pos                        prob: fp/value
					fp: as red-float! bot-pos  fl: as-float dx       prob: (prob + fp/value) * fl
					fp: as red-float! lef-pos  fl: as-float dy       prob: prob + (fp/value * fl)
					fp: as red-float! rig-pos                        prob: prob + (fp/value * fl)
					                           fl: as-float dx + dy  prob: prob / 2.0 / fl

					float/make-at ALLOC_TAIL(boxes) prob
					pair/make-in boxes lef-x top-y
					pair/make-in boxes rig-x bot-y

					rig-pos: rig-pos + edge-size
				]
				lef-pos: lef-pos + edge-size
			]
			bot-pos: bot-pos + edge-size
		]
		top-pos: top-pos + edge-size
	]

	as red-block! stack/set-last as cell! boxes
]

