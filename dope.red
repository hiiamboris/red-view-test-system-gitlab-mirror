Red [
	title:   "most of the doping in one place"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %include.red			;-- without this, load time becomes ~20 seconds

random/seed now/precise

; #do [print "PREPROCESSING DOPE"]
; print "EVALUATING DOPE"

include %common/clock-each.red
; clock-each [
	#include %common/debug.red
	include %common/clock.red
	include %common/with.red
	include %common/setters.red
	include %common/do-atomic.red
	include %common/apply.red
	include %common/collect-set-words.red
	; #include %common/format-number.red
	include %common/stepwise-func.red
	include %common/timestamp.red
	#include %common/assert.red
	; #include %common/trace.red
	include %common/trace-deep.red
	#include %common/composite.red
	#include %common/error-macro.red
	#include %common/stepwise-macro.red
	#include %common/show-trace.red

	include %loops.red
	include %relativity.red		;@@ this is more advanced than in %common/ due to R/S base
	include %logger.red
	include %proc-win32.red			;@@ TODO: leave only portable imports here
; ]

;@@ TODO: move `trace` out

once dope-ctx: context [

	abs: :absolute

	;; declarative chainable pair comparison: 1x1 .<. 2x2 .<. 3x3 => 3x3 (truthy) - because `within?` messes my head up
	.<.:  make op! func [a [pair! none!] b [pair! none!]] [all [a b  a/1 <  b/1  a/2 <  b/2  b]]
	.<=.: make op! func [a [pair! none!] b [pair! none!]] [all [a b  a/1 <= b/1  a/2 <= b/2  b]]
	.=.:  make op! func [a b] [all [a = b  b]]
	#assert [not 1 .=. 2 .=. 3]

	;; fuzzy number comparison
	~=: make op! almost-equal?: func [a [number!] b [number!]] [
		eps: 1% * to float! max a b
		eps >= to float! abs a - b
	]


	when: make op! func [value test] [either :test [:value][[]]]


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

	;@@ TODO: refactor and export this into the warehouse
	get-relative-path: function [
		"Get PATH relative to BASE"
		path [file!]
		base [file!] "Should be a directory!"
	][
		#assert [dir? base]		;@@ or convert to a dir?
		path: split clean-path path #"/"		;@@ this is where a longest match algorithm could have been useful!
		base: split clean-path base #"/"
		take/last base			;-- remove the empty part
		while [all [path/1 path/1 = base/1]] [remove path remove base]	;@@ BUG: OS dependent: in Windows should use `=`, in Linux `==`
		insert/dup path ".." length? base
		parse path [any [skip ahead skip insert "/"]]
		as file! rejoin path
	]

	#assert [%1/2    = get-relative-path %1/2 %./]
	#assert [%2      = get-relative-path %1/2 %1/]
	#assert [%../1/2 = get-relative-path %1/2 %2/]
	#assert [%1/2    = get-relative-path %/1/2 %/]

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

	;@@ TODO: propose `distance?` should work like this too
	vec-length?: func [
		"Compute length of vector (X,Y)"
		xy [pair!]
	][
		(xy/x ** 2) + (xy/y ** 2) ** 0.5
	]

	space?: func [size [pair! object!]] [
		if object? size [size: size/size]
		#assert [pair? size]
		size/x * size/y
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



	; hold-horses: do-async: :do-atomic



	;; similar to where's-my-error?, but tied to the logger and test system
	trace-it: function [
		"Execute CODE, reporting where it stuck on error; returns [result []] or [error pos-before-failed-expr]"
		code [block!]
		/with inspect [function!] "func [result [any-type!] next-code [block!]]"
	][
		unset 'res
		pos: code
		upd: func [r [any-type!] p][inspect :r pos: p]
		if error? err: try [set/any 'res trace :upd code  'ok] [
			clear find err: form res: err #"^/"		;-- extract only the 1st string
			panic #composite "(err)^/*** During execution of: (mold-part pos 100)"
		]
		reduce [:res pos]		;-- res = error on failure
	]



	; ;; experimental hybrid of `guard` and `where's-my-error?`
	; trace-using: function [
	; 	"Execute CODE, exposing a set of DEFINITIONS (word: expression) to it and reporting where it stuck on error"
	; 	code		[block!]
	; 	definitions	[block!]
	; 	/local res err
	; ][
	; 	unset 'res
	; 	pos: code
	; 	upd: func [_ [any-type!] p][pos: p]
	; 	fun: function [] compose [			;@@ BUG: unfortunately, this binds 'local as well and traps return/exit
	; 		(definitions)
	; 		if error? set 'err try [set/any 'res trace :upd code  'ok] [
	; 			clear find err: form err #"^/"		;-- extract only the 1st string
	; 			panic #composite "(err)^/*** During execution of: (mold-part pos 100)"
	; 		]
	; 		:res
	; 	]
	; 	bind code :fun
	; 	fun
	; ]


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
		sw: collect-set-words code
		ctx: context compose [(sw) none]
		bind-only code bind sw ctx
		ctx
	]


	;@@ TODO: how to name this ctx?
	context [
		;@@ TODO: how to unify this with %common/expect, considering the score computation here?
		expect: function [
			"EXPR should evaluate to anything but false, none or unset, else count it as error"
			expr [block!]
			/local r
		][
			log-artifact art: object compose [
				type: 'condition
				success: no
				expr: (mold expr)
				key: current-key
			]

			red-log: copy "  Reduction log:"
			inspect: func [expr [block!] val [any-type!]] [
				repend red-log ["^/    " pad mold-part/flat/only expr 20 20 " => " mold-part/flat :val 40]
				:val
			]
			e: try/all [set/any 'r trace-deep :inspect expr 'ok]

			append issues/(art/key)/score case [
				error? e
					[panic  #composite "(mold expr) errored out with^/(:e)"  0.0]
				any [unset? :r not :r]
					[panic  #composite "(mold expr) check failed with (:r)^/(red-log)"  0.0]
				'ok	[inform #composite "(mold expr) check succeeded"  art/success: yes  1.0]
			]
			none					;-- no return value
		]


		param: function [
			"Evaluate an EXPR as parameter and check if it's within EXPECTED range"
			expr     [block!] "Code to evaluate"
			expected [block!] "Range as [CRIT-LOW < LOW < IDEAL > HIGH > CRIT-HIGH]"	;@@ TODO: any reason to reduce words in the range?
			/local val crit-lo crit-hi warn-lo warn-hi ideal
		][
			log-artifact art: object compose [		;-- log it before any point of failure
				type: 'parameter
				expr: (mold expr)
				value: none
				status: 'red
				key: current-key
			]

			set/any 'val do expr					;-- may throw
			unless number? :val [
				panic #composite "(mold expr) should have returned a number, not (mold :val)"
				exit
			]
			art/value: val

			if float? val   [val: round/to val 0.0001]
			if percent? val [val: 100% * round/to to float! val 0.0001]		;@@ round/to percent float is bugged REP #42

			parsed?: parse expected [
				   set crit-lo number!
				'< set warn-lo number!
				'< set ideal   number!
				'> set warn-hi number!
				'> set crit-hi number!
				   set msg opt string! (default msg: "")
			]
			panic-if [not parsed?] #composite "invalid expectations block: (mold expected)"
			append issues/(art/key)/score case [
				any [val < crit-lo  val > crit-hi] [
					panic #composite "(mold expr) yielded (val), outside critical range: (crit-lo) to (crit-hi). (msg)"
					0.0
				]
				any [val < warn-lo  val > warn-hi] [
					warn #composite "(mold expr) yielded (val), expected to be in range: (warn-lo) to (warn-hi). (msg)"
					art/status: 'yellow
					0.5
				]
				'normally [
					inform #composite "(mold expr) yielded (val), ideally should be (ideal)"
					art/status: 'green
					1.0
				]
				;@@ TODO: use ideal value for score computation = 1.0, green = 0.9?
			]
			none					;-- no return value
		]

		;@@ BUG: unfortunately this traps return/exit
		set 'eval-results-group func [
			"Evaluate code using EXPECT, PARAM, PARAM-EXACT functions to test certain results"
			body	[block!]
			/key id	[string!] "Specify an identifier to mark produced artifacts with"
		][
			scope [
				current-key/push id
				leaving [current-key/back]
				trace-it bind bind-only body 'leaving self		;-- `leaving` should be available to issues, for more reliable cleanup
			]
			none					;-- no return value
		]

		set 'stop-here func ["Throw a STOP signal for eval-part"][throw/name none 'stop]
		set 'eval-part function [
			"Evaluate CODE until it's tail or it throws a STOP signal; returns CODE at next non-evaluated position"
			code [block!] "CODE must be bound in a way that intermediate results survive between evaluations"
			/key id [string!] "Specify an identifier to mark produced artifacts with"
			/local r
		][
			inspect: func [result [any-type!] next-code] [code: next-code]
			scope [
				current-key/push id
				leaving [current-key/back]
				catch/name [trace-it/with bind bind-only code 'leaving self :inspect] 'stop
			]
			code		;-- empty? can be used to check if it's done or not
		]

	]

	import self
]
