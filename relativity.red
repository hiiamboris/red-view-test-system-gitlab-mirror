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

	set 'borders-of function [
		"Return window borders thickness: [left x top  right x bottom]"
		window [object!]
	][
		#assert [any [handle? window/state/1 integer? window/state/1]]
		get-window-borders window/state/1
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

	set 'units-to-pixels func [xy [pair!]] [xy * system/view/metrics/dpi / 96]
	set 'pixels-to-units func [xy [pair!]] [xy * 96 / system/view/metrics/dpi]

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
			[ (units-to-pixels xy) + get-client-offset face/state/1 ]
			[ xy + pixels-to-units get-client-offset face/state/1 ]
	]

	set 'screen-to-face func [
		"Translate a point in screen space into face space"
		xy [pair!] face [object!]
		/real "XY is in real pixels (not scaled by DPI)"
	][
		; (translate xy face :-) - nonclient-size?
		either real
			[ pixels-to-units xy - get-client-offset face/state/1 ]
			[ xy - pixels-to-units get-client-offset face/state/1 ]
	]

	set 'face-to-face func [
		"Translate a point from face1 space into face2 space"
		xy [pair!] face1 [object!] face2 [object!]
	][
		screen-to-face face-to-screen xy face1 face2
	]
]
