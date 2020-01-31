Red [
	title:   "simulator facilities manual test"
	author:  @hiiamboris
	license: 'BSD-3
]


test-simulator: function ["Ensures all input simulator facilites are working"] [
	log-trace "--- Started simulator facilities test ---"
	scope [
		evs: copy []
		wnd: view/no-wait [b: button 100x100]			;-- face should have no RMB-menu; `base` does not get focus on click
		leaving [unview/only wnd]
		do-queued-events

		insert-event-func evfu: func [fa ev] [
			try [ if same? fa b [
				repend evs [ev/type switch/default ev/type [
					wheel [ev/picked]
					key key-down key-up [ev/key]
				]	[ev/offset] ]
			]]
			none
		]
		leaving [remove-event-func :evfu]

		simulate-input-raw compose [
			(face-to-screen 50x50 b)
			+ lmb - lmb
			+ wheel
			+ rmb - rmb
			- wheel
			+ mmb - mmb
			+ wheel - wheel							;-- wheel events are grouped
			+ #"a" - #"a"
			+ VK_LCONTROL + VK_RETURN - VK_RETURN - VK_LCONTROL
		]
		do-queued-events

		expected: [
			over 50x50
			down 50x50 focus none up 50x50 click 50x50		;-- `focus` event is not working (#3728)
			wheel 1.0 
			alt-down 50x50 alt-up 50x50
			wheel -1.0 
			mid-down 50x50 mid-up 50x50
			wheel 0.0
			key-down #"A" key #"a" key-up #"A"
			key-down left-control key-down #"^M" key #"^/" key-up #"^M" key-up left-control
		]
		pairs: copy []
		for-each [ev arg [pair!]] evs [append pairs arg]
		midx: attempt [average map-each p pairs [p/x]]
		midy: attempt [average map-each p pairs [p/y]]

		nums: copy []
		for-each [ev arg [number!]] evs [append nums arg]

		keys:     map-each [ev arg] evs filtkeys: [either find [key key-down key-up] ev [arg][[]]]
		exp-keys: map-each [ev arg] expected filtkeys
		common-keys:  intersect exp-keys keys		;@@ TODO: ideally we need Levenshtein's here

		names:     map-each [ev arg] evs [ev]
		exp-names: map-each [ev arg] expected [ev]
		if empty? exp-names [do make error! #composite "Map-each is not working?!"]
		lacking-names: exclude exp-names names			;-- on lacking focus event - see #3728
		extra-names:   exclude names exp-names
		common-names:  intersect exp-names names
		warn-if [not empty? lacking-names] #composite "Expected (mold lacking-names) events to happen, but they didn't"
		warn-if [not empty? extra-names]   #composite "Unexpected (mold extra-names) were found in the event log"

		keys-size:  100% * (length? keys ) / length? exp-keys
		names-size: 100% * (length? names) / length? exp-names
		keys-coverage:  100% * (length? common-keys ) / length? unique exp-keys
		names-coverage: 100% * (length? common-names) / length? unique exp-names
		keys-order:  hamming intersect keys  exp-keys  intersect exp-keys  keys		;@@ TODO: ideally we need Levenshtein's here
		names-order: hamming intersect names exp-names intersect exp-names names	;@@ instead of coverage + Hamming

		eval-results-group [
			"Event simulator facilities"
			param [midx]          [47 < 49 < 50 > 51 > 53]	;-- mouse button event offsets
			param [midy]          [47 < 49 < 50 > 51 > 53]
			param [length? nums]  [ 3 <  3 <  3 >  3 >  3]	;-- wheel event offsets
			param [nums/1]        [ 1 <  1 <  1 >  1 >  1]
			param [nums/2]        [-1 < -1 < -1 > -1 > -1]
			param [nums/3]        [ 0 <  0 <  0 >  0 >  0]
			param [keys-size]     [ 100% < 100% < 100% > 100% > 100% ]	;-- keys
			param [keys-coverage] [ 100% < 100% < 100% > 100% > 100% ]
			param [keys-order]    [  0.0 <  0.0 <  0.0 > 0.1  > 0.2  ]
			param [names-size]    [  80% < 100% < 100% > 100% > 120% ]	;-- event names
			param [names-coverage][  80% < 100% < 100% > 100% > 120% ]
			param [names-order]   [  0.0 <  0.0 <  0.0 > 0.1  > 0.2  ]
		]
	]
	log-trace "--- Ended simulator facilities test ---"
]
test-simulator

