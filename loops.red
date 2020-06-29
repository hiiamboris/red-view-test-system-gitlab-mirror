Red [
	title:   "loop constructs"
	author:  @hiiamboris
	license: 'BSD-3
]

do %include.red

include %common/setters.red
include %common/count.red
include %common/keep-type.red
include %common/extremi.red
include %common/xyloop.red
include %common/forparse.red
include %common/for-each.red
include %common/map-each.red
#include %common/composite.red
#include %common/assert.red

once loops-ctx: context [

	gen-range: function [max [integer!]] [
		collect [repeat i max [keep i]]
	]

	for: function [
		"FOR loop"
		'x		[word!]
		start	[integer!]
		end		[integer!]
		code	[block!]
	][
		incr: pick [1 -1] start <= end
		set x start
		loop 1 + abs end - start compose [
			(code)
			(to set-word! x) incr + (x)
		]
	]


	while-waiting: function [
		"Do BODY periodically until TIME runs out or COND evaluates to false"
		time [time! integer! float! none!] "Returns NONE when TIME hits; Pass NONE to disable timer completely"
		cond [block!] "Returns TRUE when COND is false"
		body [block!]
	][
		if number? time [time: to time! time]
		t1: now/precise
		while cond [
			all [time  time <= difference now/precise t1  return none]
			do body
			wait 0.01
		]
		yes
	]

	import self
]

