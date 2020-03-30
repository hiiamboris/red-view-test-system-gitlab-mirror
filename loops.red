Red [
	title:   "loop constructs"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %assert.red
#include %bindings.red		;-- bind-only for for-each
#include %composite.red


count: function [
	"Count occurrences of X in S (using `=`)"
	s [series!]
	x [any-type!]
	;@@ TODO /case /same
][
	r: 0
	while [s: find/tail s :x] [r: r + 1]
	r
]

gen-range: function [max [integer!]] [
	collect [repeat i max [keep i]]
]


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
	incr: pick [1 -1] start <= end
	set x start
	loop 1 + abs end - start compose [
		(code)
		(to set-word! x) incr + (x)
	]
]


while-waiting: function [
	"Do BODY periodically until TIME runs out or COND evaluates to false"
	time [time! integer! float! none!] "Returns NONE when TIME hits"
	cond [block!] "Returns TRUE when COND is false"
	body [block!]
][
	if number? time [time: to time! time]
	t1: now/precise
	while cond [
		if time [
			t2: now/precise
			dt: difference t2 t1
			if dt >= time [return none]
		]
		do body
		wait 0.01
	]
	yes
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
	/stride "Lock step at 1 (or -1 for reverse) and always include all SPEC words"
][
	if empty? series [exit]				;-- optimization

	;@@ TODO: use `find` for better speed; unfortunately find is limited to types, not working with typesets
	;@@ no big loss? find with types is not gonna be fast anyway as it can't leverage hashmap
	; if any [
	; 	word? spec
	; 	not find spec block!
	; 	;-- should also check if advance isn't used
	; ] [return foreach (spec) series code]				;-- use default loop when possible
	spec: to block! spec
	set-index: either set-word? :spec/1 [to block! to set-word! take spec][[]]
	
	step: (count spec word!) + (count spec get-word!)
	if 0 = step [ERROR "Spec must contain words or get-words!"]
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
	|	spc: (ERROR "Unexpected spec format (mold spc)")
	]]

	;;@@ TODO: fastest(?) way to check values' types - call a function - do that once `apply` is a native - otherwise will have to compose the call each time
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
		either stride [
			index: (length? series) - step + 1
			step: -1
		][
			index: (length? series) - 1 / step * step + 1		;-- align to current offset rather than the tail
			step: 0 - step
		]
		stop: 0
	][
		index: 1
		either stride [
			stop: (length? series) - step + 2
			step: 1
		][
			stop: 1 + length? series		;@@ this fixes length; if it's building up - won't be accounted for ;@@ TODO: allow growing up
		]
	]

	; advance: does compose [series: skip (to set-word! pos) series (step)]
	advance: does compose [
		also at series index			;-- return series for `set` usage ;@@ TODO: buggy(?) with /reverse - at head always succeeds
			index: (step) + index		;-- do not use `get` on user provided index word, for security; do not set it for predictability
	]
	bind-only code 'advance

	cmp:          pick [> <] reverse
	type-check:   pick [ [types-match?  where types ] [] ] use-types?
	values-check: pick [ [values-match? where values] [] ] use-values?
	spec-fill:    compose/only pick [ [set (spec) where] [foreach (spec) where [break]] ] any-block? series
	filtered?:    use-types? or use-values?
	eval:         [set/any 'r do code]
	do compose/deep [
		while [index (cmp) stop] [
			;; this should go before the code - to advance on `continue`!
			where: at series index
			index: (step) + (set-index) index		;-- inlines `advance` for more juice

			(compose/deep pick [
				[ if all [(type-check) (values-check)] [(spec-fill) (eval)] ]
				[ (spec-fill) (eval) ]
			] filtered?)
		]
	]
	:r
]

; v: 2.0
; for-each [x: y [integer!] :v] [1 2.0 3] [probe x/2]

#assert [[#"a" #"b" #"c"] = collect [for-each c "abc" [keep c]]]


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
	#assert [function? :count]							;-- leaked words may override it :(
	for-each (spec) old: series compose [
		new: at series (to word! spec/1)
		; unless old =? new [append/part tgt old new]		doesn't work because of #4336
		unless old =? new [append tgt copy/part old new]	;-- workaround
		(pick [append/only append] only) tgt (either eval ['reduce][()]) do code
		old: skip new ((count spec word!) + (count spec get-word!))
	]
	unless empty? old [append tgt old]
	either self [head change/part series tgt tail series][tgt]
]

#assert [[#"a" #"b" #"c"]    = map-each c "abc" [c]]
#assert [[#"a" #"c" #"e"]    = map-each [a b] "abcde" [a]]
#assert [[#"b" #"d" #[none]] = map-each [a b] "abcde" [b]]
#assert [[#"b" #"d"]         = map-each [a b] "abcd" [b]]

; probe map-each/eval [x [integer!] y [integer! float!]] [1 2.0 3.0 4 5] [ [form x form y]]


keep-type: function [list [series!] type [datatype! typeset!]] [
	remove-each x list: copy list
		either datatype? type
			[[ type <> type? :x ]]
			[[ not find type type? :x ]]
	list
]

