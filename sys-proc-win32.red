Red [
	title:   "win32 process-related low-level API"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
	; SECURITY_ATTRIBUTES: alias struct! [
	; 	nLength 			 [integer!]		;-- should be 12
	; 	lpSecurityDescriptor [int-ptr!]		;-- can be null
	; 	bInheritHandle 		 [logic!]
	; ]

	; JOBOBJECT_BASIC_PROCESS_ID_LIST: alias struct! [
	; 	NumberOfAssignedProcesses	[integer!]
	; 	NumberOfProcessIdsInList	[integer!]
	; 	ProcessIdList				[int-ptr!]		;-- points to an array of pids
	; ]

	PROCESSENTRY32: alias struct! [
		dwSize					[integer!]
		cntUsage				[integer!]
		th32ProcessID			[integer!]
		th32DefaultHeapID		[int-ptr!]
		th32ModuleID			[integer!]
		cntThreads				[integer!]
		th32ParentProcessID		[integer!]
		pcPriClassBase			[integer!]
		dwFlags					[integer!]
		szExeFile001			[float!]		;-- szExeFile[MAX_PATH=260] -- 260=65*4=32*8+4
		szExeFile002			[float!]
		szExeFile003			[float!]
		szExeFile004			[float!]
		szExeFile005			[float!]
		szExeFile006			[float!]
		szExeFile007			[float!]
		szExeFile008			[float!]
		szExeFile009			[float!]
		szExeFile010			[float!]
		szExeFile011			[float!]
		szExeFile012			[float!]
		szExeFile013			[float!]
		szExeFile014			[float!]
		szExeFile015			[float!]
		szExeFile016			[float!]
		szExeFile017			[float!]
		szExeFile018			[float!]
		szExeFile019			[float!]
		szExeFile020			[float!]
		szExeFile021			[float!]
		szExeFile022			[float!]
		szExeFile023			[float!]
		szExeFile024			[float!]
		szExeFile025			[float!]
		szExeFile026			[float!]
		szExeFile027			[float!]
		szExeFile028			[float!]
		szExeFile029			[float!]
		szExeFile030			[float!]
		szExeFile031			[float!]
		szExeFile032			[float!]
		szExeFile033			[integer!]
	]

	#import [
		"kernel32.dll" stdcall [
			GetLastError: "GetLastError" [
				return:                 [integer!]
			]
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
			CreateToolhelp32Snapshot: "CreateToolhelp32Snapshot" [
				dwFlags					[integer!]
				th32ProcessID			[integer!]
				return:					[handle!]
			]
			Process32First: "Process32First" [
				hSnapshot				[handle!]
				lppe					[PROCESSENTRY32]
				return:					[logic!]
			]
			Process32Next: "Process32Next" [
				hSnapshot				[handle!]
				lppe					[PROCESSENTRY32]
				return:					[logic!]
			]
			GetProcessId: "GetProcessId" [
				Process					[handle!]
				return:					[integer!]
			]

			;@@ jobs are shit on W7 and earlier - do not use them
			; TerminateJobObject: "TerminateJobObject" [
			; 	hJob					[handle!]
  	; 			uExitCode				[integer!]
  	; 			return:					[logic!]
  	; 		]
			; CreateJobObject: "CreateJobObjectW" [
			; 	lpJobAttributes			[SECURITY_ATTRIBUTES]	;-- can be null, but won't be inherited by child processes then
			; 	lpName					[byte-ptr!]	;-- UTF16, can be null
			; 	return:					[handle!]
			; ]
			; AssignProcessToJobObject: "AssignProcessToJobObject" [
			; 	hJob					[handle!]
			; 	hProcess				[handle!]
			; 	return:					[logic!]
			; ]
			; QueryInformationJobObject: "QueryInformationJobObject" [
			; 	hJob							[handle!]
			; 	JobObjectInformationClass		[integer!]
			; 	lpJobObjectInformation			[byte-ptr!]
			; 	cbJobObjectInformationLength	[integer!]
			; 	lpReturnLength					[int-ptr!]
			; 	return:							[logic!]
			; ]
		]
	]
]

; PROCESS_QUERY_INFORMATION (0x0400)
; PROCESS_TERMINATE (0x0001)
get-pid-handle: routine [pid [integer!] return: [handle!]] [
	handle/box OpenProcess 0401h no pid
]

get-pid-from-handle: routine [hprocess [handle!] return: [integer!]] [
	GetProcessId as handle! hprocess/value
]

close-handle: close-process-handle: routine [process [handle!]] [
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

;@@ BUG: this doesn't work with call/shell - only the shell gets terminated
kill-process: routine [process [handle!]] [
	TerminateProcess process/value 100
]


list-all-processes: routine [return: [block!] /local h b pe [PROCESSENTRY32 value]] [
	h: CreateToolhelp32Snapshot 2 0			;-- 2 = TH32CS_SNAPPROCESS
	b: block/push-only* 32
	if Process32First h pe [
		until [
			integer/make-in b pe/th32ProcessID
			integer/make-in b pe/th32ParentProcessID
			not Process32Next h pe
		]
	]
	CloseHandle as-integer h
	b
]


; create-job-object: routine [return: [handle!] /local sa [SECURITY_ATTRIBUTES value]] [
; 	sa/nLength: 12
; 	sa/lpSecurityDescriptor: null
; 	sa/bInheritHandle: yes
; 	handle/box CreateJobObject sa null
; ]

; process-into-job: routine [
; 	hproc [handle!]
; 	return: [handle!]
; 	/local r hjob sa [SECURITY_ATTRIBUTES value]
; ][
; 	;; create job object
; 	sa/nLength: size? SECURITY_ATTRIBUTES
; 	sa/lpSecurityDescriptor: null
; 	sa/bInheritHandle: yes
; 	hjob: CreateJobObject sa null
; 	probe hjob
; 	assert hjob <> null

; 	;; assign process to it
; 	r: AssignProcessToJobObject hjob as handle! hproc/value
; 	probe r
; 	probe GetLastError
; 	assert r

; 	handle/box as-integer hjob
; ]

; kill-job: routine [hjob [handle!]] [
; 	TerminateJobObject as handle! hjob/value 100
; 	CloseHandle hjob/value		;@@ should we close it?
; ]

; ;@@ BUG: pids can be reused - this is unreliable crapsome MS junk
; list-job-pids: routine [
; 	hjob [handle!]
; 	return: [block!]
; 	/local r b n int-buf pids [JOBOBJECT_BASIC_PROCESS_ID_LIST value]
; ][
; 	int-buf: [0 0 0 0 0 0 0 0  0 0 0 0 0 0 0 0]		;-- 16 ints
; 	pids/NumberOfAssignedProcesses: 16
; 	pids/ProcessIdList: int-buf
; 	r: QueryInformationJobObject
; 		as handle! hjob/value
; 		3							;-- JobObjectBasicProcessIdList
; 		as byte-ptr! pids
; 		size? pids
; 		null
; 	assert r
; 	assert pids/NumberOfAssignedProcesses = pids/NumberOfProcessIdsInList	;-- list big enough?
; 	n: pids/NumberOfProcessIdsInList
; 	b: block/push-only* n
; 	loop n [
; 		integer/make-in b int-buf/1
; 		int-buf: int-buf + 1
; 	]
; 	b
; ]

; is-job-alive?: function [hjob [handle!]] [
; 	foreach pid list-job-pids hjob [
; 		h: get-pid-handle pid
; 		live?: is-process-alive? h
; 		close-process-handle h
; 		if live? [return yes]
; 	]
; 	no
; ]
