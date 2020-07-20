Red [
	title:   "include helper mezz"
	author:  @hiiamboris
	license: 'BSD-3
]


include: function [
	"Do FILE only if was not evaluated yet, saving load time"
	file [file!]
	/force "Force inclusion of an already evaluated file"
][
	unless block? :included [set 'included []]
	found: find included file
	either found [
		unless force [exit]
	][	append included file
	]
	print ["loading" file]
	do file
]
