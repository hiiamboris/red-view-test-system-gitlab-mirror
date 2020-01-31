Red [
	title:   "job dispatcher for the view test system"
	author:  @hiiamboris
	license: 'BSD-3
]


#include %dope.red

comment {
	Design notes:
	- why use workers:
	   1) eliminate the test system environment influence onto tests
	   2) parallelize compilations
	   3) do not let crashing tests interrupt the whole test process
	- why files and not I/O redirection: redirection doesn't work (#4241)
	- why divide tests into types: different strategy of evaluation
	   1) some can be parellelized, some not
	   2) test system may choose test ordering based on this info
	   3) usage of the not-requested-for functionality indicates a bug likely
	   4) crashing tests may use more defense mechanisms (not decided yet)
}

;@@ TODO: write each test into a separate file? worth it?
;@@ TODO: master's status bar that tells current running script(test) and results...
;@@ TODO: prebuild the libredrt

jobs: context [

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

	working-dir: rejoin [%run- timestamp %/]

	file-for-test: function [
		"Generate a script file name for a given test name/number"
		test [integer! string! issue!]
	][
		test: either string? test [copy test][mold test]	;-- "#issue" should be with a shard
		test: replace/all test charset [not #"a" - #"z" #"0" - #"9"] #"-"
		rejoin [working-dir test ".red"]				;-- using .red for R/S scripts too  @@ TODO: check that no test has name 'worker-n' ...
	]

	worker!: object [
		;; constant properties
		pid: none
		handle: none									;-- PID is unreliable
		name: none
		stdin: stdout: stderr: none						;-- worker's IO streams file names
		;; volatile properties
		stdout-offset: stderr-offset: 0					;-- where to read the next item from
		; task: none										;-- what's it doing right now (set by tasker funcs)
		timestamp: now/precise							;-- datetime of last `task` change (including busy->idle)
		last-output: last-errors: none					;-- will contain output from the last finished task
		last-code: none									;-- last given task's code
		last-assigned-task-id: 0
		last-completed-task-id: 0
	]
	workers: []											;-- up to max-workers-count length; 1=main worker, 2-4=heavy workers; new instances replace old ones
	max-workers-count: 4								;@@ TODO: use CPU core count; https://stackoverflow.com/questions/150355/programmatically-find-the-number-of-cores-on-a-machine
	last-worker-index: 0								;-- always increases - controls file numeration

	tasks: context [
		last-id: 0							;-- every task is assigned a unique id
		timeouts: #(						;@@ TODO: use these for deadlock detection
			compile: 600.0					;-- 10 min - should be enough? @@ TODO: check by cpu load if they are compiling?
			display: 1.0					;-- for view [..] tasks - analyze after 1 second at worst
			default: 1.0					;-- for unspecified tests - usually instantaneous
		)
		;@@ TODO: maybe queues? but then who's to check them?
		;; for now, if no free worker - assigned to random one
	]

	task!: object [
		id: none
		worker-index: none					;-- worker it's assigned to (1 to max-workers-count)
		; job: none							;@@ need it?
		worker: does [all [worker-index  pick workers worker-index]]
		running?: function [
			"Check if task was accepted but not finished"
		][
			all [
				wr: worker
				wr/last-assigned-task-id >= id
				wr/last-completed-task-id < id
			]
		]
		finished?: function [
			"Check if task was accepted and finished"
		][
			wr: worker
			#assert [wr/last-assigned-task-id >= id]
			wr/last-completed-task-id >= id
		]
	]


	; is-red-available?	; run red "print something" - test if it returned something (using worker mechanisms)

	;@@ reuse old worker numbers & files? bad, since erases history of events

	;@@ TODO: somehow reflect worker type in file names (to know the inheritance)?

	restart-worker: function [
		"Restart the previously created worker"
		worker [object!]
	][
		#assert [find/same workers worker]
		;@@ TODO: kill if deadlocked?
		if worker/pid [		;; close it first
			stop-worker worker		;@@ TODO: error handling
			if worker/handle [close-process-handle worker/handle]
		]
		#assert [none? worker/pid]
		remove find/same workers worker
		set worker start-worker
	]

	start-worker: has [wc worker][ ; return info about it - to be used as an argument for jobs dispatch
		if max-workers-count <= length? workers [ERROR "Out of allowed worker slots"]
		wi: last-worker-index + 1
		unless exists? working-dir [create-dir working-dir]
		worker: make worker! [
			stdin:  #composite %"(working-dir)stdin-(wi).txt"
			stdout: #composite %"(working-dir)stdout-(wi).txt"
			stderr: #composite %"(working-dir)stderr-(wi).txt"
			name:   #composite %"(working-dir)worker-(wi).red"
			foreach stream [stdin stdout stderr] [
				write get stream ""				;-- empty streams in case they were not
			]
			;; `input` doesn't work - see #4241
			write name #composite {
				Red [needs: view]
				context [					;-- hide used words from loaded code
					ofs: 0
					bin: none
					pos: none
					forever [
						wait 1e-2			;-- lessen CPU load
						do-events/no-wait	;-- process queued events
						bin: read/binary/seek %stdin-(wi).txt ofs
						if pos: find/tail bin %"^^/" [
							ofs: ofs + offset? bin pos
							str: to string! copy/part bin pos
							print ["=== BUSY:" str]
							task: load/all str
							try/all [do next task]
							print ["=== IDLE:" :task/1 "@" now/precise]
						]
					]
				]
			}
			;@@ TODO: hide worker's words from the user code
			;@@ /input/output/error isn't working - see #4241
			pid: call #composite {red --cli (to-local-file name) <(to-local-file stdin) 1>(to-local-file stdout) 2>(to-local-file stderr)}
			handle: get-pid-handle pid
			log-info #composite {Started worker (name) ("(")PID:(pid)(")")}
		]
		last-worker-index: wi				;-- update the counter after everything succeeds
		append workers worker

		worker
	]

	kill-worker: function [worker [object!]] [  ; when it hung (otherwise `quit` should be commanded)
		assert [worker/pid]
		; switch/default system/platform [
		; 	Windows [ok: 0 = call/shell/wait #composite "taskkill /f /t /pid (worker/pid)"]		;-- destroys the whole process tree - both cmd and console
		; ][do make error! rejoin ["kill-worker: unsupported platform " platform]]
		; if ok [
		; 	worker/pid: none
		; 	;@@ remove it from the `workers` list?
		; ]
		if alive? worker [
			kill-process worker/handle
			worker/pid: none
		]
	]

	stop-worker: function [worker [object!]] [  ; when it hung (otherwise `quit` should be commanded)
		assert [worker/pid]
		unless alive? worker [				;-- terminated already?
			worker/pid: none
			return yes
		]

		assert [not find peek-worker-output worker "quit"]
		send-to* worker "quit"
		loop 50 [			;-- wait half a sec max (else kill)
			wait 1e-2
			if find peek-worker-output worker "quit" [
				worker/pid: none
				return yes
			]
		]
		;@@ remove it from the `workers` list?
		no
	]

	stop-all-workers: function [] [
		foreach worker workers [if worker/pid [stop-worker worker]]
	]

	kill-all-workers: function [] [
		foreach worker workers [if worker/pid [kill-worker worker]]
	]

	alive?: function [worker [object!]] [
		is-process-alive? worker/handle
	]

	;@@ should not check the worker output? otherwise someone might miss it later
	idle?: function [worker [object!]] [
		worker/last-assigned-task-id = worker/last-completed-task-id
	]

	;; low level, does not check anything
	send-to*: function [worker [object!] command [string!]] [
		new-id: worker/last-assigned-task-id: tasks/last-id: tasks/last-id + 1
		task: make task! compose [
			id: (new-id)
			worker-index: (index? find/same workers worker)
		]
		write/append/lines worker/stdin rejoin [task/id #" " command]		;@@ TODO: trim command from newlines? or it's ok?
		task
	]

	;@@ TODO: dump all stuff ever sent to each worker somewhere; rather than creating 1-line files
	send-to: function [worker [object!] command [block!] /wait] [
		also send-to* worker worker/last-code: mold/only/all/flat command			;@@ BUG: /all may become unloadable - use it or not?
			if wait [wait-for worker]
		;@@ TODO: wait until worker signals it's running this task?
	]

	; send: function [	 ; to a free worker - or create new
	; 	"Send command to the first free worker (waits if they're busy); returns yes on success or no on timeout"
	; 	command [block!]
	; 	/force "Create a new worker if all are busy"
	; ][
	; 	;; this must not wait indefinitely but check workers' timeouts
	; 	;; since worker is free, we can check acknowledgement
	; 	;; must also set `task` and `last-code`
	; ]

	send-main: function [
		"Send command to the main worker"
		command [block!]
	][
		; #assert [running? main-worker]
		send-to main-worker command
	]

	send-heavy: function [   ; for compilations & long tests
		"Send command to workers other than the main one"
		command [block!]
		/local i
	][
		for i 2 max-workers-count [
			if none? workers/:i [worker: start-worker  break]		;-- free slot - start a new worker
			if idle? workers/:i [worker: workers/:i  break]			;-- idle worker - use it
		]
		if none? worker [worker: random/only next workers]			;-- otherwise send to a random heavy worker
		send-to worker command
	]

	; all-busy?  ?

	; shoot-layout ; based on send-general


	;@@ TODO: assign task types, collect info on each type (esp. duration), balance load based on predicted finish time

	wait-for-task: function [task [object!] /max period [float! integer! time!]] [		;@@ TODO: timeouts
		if max [period: to time! period]
		#assert [task/id]
		worker: task/worker
		t1: now/time/precise
		while [worker/last-completed-task-id < task/id] [		;-- = if this is the task; > if completed previously
			if max [
				t2: now/time/precise
				dt: t2 - t1 + 24:00 % 24:00
				if dt >= period [return none]
			]
			output: read-task-report worker
			wait 1e-2
		]
		output
	]

	; wait-for-worker: function [worker [object!] /max period [float! integer! time!]] [
	; 	if max [period: to time! period]
	; 	t1: now/time/precise
	; 	while [not idle? worker] [
	; 		if max [
	; 			t2: now/time/precise
	; 			dt: t2 - t1 + 24:00 % 24:00
	; 			if dt >= period [return none]
	; 		]
	; 		output: 
	; 		wait 1e-2
	; 	]
	; 	worker/last-output
	; ]



	peek-worker-output: func [worker [object!]] [		; does not consume but returns unprocessed part of worker's output file
		to string! read/binary/seek worker/stdout worker/stdout-offset
	]

	; read-worker-output: function [worker [object!]] [
	; 	also to string! bin: read/binary/seek worker/stdout ofs: worker/stdout-offset
	; 		worker/stdout-offset: ofs + length? bin
	; ]

	;; returns none if performing no task
	;; returns id (integer) if next task is not complete
	;; returns output (string) if next is complete
	read-task-report: function [worker [object!] /local id code timestamp output] [
		bin: read/binary/seek worker/stdout ofs: worker/stdout-offset

		=busy-line=: ["=== BUSY: " copy id to #" " " "   copy code to lf lf]
		=idle-line=: ["=== IDLE: " copy id to #" " " @ " copy timestamp to lf lf]
		unless parse bin [
			=busy-line=
			copy output to "=== IDLE:"
			=idle-line=
			size:
		][return attempt [to integer! to string! id]]

		foreach w [code timestamp id output] [set w to string! get w]
		unless worker/last-code = code: trim/lines code [
			panic #composite {*** INTERNAL ERROR: Code/Last-code mismatch: code="(code)" last-code="(worker/last-code)"}
		]
		worker/stdout-offset: ofs + offset? bin size
		worker/timestamp: trim/lines timestamp
		worker/last-output: output: trim/lines output
		worker/last-completed-task-id: to integer! id
		output
	]

	; reset-system-words
	init: does [
		main-worker: start-worker
		q: does [
			stop-all-workers
			kill-all-workers		;-- force-kill those that do not yield
			quit
		]
		print "Please quit with Q or worker threads will remain active"
	]
]
