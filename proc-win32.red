Red [
	title:   "win32 process-related API"
	author:  @hiiamboris
	license: 'BSD-3
]


;; this is strictly required when using `call/shell`
kill-process-tree: function [
	"Terminate a tree of processes starting with HPROC"
	hproc [handle!]
][
	list: list-all-processes
	kill-tree: function [target-pid] [
		foreach [child-pid parent-pid] list [
			if target-pid = parent-pid [kill-tree child-pid]
		]
		h: get-pid-handle target-pid
		if is-process-alive? h [
			kill-process h
			log-info #composite "Killed process with PID (target-pid)"
		]
		close-handle h
	]
	root-pid: get-pid-from-handle hproc
	log-info #composite "Cutting process tree starting with PID (root-pid) (mold/all hproc)..."
	kill-tree root-pid
]


start-exe: function [exe [file!] /output out [file!]] [
	assert [exists? exe]
	pid: either output [call/show/shell #composite {"(exe)" >"(out)"}][call/show exe]		;-- >output doesn't work without /shell
	assert [pid <> -1]
	handle: get-pid-handle pid
	; handle: process-into-job handle
	log-info #composite {Started executable (exe) [PID: (pid), handle: (mold/all handle)] }
	handle
]


stop-exe: function [
	"Wait for a process to terminate or force it to; return the time it took to finish"
	handle [handle! integer!]
	/max period [time! float! integer!] "Defaults to 5 seconds"
][
	if integer? handle [handle: make handle! handle]
	#assert [handle <> make handle! 0]
	t1: now/time/precise
	if all [max period < 0] [period: 0]
	; either while-waiting any [period 5] [is-job-alive? handle] [] [
	either while-waiting any [period 5] [is-process-alive? handle] [] [
		inform #composite "Finished process with handle: (mold/all handle)"
	][
		panic  #composite "Process with handle (mold/all handle) is not terminating"
		; kill-job handle
		; kill-process handle
		kill-process-tree handle
	]
	now/time/precise - t1 + 24:00 % 24:00
]


