Red [
	title:   "include helper mezz"
	author:  @hiiamboris
	license: 'BSD-3
]


include: func [
	"Do FILE only if was not evaluated yet, saving load time"
	file [file!]
	/force "Force inclusion of an already evaluated file"
][
	unless block? :included [included: []]
	if all [not force  find included file] [exit]
	append included file
	print ["loading" file]
	do file
]
