Red [
	title:   "win32 process-related API"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
	#import [
		"kernel32.dll" stdcall [
			OpenProcess: "OpenProcess" [
				dwDesiredAccess			[integer!]
				bInheritHandle			[logic!]
				dwProcessId				[integer!]
				return:					[integer!]
			]
			GetExitCodeProcess: "GetExitCodeProcess" [
				hProcess				[integer!]
				lpExitCode				[int-ptr!]
				return:                 [logic!]
			]
			CloseHandle: "CloseHandle" [
				hObject                 [integer!]
				return:                 [logic!]
			]
			TerminateProcess: "TerminateProcess" [
				hProcess				[integer!]
				uExitCode				[integer!]
				return:					[logic!]
			]
		]
	]
]

; PROCESS_QUERY_INFORMATION (0x0400)
; PROCESS_TERMINATE (0x0001)
get-pid-handle: routine [pid [integer!] return: [handle!]] [
	handle/box OpenProcess 0401h no pid
]

close-process-handle: routine [process [handle!]] [
	CloseHandle process/value
]

;; NOTE: GetExitCodeProcess is unreliable - STILL_ACTIVE can be a valid return code
;; however, other ways are flawed as well it seems
is-process-alive?: routine [
	process [handle!]
	return: [logic!]
	/local code [integer!] ok? [logic!]
][
	code: 0
	ok?: GetExitCodeProcess process/value :code
	all [ok? code = 259]				;-- 259 = STILL_ACTIVE
]

kill-process: routine [process [handle!]] [
	TerminateProcess process/value 100
]
