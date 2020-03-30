Red [
	title:   "win32 UI-related API"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
	RECT_STRUCT: alias struct! [
		left		[integer!]
		top			[integer!]
		right		[integer!]
		bottom		[integer!]
	]

	#import [
		"user32.dll" stdcall [
			SetForegroundWindow: "SetForegroundWindow" [
				hWnd		[handle!]
				return:		[logic!]
			]
			GetAncestor: "GetAncestor" [
				hWnd 		[handle!]
				gaFlags		[integer!]
				return:		[handle!]
			]
			GetWindowRect: "GetWindowRect" [
				hWnd		[handle!]
				lpRect		[RECT_STRUCT]
				return:		[integer!]
			]
			ShowWindow: "ShowWindow" [
				hWnd		[handle!]
				nCmdShow	[integer!]
				return:		[logic!]
			]
		]
	]
]

activate*: routine [
	hwnd [any-type!] "handle! or integer!"
	/local h
][
	assert any [
		TYPE_HANDLE  = TYPE_OF(hwnd)
		TYPE_INTEGER = TYPE_OF(hwnd)
	]
	h: as red-handle! hwnd
	SetForegroundWindow GetAncestor as handle! h/value 2	;-- 2 = GA_ROOT
]

minimize*: routine [
	hwnd [any-type!] "handle! or integer!"
	/local rh h
][
	assert any [
		TYPE_HANDLE  = TYPE_OF(hwnd)
		TYPE_INTEGER = TYPE_OF(hwnd)
	]
	rh: as red-handle! hwnd
	h: GetAncestor as handle! rh/value 2	;-- 2 = GA_ROOT
	ShowWindow h 6							;-- 6 = SW_MINIMIZE
]

restore*: routine [
	hwnd [any-type!] "handle! or integer!"
	/local rh h
][
	assert any [
		TYPE_HANDLE  = TYPE_OF(hwnd)
		TYPE_INTEGER = TYPE_OF(hwnd)
	]
	rh: as red-handle! hwnd
	h: GetAncestor as handle! rh/value 2	;-- 2 = GA_ROOT
	ShowWindow h 9							;-- 9 = SW_RESTORE
]

get-window-size*: routine [
	hwnd [any-type!] "handle! or integer!"
	return: [pair!]
	/local h rc [RECT_STRUCT value]
][
	assert any [
		TYPE_HANDLE  = TYPE_OF(hwnd)
		TYPE_INTEGER = TYPE_OF(hwnd)
	]
	h: as red-handle! hwnd
	GetWindowRect as handle! h/value rc
	as red-pair! stack/set-last as cell! pair/push rc/right - rc/left rc/bottom - rc/top
]

