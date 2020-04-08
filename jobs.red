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

value-of: func ['w] [if value? to word! w [get w]]

jobs: make any [value-of jobs  object!] [

	stack-friendly
	file-for-test: function [
		"Generate a script file name for a given test name/number"
		test [integer! string! issue!]
	][
		test: either string? test [copy test][mold test]	;-- "#issue" should be with a shard
		test: replace/all test charset [not #"a" - #"z" #"0" - #"9"] #"-"
		rejoin [test ".red"]				;-- using .red for R/S scripts too  @@ TODO: check that no test has name 'worker-n' ...
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
	once workers: []									;-- up to max-workers-count length; 1=main worker, 2-4=heavy workers; new instances replace old ones
	max-workers-count: 4								;@@ TODO: use CPU core count; https://stackoverflow.com/questions/150355/programmatically-find-the-number-of-cores-on-a-machine
	once last-worker-index: 0							;-- always increases - controls file numeration

	once tasks: context [
		last-id: 0							;-- every task is assigned a unique id
		timeouts: #(						;@@ TODO: use these for deadlock detection
			compile: 600.0					;-- 10 min - should be enough? @@ TODO: check by cpu load if they are compiling?
			display: 1.0					;-- for view [..] tasks - analyze after 1 second at worst
			default: 1.0					;-- for unspecified tests - usually instantaneous
		)
		history: #()						;-- id -> task object ;@@ TODO: clean it up? when?
		;@@ TODO: maybe queues? but then who's to check them?
		;; for now, if no free worker - assigned to random one
	]

	task!: object [
		id: none
		worker-index: none					;-- worker it's assigned to (1 to max-workers-count)
		output: none						;-- filled when task is finished
		; result: none						;@@ ??? should it contain the loaded result?
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

	stack-friendly
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
		start-worker/replace worker
	]

	stack-friendly
	start-worker: func [/replace old [object!] /local wc worker][ ; return info about it - to be used as an argument for jobs dispatch
		if all [
			not replace
			max-workers-count <= length? workers
		] [ERROR "Out of allowed worker slots"]

		wi: last-worker-index + 1
		worker: make worker! [
			stdin:  #composite %"(working-dir)stdin-(wi).txt"		;-- use absolute paths to be able to change directories
			stdout: #composite %"(working-dir)stdout-(wi).txt"
			; stderr: #composite %"(working-dir)stderr-(wi).txt"
			name:   #composite %"(working-dir)worker-(wi).red"
			foreach stream [stdin stdout] [  ; stderr] [
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
						wait 1e-2					;-- lessen CPU load
						unless empty? system/view/screens/1/pane [		;-- 0.6.4 bug workaround
							loop 5 [do-events/no-wait]					;-- process queued events
						]
						bin: read/binary/seek (mold stdin) ofs
						if pos: find/tail bin %"^^/" [
							ofs: ofs + offset? bin pos
							str: to string! copy/part bin pos
							print ["=== BUSY:" str]
							task: load/all str
							if error? e: try/all [do next task 'ok] [print e]
							print ["=== IDLE:" :task/1 "@" now/precise]
						]
					]
				]
			}
			;@@ /input/output/error isn't working - see #4241
			; pid: call/shell #composite {d:\devel\red\red-src\red\console-view.exe (to-local-file name) 1>(to-local-file stdout) 2>(to-local-file stderr)}
			; pid: call/shell #composite {d:\devel\red\red-src\red\console-view.exe (to-local-file name) 1>(to-local-file stdout) 2>(to-local-file stderr)}
			; pid: call/shell #composite {d:\devel\red\red-src\red\console-view-3369-nodebug.exe (to-local-file name) 1>(to-local-file stdout) 2>(to-local-file stderr)}
			;@@ TODO: move this unportable shell trickery outta here
			; pid: call/shell #composite {d:\devel\red\red-src\red\console-view.exe (to-local-file name) 1>(to-local-file stdout)}
			pid: call/shell #composite {(config/command-to-test) (to-local-file name) 1>(to-local-file stdout)}
			; pid: call/shell #composite {d:\devel\red\red-src\red\console-view-3369-nodebug.exe (to-local-file name) 1>(to-local-file stdout)}
			assert [pid <> -1]
			; pid: call #composite {red --cli (to-local-file name) 1>(to-local-file stdout) 2>(to-local-file stderr)}
			handle: get-pid-handle pid				;-- pid is not persistent - console may close and it's pid reassigned to another program!
			; handle: process-into-job handle
			log-info #composite {Started worker (name) ("(")PID:(pid)(")")}
		]
		last-worker-index: wi				;-- update the counter after everything succeeds
		either replace
			[ set old worker ]
			[ append workers worker ]

		worker
	]

	stack-friendly
	kill-worker: function [worker [object!]] [  ;-- when it hung (otherwise `quit` should be commanded)
		assert [worker/pid]
		if alive? worker [
			; kill-job worker/handle
			; kill-process worker/handle
			kill-process-tree worker/handle
			worker/pid: worker/handle: none
		]
	]

	stack-friendly
	stop-worker: function [worker [object!]] [  ; when it hung (otherwise `quit` should be commanded)
		assert [worker/pid]
		unless alive? worker [				;-- terminated already?
			worker/pid: worker/handle: none
			return yes
		]

		assert [not find peek-worker-output worker "quit"]
		send-to* worker "quit"
		loop 50 [			;-- wait half a sec max (else kill)
			wait 1e-2
			if find peek-worker-output worker "quit" [
				worker/pid: worker/handle: none
				return yes
			]
		]
		;@@ remove it from the `workers` list?
		no
	]

	stack-friendly
	stop-all-workers: function [] [
		foreach worker workers [if worker/pid [stop-worker worker]]
	]

	stack-friendly
	kill-all-workers: function [] [
		foreach worker workers [if worker/pid [kill-worker worker]]
	]

	stack-friendly
	alive?: function [worker [object!]] [
		all [worker/handle  is-process-alive? worker/handle]
		; is-job-alive? worker/handle
	]

	;@@ should not check the worker output? otherwise someone might miss it later
	stack-friendly
	idle?: function [worker [object!]] [
		worker/last-assigned-task-id = worker/last-completed-task-id
	]

	;; low level, does not check anything
	stack-friendly
	send-to*: function [worker [object!] command [string!]] [
		new-id: worker/last-assigned-task-id: tasks/last-id: tasks/last-id + 1
		task: make task! compose [
			id: (new-id)
			worker-index: (index? find/same workers worker)
		]
		tasks/history/:new-id: task						;-- register it for later output assignment
		write/append/lines worker/stdin rejoin [task/id #" " command]		;@@ TODO: trim command from newlines? or it's ok?
		task
	]

	;@@ TODO: dump all stuff ever sent to each worker somewhere; rather than creating 1-line files
	stack-friendly
	send-to: function [worker [object!] command [block!] /wait] [
		task: send-to* worker worker/last-code: mold/only/all/flat command			;@@ BUG: /all may become unloadable - FIXED by commit
		if wait [wait-for-task task]
		task
		;@@ TODO: wait until worker signals it's running this task?
	]

	stack-friendly
	send-main: function [
		"Send command to the main worker"
		command [block!]
	][
		; #assert [running? main-worker]
		send-to main-worker command
	]

	stack-friendly
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

	stack-friendly
	wait-for-task: function [task [object!] /max period [float! integer! time!]] [		;@@ TODO: timeouts
		if task/finished? [return task/output]					;-- already finished?
		if max [period: to time! period]
		#assert [task/id]
		worker: task/worker
		either
			while-waiting
				period
				[worker/last-completed-task-id < task/id]		;-- = if this is the task; > if completed previously
				[read-task-report worker]
			[task/output][none]								;@@ none or error?
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




	non-alpha-char: charset [not #"a" - #"z" #"A" - #"Z"]
	remove-GC-output: func [s [string!]] [
		parse s [
			any [
				to ["root: " 5 20 non-alpha-char "runs: " 2 10 non-alpha-char "mem: "]
				remove thru [#"^/" | end]
			] to end
		]
		s
	]

	peek-worker-output: function [worker [object!]] [		; does not consume but returns unprocessed part of worker's output file
		remove-GC-output to string! read/binary/seek worker/stdout worker/stdout-offset
	]

	; read-worker-output: function [worker [object!]] [
	; 	also to string! bin: read/binary/seek worker/stdout ofs: worker/stdout-offset
	; 		worker/stdout-offset: ofs + length? bin
	; ]

	read-heavy-reports: function ["Update all compilation tasks state"] [
		foreach worker next workers [		;-- skip the main-worker
			rep: read-task-report worker
			if all [string? rep  err: find rep "Cannot access source file:"] [
				panic #composite "Compilation task failed with:^/(err)"
			]
			while [rep <> new: read-task-report worker] [rep: new]	;-- stop reading when it returns either the same (busy) task or none
		]
	]

	;; returns none if performing no task
	;; returns id (integer) if next task is not complete
	;; returns output (string) if next is complete
	read-task-report: function [worker [object!] /local id code timestamp output out-of-order] [
		bin: read/binary/seek worker/stdout ofs: worker/stdout-offset

		=busy-line=: ["=== BUSY: " copy id to #" " " "   copy code to #"^/" #"^/"]
		=idle-line=: ["=== IDLE: " copy id to #" " " @ " copy timestamp to #"^/" #"^/"]
		unless parse bin [
			copy out-of-order to "=== BUSY:"
			=busy-line=
			copy output to "=== IDLE:"
			=idle-line=
			size: to end
		][return attempt [to integer! to string! id]]

		foreach w [code timestamp id output out-of-order] [
			set w trim/head/tail to string! get w
			replace/all get w "^M^/" "^/"
		]
		remove-GC-output out-of-order
		remove-GC-output output
		; unless worker/last-code = code [		no longer actual now that we have tasks
		; 	panic #composite {*** INTERNAL ERROR: Code/Last-code mismatch: code="(code)" last-code="(worker/last-code)"}
		; ]
		unless empty? out-of-order [		;@@ should I save it to the worker?
			panic #composite "*** Out-of-order worker output encountered:^/(out-of-order)"
		]
		worker/stdout-offset: ofs + offset? bin size
		worker/timestamp: timestamp
		worker/last-output: output
		worker/last-completed-task-id: id: to integer! id
		task: tasks/history/:id
		#assert [task]
		task/output: output
		task/finished?: yes		;-- force it ;@@ TODO: think on a better structure of querying state... what a mess
		output
	]

	; reset-system-words
	init: does [
		unless object? :config [config: object [command-to-test: none last-working-dir: none]]
		unless attempt [config/command-to-test] [config: make config [command-to-test: "red --cli"]]
		log-info #composite "Configured worker console is: (config/command-to-test)"

		main-worker: start-worker
		quit-gracefully: q: does [
			stop-all-workers
			kill-all-workers		;-- force-kill those that do not yield
			change-dir startup-dir
			quit
		]
		print "Please quit with Q or worker threads will remain active"
	]

	crash-main-worker: does [send-main [to float! "1e"]]		;-- for debugging
]
