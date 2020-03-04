Red [
	title:   "focus & unfocus events test"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %dope.red

eval-results-group [
	styles: exclude words-of system/view/VID/styles [window]
	unfocus-map: #()
	focus-map:   #()
	i: 0
	view collect [
		for-each [k: st] styles [
			keep compose/deep [
				(st) all-over (form st) 50x50
				on-created [
					put   focus-map face/type no
					put unfocus-map face/type no
				]
				on-focus   [put   focus-map face/type yes]
				on-unfocus [put unfocus-map face/type yes]
			]
			if k % 8 = 0 [keep [return]]
		]
		keep [
			rate 10 on-time [
				set-focus pick face/parent/pane i: i + 1
				if i = length? face/parent/pane [face/rate: none  unview]
			]
		]
	]

	n-focused:   count values-of focus-map yes
	n-unfocused: count values-of unfocus-map yes
	n-total:   length? values-of focus-map
	expect [n-focused = n-total]
	expect [n-unfocused = n-total]
	;;@@ TODO: count score +1 for each 'yes'
]

