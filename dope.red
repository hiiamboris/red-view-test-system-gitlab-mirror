Red [
	title:   "most of the doping in one place"
	author:  @hiiamboris
	license: 'BSD-3
]

random/seed now/precise

#include %debug.red
#include %assert.red
#include %clock.red
#include %loops.red
#include %relativity.red
#include %logger.red
#include %composite.red

abs: :absolute

with: func [ctx [object! any-function!] code [block!]] [bind code :ctx]

;; using set-word makes it collected by the `function` and visually distinguishable
default: func [
	"If W's value is none, set it to V"
	:w [set-word!]
	v  [block!] "Will only be executed if required"		;-- for cases where doing so otherwise may lead to slowdown/crashes
][
	unless get w [set/any w do v]
]

hamming: func [
	"Compute hamming distance between series S1 and S2"
	s1 [series!]
	s2 [series!]
	/local i n len
][
	n: 0
	repeat i len: max length? s1 length? s2 [if :s1/:i <> :s2/:i [n: n + 1]]
	1.0 * n / len
]

vec-length?: func [
	"Compute length of vector (X,Y)"
	xy [pair!]
][
	sqrt (xy/x * xy/x) + (xy/y * xy/y)
]

min+max: func [
	"Compute [min max] pair along XS"
	xs [block!]
	/local x- x+
][
	x-: x+: xs/1
	foreach x next xs [x-: min x- x x+: max x+ x]
	reduce [x- x+]
]


;@@ BUG: this diverts return & exit (but bind-only is too slow to use here)
trace: func [
	"Evaluate each expression in CODE and pass it's result to the INSPECT function"
	inspect	[function!] "func [result [any-type!] next-code [block!]]"
	code	[block!]	"If empty, still evaluated once"
	/local r
][
	#assert [2 = preprocessor/func-arity? spec-of :inspect]
	#assert [[any-type!] = first find spec-of :inspect block!]
	; #assert [[block!] = first find/reverse tail spec-of :inspect block!]
	until [
		set/any 'r do/next code 'code						;-- eval at least once - to pass unset from an empty block
		inspect :r code
		tail? code
	]
	:r
]


;; this is handy for producing a step-by-step expression reduction log
;; [100 / add 1 subtract 4 2] should produce:
;;  subtract 4 2
;;  add 1 :.
;;  100 / :.
;; then `trace` the result and log the outputs
trace-deep: function [
	"Deeply trace a set of expressions"			;@@ TODO: remove `quote` once apply is available
	inspect	[function!] "func [expr [block!] result [any-type!]]"
	code	[block!]	"If empty, still evaluated once"
][
	code: copy/deep code		;-- will be modified in place
	eval-types: reduce [		;-- value types that should be traced
		paren!		;-- recurse into it
		; block!	-- never known if it's data or code argument - can't recurse into it
		set-word!	;-- ignore it, as it's previous value is not used; also preprocessor returns it as a single expression
		set-path!	;-- ditto
		word!		;-- function call or value acquisition - we wanna know the value
		path!		;-- ditto
		get-word!	;-- value acquisition - wanna know it
		get-path!	;-- ditto
		native!		;-- literal functions should be evaluated but no need to display their source
		action!
		routine!
		op!
		function!
	]
	;@@ BUG: double evaluation can happen if something returns a function - TODO: use quote

	wrap: func [x [any-type!]] [
		either any [			;-- quote evaluatable types
			any-word? :x
			any-path? :x
			any-function? :x
			paren? :x
		][
			as paren! reduce ['quote :x]
		][
			:x
		]
	]
	rewrite: func [code] [
		while [not empty? code] [
			code: rewrite-next code
		]
		; inspect code tail code last code
	]
	rewrite-single: func [code] [
		expr: copy/part code next code
		set/any 'r do expr
		inspect expr :r
		change/only code wrap :r
	]
	rewrite-next: func [code /no-op /local start end v1 v2 r arity expr rewrite?] [
		assert [not empty? code]
		;; correct for the set-word / set-path bug - rewrite every set-expr with it's result
		start: code
		while [find [set-word! set-path!] type?/word :start/1] [start: next start]
		end: preprocessor/fetch-next start

		;; 2 or more values
		v1: :start/1
		v2: :start/2
		rewrite?: yes
		case [									;-- priority: op, any-func, everything else
			all [									;-- operator - recurse into it's right part
				word? :v2
				op! = type? get/any :v2
			][
				if no-op [rewrite?: no]
				if find eval-types type? :v1 [rewrite-single start]
				rewrite-next/no-op skip start 2
			]

			all [									;-- a function call - recurse into it
				any [word? :v1  path? :v1]
				find [native! action! function! routine!] type?/word get/any :v1
			][
				arity: preprocessor/func-arity? spec-of get :v1
				end: next start
				loop arity [end: rewrite-next end]
			]

			paren? :v1 [rewrite as block! v1]		;-- recurse into paren

			'else [									;-- other cases
				if find eval-types type? :v1 [rewrite-single start]
				rewrite?: any [
					not same? end next start		;-- 2 or more values
					not same? start code			;-- got set-words/set-paths
				]
			]
		]
		if rewrite? [
			expr: copy/deep/part code end		;-- have to make a copy or it may be modified by `do`
			set/any 'r do/next code 'end
			inspect expr :r
			change/part/only code wrap :r end
		]
		return next code
	]
	rewrite code
	do code
]

; inspect: func [e [block!] r [any-type!]] [print [pad mold/flat/only e 30 "=>" mold :r]]
; #assert [() = trace-deep :inspect []]
; #assert [() = trace-deep :inspect [()]]
; #assert [() = trace-deep :inspect [1 ()]]
; #assert [3  = trace-deep :inspect [1 + 2]]
; #assert [9  = trace-deep :inspect [1 + 2 * 3]]
; #assert [4  = trace-deep :inspect [x: y: 2 x + y]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] g: f 1 g * 2]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] (g: f (1)) ((g) * 2)]]

#assert [() = trace-deep func [x y [any-type!]][] []]
#assert [() = trace-deep func [x y [any-type!]][] [()]]
#assert [() = trace-deep func [x y [any-type!]][] [1 ()]]
#assert [3  = trace-deep func [x y [any-type!]][] [1 + 2]]
#assert [9  = trace-deep func [x y [any-type!]][] [1 + 2 * 3]]
#assert [4  = trace-deep func [x y [any-type!]][] [x: y: 2 x + y]]
#assert [20 = trace-deep func [x y [any-type!]][] [f: func [x] [does [10]] g: f 1 g * 2]]
#assert [20 = trace-deep func [x y [any-type!]][] [f: func [x] [does [10]] x: f: :f (g: f (1)) ((g) * 2)]]


;@@ BUG: this diverts return & exit (but bind-only is too slow to use here)
stepwise: function [
	"Evaluate CODE by setting `.` word to the result of each expression"
	code [block!]
][
	;; `code` can't be bound to `stepwise` context, or we expose it's locals
	;;@@ TODO: revise this once bind/only is available (bind-only mezz is an overkill)
	bind code f: has [.] [								;-- localize `.` to allow recursion
		unset '.										;-- for `stepwise []` to equal `stepwise [.]`
		trace :setter code
	]
	setter: func [x [any-type!] _] bind [set/any '. :x] :f
	f
]


;@@ TODO: better name
where's-my-error?: func [
	"Execute an erroneous CODE and tell where it stuck exactly"
	code [block!]
	/local pos f e r
][
	pos: code
	f: func [_ [any-type!] p][pos: p]
	if error? e: try [set/any 'r trace :f code  'ok] [
		print [e "^/*** Stuck at:" mold/part pos 100]
		halt
	]
	:r
]

;; insert macro name somewhere and it will affect the rest of the code in a block/file
#macro [#where's-my-error? to end] func [[manual] ss ee] [
	clear change ss reduce ['where's-my-error? copy next ss]
	ss
]

clock-each: function [
	"Display execution time of each expression in CODE"
	code [block!]
	/times n [integer!] "Repeat the whole CODE N times (default: once)"
][
	times: make block! 32
	marks: make block! 32
	timer: func [x [any-type!] pos [block!]] [
		t2: now/precise/time
		dt: 1e3 * to float! t2 - t1 + 24:00 % 24:00			;-- be prepared for day change
		times: change times dt + any [times/1 0.0]
		marks: change/only marks pos
		t1: now/precise/time
	]
	loop n: any [n 1] [
		t1: now/precise/time
		trace :timer code
		times: head times
		marks: head marks
	]
	marks: insert/only marks code
	foreach dt times [							;-- display the results
		parse form dt / n [0 3 [opt #"." skip] opt [to #"."] dt: (dt: head clear dt)]
		print [ dt "ms^-" mold/flat copy/part marks/-1 marks/1 ]
		marks: next marks
	]
	clear times  clear marks							;-- to help the poor GC
]



num-format: function [num [float! integer!] integral [integer!] frac [integer!] /no-zero-frac] [
	either dot: find x: form num #"." [
		more: frac + 1 - length? dot
		either more > 0
			[append/dup x #"0" more]
			[clear skip tail x more]
	][dot: tail x]
	insert/dup x #"0" max 0 integral - offset? x dot
	while [all [no-zero-frac  #"0" = last x]] [take/last x]
	all [#"." = last x  take/last x]
	x
]


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


; find-parse: func [srs ptrn] [
; 	unless forparse [pos: ptrn] srs [break] [do make error! "not found"] :pos
; ]


;@@ BUG: unfortunately this traps return/exit
guard: func [
	"Evaluate CODE logging the error if it happens"
	code [block!]
	/local e r
][
	if error? e: try [set/any 'r do code  'ok] [
		panic #composite "Internal error:^/(form e)^/during execution of (mold/part code 100)"
	]
	:r
]


;@@ BUG: unfortunately this traps return/exit
scope: func [
	"Evaluate CODE, catch and log any error, but do a cleanup regardless"
	code [block!] "May contain LEAVING [cleanup code...] directives"
	/local e cleaners leaving
][
	cleaners: copy []
	leaving: func [expr [block!]] [insert cleaners expr]	;-- `insert` to run them in the reverse the order
	bind-only code: copy/deep code 'leaving
	also guard code
		do cleaners
]


;@@ BUG: unfortunately this traps return/exit
eval-results-group: func [body [block!]] [
	guard [
		do-using body [									;-- need a context for these words
			group: either string? :body/1 [body/1]["GLOBAL"]

			expect: function [
				"EXPR should evaluate to anything but false, none or unset, else count it as error"
				expr [block!]
				/local r
			][
				red-log: copy "  Reduction log:"
				inspect: func [exp [block!] val [any-type!]] [
					repend red-log ["^/    " pad mold/flat/only exp 30 " => " mold :val]
				]
				set/any 'r trace-deep :inspect expr
				; set/any 'r do expr
				either any [unset? :r not :r]
					[panic  #composite "(group): (mold expr) check failed with (:r)^/(red-log)"]
					[inform #composite "(group): (mold expr) check succeeded"]
				none
			]

			;@@ get rid of this? `expect` is better
			param-exact: function [expr [block!] expected [any-type!] /blame culprits [block!] /local val] [
				set/any 'val do expr
				either not equal? :val :expected
					[panic  #composite "(group): (mold expr) yielded (:val), the only acceptable result is (:expected)"
if blame [foreach evil culprits [? (get evil)]]		;@@ TODO!!
					]
					[inform #composite "(group): (mold expr) yielded an acceptable (:val)"]
			]
			param: function [expr [block!] expected [block!] /blame culprits [block!] /local val crit-lo crit-hi warn-lo warn-hi ideal] [
				set/any 'val do expr
				unless number? :val [
					panic #composite "(group): (mold expr) should have returned a number, not (mold :val)"
					exit
				]
				if float? val   [val: round/to val 0.0001]
				if percent? val [val: 100% * round/to to float! val 0.0001]		;@@ round/to percent float is bugged REP #42
				parsed?: parse expected [
					   set crit-lo number!
					'< set warn-lo number!
					'< set ideal number!
					'> set warn-hi number!
					'> set crit-hi number!
					set msg opt string!
				]
				default msg: [""]
				panic-if [not parsed?] #composite "(group): invalid expectations block: (mold expected)"
				case [
					any [val < crit-lo  val > crit-hi] [
						panic #composite "(group): (mold expr) yielded (val), outside critical range: (crit-lo) to (crit-hi). (msg)"
if blame [foreach evil culprits [? (get evil)]]
					]
					any [val < warn-lo  val > warn-hi] [
						warn #composite "(group): (mold expr) yielded (val), expected to be in range: (warn-lo) to (warn-hi). (msg)"
					]
					'normally [
						inform #composite "(group): (mold expr) yielded (val), ideally should be (ideal)"
					]
					;@@ TODO: use ideal value for rating computation
				]
			]
		]
	]
]
