Red [
	title:   "bind-related mezzanines"
	author:  @hiiamboris
	license: 'BSD-3
]

; unless value? 'rebind [
; 	rebind: function [	;@@ TODO: this could use optimization
; 		"selectively rebinds only `what` in `where` to `tgt`"
; 		where [block! function!] what [any-word! block!] tgt [any-word! any-object! function!]
; 		/deep "rebind also in subblocks/paths/functions (not in objects)" /local w f
; 	] [
; 		if function? :where [where: body-of :where]
; 		what-rule: either any-word? what [ [if (w == what)] ][ [if (find/same what w)] ]
; 		word-rule: [ change [set w any-word! what-rule] (bind w :tgt) ]
; 		deep-rule: [
; 			word-rule
; 		|	ahead [block! | any-path!] into rule
; 		|	set f function! (parse body-of :f rule)
; 		]
; 		shlw-rule: [ word-rule ]
; 		parse where rule: pick [
; 			[ any [ deep-rule | skip ] ]
; 			[ any [ shlw-rule | skip ] ]
; 		] deep
; 	]
; ]

;-- non-strict: rebinds any word type
bind-only: function [
	"Selective bind"
	where	[block!] "Block to bind"
	what	[any-word! block!] "Bound word or a block of, to replace to, in the where-block"
	/strict "Compare words strictly - not taking set-words for words, etc."
	/local w
][
	found?: does either block? what [
		finder: pick [find/same find] strict
		compose/deep [all [p: (finder) what w  ctx: p/1]]	;-- use found word's context
	][
		ctx: what										;-- use (static) context of 'what
		pick [ [w =? what] [w = what] ] strict
	]
	parse where rule: [any [
		ahead any-block! into rule						;-- into blocks, parens, paths, hash
	|	change [set w any-word! if (found?)] (bind w ctx)
	|	skip
	]]
]

; do-using: function [
; 	"Return CODE with WORD being locally bound to it"
; 	word [any-word!]
; 	code [block!]
; ][
; 	context compose/only [								;@@ BUG: also binds 'self and diverts return/exit
; 		(to set-word! word) get word
; 		return (code)
; 	]
; ]

do-using: function [
	"Evaluate CODE, exposing a set of DEFINITIONS (word: expression) to it"
	code		[block!]
	definitions	[block!]
][
	fun: function [] compose [(definitions) do bind code :fun]		;@@ BUG: unfortunately, this binds 'local as well and traps return/exit
	fun
]
