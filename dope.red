Red [
	title:   "most of the doping in one place"
	author:  @hiiamboris
	license: 'BSD-3
]

random/seed now/precise

#include %debug.red
#include %assert.red
#include %clock.red
#include %composite.red
#include %loops.red
#include %relativity.red
#include %logger.red
#include %proc-win32.red

abs: :absolute

with: func [ctx [object! any-function!] code [block!]] [bind code :ctx]

;; declarative chainable pair comparison: 1x1 .<. 2x2 .<. 3x3 => 3x3 (truthy) - because `within?` messes my head up
.<.:  make op! func [a [pair!] b [pair!]] [all [a/1 <  b/1  a/2 <  b/2  b]]
.<=.: make op! func [a [pair!] b [pair!]] [all [a/1 <= b/1  a/2 <= b/2  b]]

once: func [
	"Set value of W to V only if it's unset"
	:w [set-word!]
	v [default!]
][
	unless value? to word! w [set w :v]
]

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

mold-part: function [
	"Visually better (esp. in sentences) mold/part with ellipsis and a closing bracket"
	value [any-type!]
	limit [integer! series!]
	/flat "Exclude all indentation"
	/only "Exclude outer brackets if value is a block"
][
	p: copy 'mold/part
	foreach w [flat only] [if get w [append p w]]
	r: do compose [(p) :value limit]
	all [
		not only
		any [any-object? :value block? :value]
		#"]" <> last r
		change skip tail r -4 "...]"
	]
	r
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


stack-friendly: func [:w [set-word!] v [default!]][set w :v]	;@@ TODO: remove it

; stack-friendly: func [
; 	"Prefix a function defined in a context to make it visible in stack trace"
; 	:w [set-word!]
; 	v [default!]
; ][
; 	set in system/words to word! w does [ERROR "DO NOT CALL (to word! w) DIRECTLY"]
; 	set w :v
; ]


;@@ BUG: this diverts return & exit (but bind-only is too slow to use here); also probably break/continue-sensitive
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
;; @@ TODO: it's simple now - no lit/get-args support; handle with care or extend
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
	]
	rewrite-single: func [code /local expr] [
		expr: copy/part code next code
		change/only code wrap inspect expr do expr
	]
	rewrite-next: func [code /no-op /local start end v1 v2 r arity expr rewrite? _] [
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
				any [
					word? :v1
					all [path? :v1  set [v1 _] preprocessor/value-path? v1]
				]
				find [native! action! function! routine!] type?/word get/any v1
			][
				arity: either path? v1: get v1 [
					preprocessor/func-arity?/with spec-of :v1 start/1
				][
					preprocessor/func-arity? spec-of :v1
				]
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
			expr: copy/deep/part code end			;-- have to make a copy or it may be modified by `do`
			set/any 'r inspect expr do/next code 'end
			change/part/only code wrap :r end
		]
		return next code
	]
	rewrite code
	do code
]

; inspect: func [e [block!] r [any-type!]] [print [pad mold :r 10 "<=" mold/flat/only e] :r]
; x: y: 2 f: func [x] [x * 5]
; probe trace-deep :inspect [x * x + f y]

; #assert [() = trace-deep :inspect []]
; #assert [() = trace-deep :inspect [()]]
; #assert [() = trace-deep :inspect [1 ()]]
; #assert [3  = trace-deep :inspect [1 + 2]]
; #assert [9  = trace-deep :inspect [1 + 2 * 3]]
; #assert [4  = trace-deep :inspect [x: y: 2 x + y]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] g: f 1 g * 2]]
; #assert [20 = trace-deep :inspect [f: func [x] [does [10]] (g: f (1)) ((g) * 2)]]

#assert [() = trace-deep func [x y [any-type!]][:y] []]
#assert [() = trace-deep func [x y [any-type!]][:y] [()]]
#assert [() = trace-deep func [x y [any-type!]][:y] [1 ()]]
#assert [3  = trace-deep func [x y [any-type!]][:y] [1 + 2]]
#assert [9  = trace-deep func [x y [any-type!]][:y] [1 + 2 * 3]]
#assert [4  = trace-deep func [x y [any-type!]][:y] [x: y: 2 x + y]]
#assert [20 = trace-deep func [x y [any-type!]][:y] [f: func [x] [does [10]] g: f 1 g * 2]]
#assert [20 = trace-deep func [x y [any-type!]][:y] [f: func [x] [does [10]] x: f: :f (g: f (1)) ((g) * 2)]]


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


timestamp: function [
	"Get date & time in a sort-friendly YYYYMMDD-hhmmss-mmm format"
][
	dt: now/precise
	r: copy ""
	foreach field [year month day hour minute second] [
		append r num-format dt/:field 2 3
	]
	stepwise [
		skip r 8  insert . "-"
		skip . 6  change . "-"
		skip . 3  clear .
	]
	r
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
		print [e "^/*** Stuck at:" mold-part pos 100]
		halt
	]
	:r
]

;; insert macro name somewhere and it will affect the rest of the code in a block/file
#macro [#where's-my-error? to end] func [[manual] ss ee] [
	clear change ss reduce ['where's-my-error? copy next ss]
	ss
]


;; experimental hybrid of `guard` and `where's-my-error?`
trace-using: function [
	"Execute CODE, exposing a set of DEFINITIONS (word: expression) to it and reporting where it stuck on error"
	code		[block!]
	definitions	[block!]
	/local res err
][
	unset 'res
	pos: code
	upd: func [_ [any-type!] p][pos: p]
	fun: function [] compose [			;@@ BUG: unfortunately, this binds 'local as well and traps return/exit
		(definitions)
		if error? set 'err try [set/any 'res trace :upd code  'ok] [
			clear find err: form err #"^/"		;-- extract only the 1st string
			panic #composite "(err)^/*** During execution of: (mold-part pos 100)"
		]
		:res
	]
	bind code :fun
	fun
]


clock-each: function [
	"Display execution time of each expression in CODE"
	code [block!]
	/times n [integer!] "Repeat the whole CODE N times (default: once)"
][
	times: make block! 32
	marks: make block! 32
	timer: func [x [any-type!] pos [block!]] [
		t2: now/precise
		dt: 1e3 * to float! difference t2 t1
		times: change times dt + any [times/1 0.0]
		marks: change/only marks pos
		t1: now/precise
	]
	loop n: any [n 1] [
		t1: now/precise
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


; find-parse: func [srs ptrn] [
; 	unless forparse [pos: ptrn] srs [break] [do make error! "not found"] :pos
; ]


;@@ BUG: unfortunately this traps return/exit
guard: func [
	"Evaluate CODE logging the error if it happens"
	code [block!]
	/blame code-2 [block! none!] "Blame this piece of code instead"
	/local e r
][
	if error? e: try [set/any 'r do code  'ok] [
		panic #composite "Internal error:^/(form e)^/during execution of (mold-part any [code-2 code] 100)"
	]
	:r
]


;@@ BUG: unfortunately this traps return/exit
scope: func [
	"Evaluate CODE, catch and log any error, but do a cleanup regardless"
	code [block!] "May contain LEAVING [cleanup code...] directives"
	/blame code-2 [block! none!]
	/local e cleaners leaving
][
	cleaners: copy []
	leaving: func [expr [block!]] [insert cleaners expr]	;-- `insert` to run them in the reverse the order
	bind-only code: copy/deep code 'leaving
	also guard/blame code code-2
		do cleaners
]


make-context-for: function [code [block!]] [
	; code: copy/deep code
	sw: collect-set-words code
	ctx: context compose [(sw) none]
	bind-only code bind sw ctx
	reduce [code ctx]
]

eval-part: function [
	"Evaluate CODE until it's tail or it throws a STOP signal; returns CODE at next non-evaluated position"
	code [block!] "CODE must be bound in a way that intermediate results survive between evaluations"
	/key id [string!] "Specify an identifier to mark produced artifacts with"
	/local r
][
	inspect: func [result [any-type!] next-code] [code: next-code]
	scope/blame [
		current-key/push id
		leaving [current-key/back]
		catch/name [trace :inspect code] 'stop
	] code
	code		;-- empty? can be used to check if it's done or not
]

stop-here: func ["Throw a STOP signal for eval-path"][throw/name none 'stop]

;@@ BUG: unfortunately this traps return/exit
eval-results-group: func [
	"Evaluate code using EXPECT, PARAM, PARAM-EXACT functions to test certain results"
	body	[block!]
	/key id	[string!] "Specify an identifier to mark produced artifacts with"
	/local results-wrapper
][
	scope [
		current-key/push id
		leaving [current-key/back]
		trace-using body [									;-- need a context for these words
		; results-wrapper: function [] compose [			;-- make all set-words there local
			group: either string? :body/1 [body/1]["GLOBAL"]
			group-key: does [id]

			stack-friendly
			expect: function [
				"EXPR should evaluate to anything but false, none or unset, else count it as error"
				expr [block!]
				/local r
			][
				red-log: copy "  Reduction log:"
				inspect: func [expr [block!] val [any-type!]] [
					repend red-log ["^/    " pad mold-part/flat/only expr 20 20 " => " mold-part/flat :val 40]
					:val
				]
				e: try/all [set/any 'r trace-deep :inspect expr 'ok]
				; set/any 'r do expr
				case [
					error? e
						[panic  #composite "(mold expr) errored out with^/(:e)"]
					any [unset? :r not :r]
						[panic  #composite "(mold expr) check failed with (:r)^/(red-log)"]
					'ok	[inform #composite "(mold expr) check succeeded"]
				]
				none
			]

			;@@ get rid of this? `expect` is better
			stack-friendly
			param-exact: function [expr [block!] expected [any-type!] /blame culprits [block!] /local val] [
				set/any 'val do expr
				either not equal? :val :expected
					[panic  #composite "(mold expr) yielded (:val), the only acceptable result is (:expected)"
if blame [foreach evil culprits [? (get evil)]]		;@@ TODO!!
					]
					[inform #composite "(mold expr) yielded an acceptable (:val)"]
			]

			stack-friendly
			param: function [expr [block!] expected [block!] /blame culprits [block!] /local val crit-lo crit-hi warn-lo warn-hi ideal] [
				set/any 'val do expr
				unless number? :val [
					panic #composite "(mold expr) should have returned a number, not (mold :val)"
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
				panic-if [not parsed?] #composite "invalid expectations block: (mold expected)"
				case [
					any [val < crit-lo  val > crit-hi] [
						panic #composite "(mold expr) yielded (val), outside critical range: (crit-lo) to (crit-hi). (msg)"
if blame [foreach evil culprits [? (get evil)]]
					]
					any [val < warn-lo  val > warn-hi] [
						warn #composite "(mold expr) yielded (val), expected to be in range: (warn-lo) to (warn-hi). (msg)"
					]
					'normally [
						inform #composite "(mold expr) yielded (val), ideally should be (ideal)"
					]
					;@@ TODO: use ideal value for rating computation
				]
			]

			; (body)
		]
		; results-wrapper
	]
]
