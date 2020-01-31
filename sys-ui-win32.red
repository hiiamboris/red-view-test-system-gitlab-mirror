Red [
	title:   "win32 UI-related API"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
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
		]
	]
]

activate*: routine [
	hwnd [any-type!] "handle! or integer!"	;-- both have /value as 3rd integer (integer is a hack due to handle being unloadable)
	/local h
][
	h: as red-handle! hwnd
	setforegroundwindow getancestor as handle! h/value 2	;-- GA_ROOT
]

