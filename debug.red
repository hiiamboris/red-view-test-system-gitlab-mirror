Red [
	title:   "#debug macros"
	author:  @hiiamboris
	license: 'BSD-3
]

#macro [#debug 'on]  func [s e] [debug: on  []]
#macro [#debug 'off] func [s e] [debug: off []]
#macro [#debug block!] func [s e] [either debug [ s/2 ][ [] ]]
#debug on
