Red [
	title:   "pointing accuracy manual test"
	author:  @hiiamboris
	license: 'BSD-3
]

test-pointing-accuracy: function ["Ensures clicking coordinates are in order"] [
	log-trace "--- Started pointing accuracy test ---"
	scope [
		pts: copy []											;-- collect click positions on a `base`
		wnd: view/options/no-wait [
			at 100x100 b: base 100x100 on-down [append last pts event/offset]
		][size: 300x300]
		repeat i b/size/x * 2 [
			append/only pts to block! xy: i * 1x1 - (b/size / 2)
			simulate-input-raw compose [(face-to-screen xy b) + lmb - lmb]
			do-queued-events
		]
		leaving [unview/only wnd]
		log-trace rejoin ["Obtained points: " mold pts]

		remove-each pt sxms: copy pts [not pt/2]	 			;-- select successful measurements - those that produced an event
		panic-if [empty? sxms] "Click test broken?"
		
		set [min-hit max-hit] min+max map-each pt sxms [pt/2]	;-- collect statistics
		offs:  map-each pt sxms [set [aim hit] pt  hit - aim]
		dists: map-each of offs [vec-length? of]
		set [min-dist max-dist] min+max dists
		avg-dist: average dists

		eval-results-group [
			"Base click accuracy"
			param [length? sxms] [ 90 <  97 < 100 > 101 > 102 "Event processing behaves unexpectedly. Investigation needed!"]
			param [min-hit/x]    [  0 <   0 <  1  > 2   > 5  ]
			param [min-hit/y]    [  0 <   0 <  1  > 2   > 5  ]
			param [max-hit/x]    [ 96 <  98 < 100 > 100 > 101]
			param [max-hit/y]    [ 96 <  98 < 100 > 100 > 101]
			param [min-dist]     [0.0 < 0.0 < 0.0 > 1.0 > 1.4 "Click event generator needs recalibration?"]
			param [max-dist]     [0.0 < 0.0 < 0.0 > 1.5 > 1.9 "Click event generator needs recalibration?"]
			param [avg-dist]     [0.0 < 0.0 < 0.0 > 0.9 > 1.4 "Click event generator needs recalibration?"]
			;@@ TODO: recalibrate automatically (even if by a little) when it misses?
		]
	]
	log-trace "--- Ended pointing accuracy test ---"
]
test-pointing-accuracy

