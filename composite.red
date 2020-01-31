Red [
	title:   "#composite macro"
	author:  @hiiamboris
	license: 'BSD-3
]


;@@ TODO: make an escape mechanism? although, it's already there: ("(") (")") (")))((()()("), but can be shorter perhaps?
;@@ TODO: should composite support comments? e.g. `(;-- comments)`, if so - how should it count braces?
;@@ TODO: should composite expand "(#macros)" ?
;@@ TODO: function version for runtime composition; and upload somewhere
;; has to be both Red & R2-compatible
;; any-string! for composing files, urls, tags
;; load errors are reported at expand time by design
#macro [#composite set s any-string!] func [[manual] ss ee /local load-expr r e] [
	set/any 'error try [								;-- display errors rather than cryptic "error in macro!"
		r: copy []

		;; loads "(expression)..and leaves the rest untouched"
		load-expr: has [rest val] [						;-- s should be at "("
			rest: as string! s							;-- use "string": load %file/url:// does something else entirely
			either rebol
				[ set [val rest] load/next rest ]
				[ val: load/next rest 'rest ]
			e: as s rest								;-- update the end-position
			val
		]

		;; removes unnecesary parens in obvious cases
		;; 2 or more tokens should remain parenthesized, so that only the last value is rejoin-ed
		;; forbidden _loadable_ types should also remain parenthesized:
		;;   - word/path (can be a function)
		;;   - set-word/set-path (would eat strings otherwise)
		;@@ TODO: to be extended once we're able to load functions/natives/actions/ops/unsets
		wrap: func [blk] [					
			all [								
				1 = length? blk
				not find [word! path! set-word! set-path!] type?/word first blk
				return first blk
			]
			to paren! blk
		]

		;; filter out empty strings for less runtime load (except for the 1st string - it determines result type)
		keep: func [x][
			if any [
				empty? r
				not any-string? x
				not empty? x
			] [append/only r x]
		]

		do compose [
			(pick [parse/all parse] rebol) ss/2 [
				any [
					s: to #"(" e: (keep copy/part s e)
					s: (keep wrap load-expr) :e
				]
				s: to end (keep copy s)
			]
		]
		;; change/part is different between red & R2, so: remove+insert
		remove/part ss ee
		insert ss reduce ['rejoin r]
		return ee
	]
	print ["***** ERROR in #COMPOSITE *****^/" :error]
	ee
]

assert [
	[#composite %"()() - (1 + 2) - ({abc)))}) - (func)(1)()()"] == [
		rejoin [
			%""				;-- first string determines result type - should not be omitted
			() ()			;-- () makes an unset, no empty strings inbetween
			%" - "			;-- subsequent string fragments of the same type
			(1 + 2)			;-- 2+ tokens are parenthesized
			%" - "
			"abc)))"		;-- an explicit string! - not a file!; without parens around
			%" - "
			(func)			;-- words are parenthesized
			1				;-- single token without parens
			() ()			;-- no unnecessary empty strings
		]
	]
]

;; I'm intentionally not naming it `#error` or the macro may be silently ignored if it's not expanded (due to many issues with the preprocessor)
#macro ['ERROR any-string!] func [[manual] ss ee] [
	remove ss
	insert ss [do make error! #composite]
	ss		;-- reprocess it again so it expands #composite
]

