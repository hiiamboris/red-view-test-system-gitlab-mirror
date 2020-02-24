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
		]
	]
]

activate*: routine [
	hwnd [any-type!] "handle! or integer!"	;-- both have /value as 3rd integer (integer is a hack due to handle being unloadable)
	/local h
][
	h: as red-handle! hwnd
	SetForegroundWindow GetAncestor as handle! h/value 2	;-- GA_ROOT
]

get-window-size*: routine [
	hwnd [any-type!] "handle! or integer!"	;-- both have /value as 3rd integer (integer is a hack due to handle being unloadable)
	return: [pair!]
	/local h rc [RECT_STRUCT value]
][
	h: as red-handle! hwnd
	GetWindowRect as handle! h/value rc
	as red-pair! stack/set-last as cell! pair/push rc/right - rc/left rc/bottom - rc/top
]

