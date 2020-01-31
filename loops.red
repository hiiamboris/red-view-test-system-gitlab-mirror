Red [
	title:   "loop constructs"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %bindings.red		;-- bind-only for for-each

xyloop: function [
	"Iterate over 2D series or pair"
	'word	[word!]
	srs		[pair! image!]
	code	[block!]
][
	any [pair? srs  srs: srs/size]
	repeat i srs/y * w: srs/x compose [
		set word as-pair  i - 1 % w + 1  i - 1 / w + 1
		(code)
	]
]

for: function [
	"FOR loop"
	'x		[word!]
	start	[integer!]
	end		[integer!]
	code	[block!]
][
	set x start
	loop end - start + 1 compose [
		(code)
		(to set-word! x) 1 + (x)
	]
]


;@@ BUG: this turns return/exit/break/continue into errors (when not caught) - they should be rethrown separately using their natives
selective-catch: func [
	"Evaluate CODE and return errors of given TYPE & ID only, while rethrowing all others"
	type	[word!]
	id		[word!]
	code	[block!]
	/local e r
][
	all [
		error? e: try/all [set/any 'r do code  'ok]		;-- r <- code result (maybe error or unset);  e <- error or ok
		any [e/type <> type  e/id <> id  return e]		;-- muffle & return the selected error only
		do e											;-- rethrow errors we don't care about
	]
	:r													;-- pass thru normal result
]

catch-a-break:  func [
	"Evaluate CODE catching BREAK (for use in loops)"
	code	[block!]
][
	selective-catch 'throw 'break code
]

catch-continue: func [
	"Evaluate CODE catching CONTINUE (for use in loops)"
	code	[block!]
][
	selective-catch 'throw 'continue code
]

;@@ BUG: this traps exit & return - can't use them inside forparse
forparse: func [
	"Evaluate BODY for every SPEC found in SRS"
	spec	[block!] "Parse expression to search for"
	srs		[any-block! any-string!] "Series to parse"
	body	[block!]
][
	catch-a-break [parse srs [any [spec (catch-continue body) | skip]]]
]


;@@ TODO: catch & propagate 'return'/'exit'
for-each: function [
	'spec [word! block!] series [series!] code [block!]
	/reverse "Traverse in the opposite direction"
][
	if empty? series [exit]				;-- optimization

	;@@ TODO: use `find` for better speed; unfortunately find is limited to types, not working with typesets
	;@@ no big loss? find with types is not gonna be fast anyway as it can't leverage hashmap
	; if any [
	; 	word? spec
	; 	not find spec block!
	; 	;-- should also check if advance isn't used
	; ] [return foreach (spec) series code]				;-- use default loop when possible
	spec: compose [(spec)]

	step: (count spec word!) + (count spec get-word!)
	if 0 = step [do make error! rejoin ["Spec must contain words or get-words!"]]
	set-index: either set-word? :spec/1 [to block! to set-word! take spec][[]]
	types:  make block! step
	values: make block! step
	_: none												;-- will be used for valus slots
	use-types?: use-values?: no
	parse spec [any [
		word! [
			remove set x block! (append types make typeset! x  use-types?: yes)
		|	(append types any-type!)
		] (append values none)
	|	change set x get-word! '_ (append values x append types any-type!  use-values?: yes)
	|	end
	|	spc: (do make error! rejoin ["Unexpected spec format: " mold spc])
	]]
	;@@ TODO: ideally, just make a function with spec from `types` and attempt-call it to check types; but need to prevent it from evaluating `series`
	if use-types? [
		types-match?: func [series types /local i] [
			repeat i length? types [
				unless find types/:i type? :series/:i [return no]
			]
			yes
		]
	]
	if use-values? [
		;trim/tail/with values 'none -- buggy, #4210
		while [all [not empty? values  none? last values]] [take/last values]

		values-match?: func [series values /local i] [
			repeat i length? values [
				all [
					:values/:i
					:series/:i <> get :values/:i
					return no
				]
			]
			yes
		]
	]

	r: none
	;@@ CRAP! so much fighting involved due to series offset being limited to 1..length ARGH!
	either reverse [
		index: (length? series) - 1 / step * step + 1		;-- align to current offset rather than the tail
		step: 0 - step
		stop: 0
	][
		index: 1
		stop: 1 + length? series		;@@ this fixes length; if it's building up - won't be accounted for
	]
	; advance: does compose [series: skip (to set-word! pos) series (step)]
	advance: does compose [
		also at series index			;-- return series for `set` usage ;@@ TODO: buggy(?) with /reverse - at head always succeeds
			index: (step) + index		;-- do not use `get` on user provided index word, for security; do not set it for predictability
	]
	bind-only code 'advance
	do compose/deep [
		while [index (pick [> <] reverse) stop] [
			;; this should go before the code - to advance on `continue`!
			where: at series index
			; set spec at series index
			index: (step) + (set-index) index		;-- inline it for more juice
			all [
				(either use-types?  [ compose [types-match?  where types ] ] [()])
				(either use-values? [ compose [values-match? where values] ] [()])
				set spec where
				set/any 'r do code
			]
		]
	]
	:r
]

; v: 2.0
; for-each [x: y [integer!] :v] [1 2.0 3] [probe x/2]


naive-map-each: func ['spec [word! block!] series [series!] code [block!] /only /eval /self /local tgt] [
	tgt: make block! length? series
	foreach (spec) series compose [
		(either only ['append/only]['append]) tgt (either eval ['reduce][()]) do code
	]
	either self [head change/part series tgt tail series][tgt]
]

;; leverages for-each power
;@@ TODO: /reverse? how will it work though?
map-each: func ['spec [word! block!] series [series!] code [block!] /only /eval /self /local tgt] [
	tgt: make block! length? series
	if any [word? spec not set-word? :spec/1] [
		spec: compose [pos: (spec)]
	]
	for-each (spec) old: series compose [
		append/part tgt old at series (to word! spec/1)
		(pick [append/only append] only) tgt (either eval ['reduce][()]) do code
		old: at series (to word! spec/1) + ((count spec word!) + (count spec get-word!))
	]
	append tgt old
	either self [head change/part series tgt tail series][tgt]
]

; probe map-each/eval [x [integer!] y [integer! float!]] [1 2.0 3.0 4 5] [ [form x form y]]

