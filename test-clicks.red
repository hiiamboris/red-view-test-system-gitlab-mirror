Red [
	title:   "clickability manual test"
	author:  @hiiamboris
	license: 'BSD-3
]

;@@ TODO: rewrite this using the system

;; see #4252
;@@ TODO: turn this into a full featured standalone click test
;@@ TODO: also a cross-face test - compare differences
;@@ TODO: this has too much checks if we count each one for 1, maybe need a score multiplier: all tests = 100, no tests = 0...


;@@ is it OK that `click` follows `up`, but `dbl-click` precedes it?
;; click is ok, since it won't be a click if it's down+over or down+alt-down...
;; but should dbl-click not wait for up? it's probably teh OS thing anyway

#include %input.red
#include %dope.red

dump-all?: no			;-- brief (no) or verbose (yes) event info to print on each event
simulate?: yes			;-- no to skip simulation phase and get to the manual playground
delay: none

event2object: function [e][
						;-- copy/deep else `flags` block may be shared with other events - bad
	construct copy/deep map-each/eval x system/catalog/accessors/event! [[
		to set-word! x
		either object? e/:x [e/:x/type][e/:x]		;-- do not include faces content, for brevity
	]]
]

subsets: function [
	"Return all unique subsets of S (preserves the order)"
	s
	/all "Include also S itself (copy of) and an empty set"
][
    collect [
    	if all [keep/only copy []]
    	n: length? s
    	repeat i 1 << (n - 1) - 1 [
    		keep/only collect [
	    		repeat j n [
	    			if 1 << (j - 1) and i <> 0 [keep s/:j]
	    		]
    		]
    	]
    	if all [keep/only copy s]
    ]
]

;; rearranging version, slow...
; combos: function [block][
; 	res: copy []
; 	more: function [acc blk] [
; 		if empty? blk [
; 			unless any [empty? acc find/only res acc] [append/only res copy acc]
; 			exit
; 		]
; 		repeat i length? blk [
; 			blk1: head remove at copy blk i
; 			more compose [(acc) (blk/:i)] blk1
; 			more acc blk1
; 		]
; 	]
; 	more [] block
; 	res
; ]

modifiers: [
;; title  opening         closing         flags     down-events  up-events
	ctrl  [+ VK_LCONTROL] [- VK_LCONTROL] [control] [key-down] [key-up]
	shift [+ VK_LSHIFT]   [- VK_LSHIFT]   [shift]   [key-down] [key-up]
	alt   [+ VK_LMENU]    [- VK_LMENU]    [alt]     [key-down] [key-up]
]
actions: [
;; title       opening             closing  flags      down-events                up-events
	down       [+ lmb]             [- lmb]  [down]     [down]                     [up click]
	down2      [+ lmb - lmb + lmb] [- lmb]  [down]     [down up click down dbl-click] [up]
	alt-down   [+ rmb]             [- rmb]  [alt-down] [alt-down]                 [alt-up]
	alt-down2  [+ rmb - rmb + rmb] [- rmb]  [alt-down] [alt-down alt-up alt-down] [alt-up]	;@@ is it normal not to have on-click?
	mid-down   [+ mmb]             [- mmb]  [mid-down] [mid-down]                 [mid-up]
	mod-down2  [+ mmb - mmb + mmb] [- mmb]  [mid-down] [mid-down mid-up mid-down] [mid-up]	;@@ is it normal not to have on-click?
	aux1-down  [+ xmb1]            [- xmb1] [aux-down] [aux-down]                 [aux-up]	;@@ TODO: report also that 5th button is treated in flags as 4th and cannot be detected
	aux2-down  [+ xmb2]            [- xmb2] [aux-down] [aux-down]                 [aux-up]	;@@ TODO: report also that 5th button is treated in flags as 4th and cannot be detected
	wheel      [+ wheel]           [- wheel] []        [wheel]                    [wheel]		;@@ TODO: handle wheels
]
mod-names: extract modifiers 6
act-names: extract actions 6
; act-names: [down down2 alt-down]; mid-down aux1-down aux2-down]
; act-names: [down mid-down wheel]

state: object [
	input: []
	exp-flags: []
	flags-stack: []
	events: []
]

expected: function [
	"Test if logged events are the ones expected"
	exp-evts
][
	check: function [test expectation /range] [
		x: do test
		y: either range [reduce expectation][do expectation]
		if either range [not all [y/1 <= x x <= y/2]] [x <> y] [
			event: either o [rejoin [" for event=" o/type]] [""]
			prin #composite "^/ * (form test) = (mold x);^-expected = (mold y)(event);^-input = (mold/flat state/input)"
		]
	]

	do-queued-events							;-- flush event queue; fill `state`
	got-evts: map-each o state/events [o/type]	;-- get happened events types
	check [got-evts] [exp-evts]
	foreach o state/events [
		check [o/face]   [receiver/type]
		check [o/window] ['window]
		check/range [o/offset/x] [18 22]		;-- aiming at 20x50
		check/range [o/offset/y] [48 52]
		unless empty? difference o/flags state/exp-flags [	;-- unordered comparison
			check [o/flags] [state/exp-flags]
		]
		foreach field [down? mid-down? alt-down? aux-down? ctrl? shift?] [	;-- check event/flags and event/down? & co flags correspondence
			flag: to word! trim/with form field "?"
			if flag = 'ctrl [flag: 'control]
			flag-value: not none? find o/flags flag
			if flag-value <> o/:field [
				prin #composite "^/ * (field) = (o/:field) whereas (flag) = (flag-value) for event=(o/type);^-input = (mold/flat state/input)"
			]
		]
	]
	clear state/events							;-- prepare state for more events
]


log-evt: func [o] [
	prin either dump-all?
		[[lf o/type mold o/flags "down?:" o/down?]]
		[[o/type sp]]
	append state/events o
]

sim: func [inp] [
	append/only state/input inp
	simulate-input-raw inp
	prin [lf 'sent mold inp tab]
	if delay [wait delay * 1e-3]
]

push: function [what] [
	if none? what [exit]		;-- case where we skip a key
	what: any [find actions what  find modifiers what]
	append/only state/flags-stack copy state/exp-flags
	append state/exp-flags what/4
	sim what/2
	expected what/5
]

pull: function [what] [
	if none? what [exit]		;-- case where we skip a key
	what: any [find actions what  find modifiers what]
	state/exp-flags: take/last state/flags-stack
	sim what/3
	expected what/6
]


logged-actors: [
	on-key-down on-key on-key-up   		;-- on-key shouldn't fire for modifier keys
	on-down on-click on-up on-dbl-click
	on-alt-down on-alt-up   
	on-mid-down on-mid-up   
	on-aux-down on-aux-up   
	on-over     
	on-wheel    
]


;-- could use `capturing?: yes` here, but it will be dangerous to embed
window: view/no-wait collect [
	keep [receiver: radio all-over focus 100x100]
	keep map-each/eval actor logged-actors [[
		actor [log-evt event2object event]
	]]
]

if simulate? [
	simulate-input-raw reduce [face-to-screen 20x50 receiver]
	do-queued-events		;-- start clean - flush & forget events before the clicks
	clear state/events

	foreach modset subsets/all mod-names [
		foreach act1 act-names [
			forbid: reduce [act1]
			if find [down down2] act1 [forbid: [down down2]]	;-- click and double click cannot follow each other
			foreach mod modset [push mod]
			foreach act2 exclude act-names forbid [			;@@ two events depth should be enough? TODO: full depth?
				push act1
				push act2
				pull act2
				pull act1
			]
			for-each/reverse mod modset [pull mod]
			clear state/input
			prin "^/------------------------"
		]
	]
]

dump-all?: yes
do-events

halt
