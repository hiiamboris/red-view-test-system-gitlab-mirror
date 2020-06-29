Red [
	title:   "face coordinate translations"
	author:  @hiiamboris
	license: 'BSD-3
]

context [

	set 'window-of func [
		"Get the window object of face FA"
		fa [object!]
	][
		while [all [fa  'window <> fa/type]] [fa: fa/parent]
		fa
	]

	set 'parent-of? make op! func [
		"Checks if PA is a (probably deep) parent of FA"
		pa [object!]
		fa [object!]
	][
		while [fa: select fa 'parent] [if pa =? fa [return yes]]
		no
	]

	set 'borders-of function [
		"Return window borders thickness: [left x top  right x bottom]"
		window [object!]
	][
		#assert [any [handle? window/state/1 integer? window/state/1]]
		#assert ['window = window/type]
		get-window-borders* window/state/1
	]

	set 'window-size-of func [
		"Get precise size (in pixels) of a window face"
		window [object!]
	][
		#assert [any [handle? window/state/1 integer? window/state/1]]
		#assert ['window = window/type]
		get-window-size* window/state/1
	]

	set 'client-offset-of func [
		"Get FACE's client area offset on a screen (in pixels)"
		face [object!]
	][
		#assert [any [handle? face/state/1 integer? face/state/1]]
		get-client-offset* face/state/1
	]

	translate: func [
		"Translate coordinate XY between face FA and screen, using OP"
		xy [pair!]
		fa [object!]
		op [op!] ":+ for face-to-screen; :- for screen-to-face"
		/limit lim [word!] "Stop at this face type (default: 'screen)"
	][
		default lim: ['screen]
		while [fa/type <> lim] [
			xy: xy op fa/offset
			fa: fa/parent
		]
		xy
	]

	set 'units-to-pixels function [xy [pair! integer!]] [
		ppd: system/view/metrics/dpi / 96.0 		;-- pixels per dot
		either pair? xy [
			as-pair
				round/to xy/x * ppd 1
				round/to xy/y * ppd 1
		][	round/to xy * ppd 1
		]
	]
	;; should be careful here not to turn 1 into 0
	set 'pixels-to-units function [xy [pair! integer!]] [
		ppd: system/view/metrics/dpi / 96.0 		;-- pixels per dot
		either pair? xy [
			as-pair
				round/to xy/x / ppd 1
				round/to xy/y / ppd 1
		][	round/to xy / ppd 1
		]
	]

	set 'face-to-window func [
		"Translate a point in face space into window space"
		xy [pair!] face [object!]
	][
		translate/limit xy face :+ 'window
	]

	set 'window-to-face func [
		"Translate a point in window space into face space"
		xy [pair!] face [object!]
	][
		translate/limit xy face :- 'window
	]

	set 'face-to-screen func [
		"Translate a point in face space into screen space"
		xy [pair!] face [object!]
		/real "Translate to real pixels (not scaled by DPI)"
	][
		; nonclient-size? + translate xy face :+
		either real
			[ (units-to-pixels xy) + client-offset-of face ]
			[ xy + pixels-to-units client-offset-of face ]
	]

	set 'screen-to-face func [
		"Translate a point in screen space into face space"
		xy [pair!] face [object!]
		/real "XY is in real pixels (not scaled by DPI)"
	][
		; (translate xy face :-) - nonclient-size?
		either real
			[ pixels-to-units xy - client-offset-of face ]
			[ xy - pixels-to-units client-offset-of face ]
	]

	set 'face-to-face func [
		"Translate a point from face1 space into face2 space"
		xy [pair!] face1 [object!] face2 [object!]
	][
		screen-to-face face-to-screen xy face1 face2
	]
]
