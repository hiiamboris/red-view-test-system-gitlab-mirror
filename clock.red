Red [
	title:   "simple clock mezz for benchmarking"
	author:  @hiiamboris
	license: 'BSD-3
]

clock: function [
	"Display execution time of CODE"
	code [block!]
	/times n [integer!] "Repeat N times (default: once)"
	/local r
][
	t1: now/precise/time
	set/any 'r loop any [n 1] code
	t2: now/precise/time
	parse form 1e3 * to float! (t2 - t1 + 24:00 % 24:00) [0 3 [opt #"." skip] opt [to #"."] a:]
	print [head clear a "ms^-" mold/flat code]
	:r
]

