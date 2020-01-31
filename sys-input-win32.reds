Red/System [
	title:   "win32 input simulation API"
	author:  @hiiamboris
	license: 'BSD-3
]

; MapVirtualKey
; GetAsyncKeyState
; GetKeyboardState - synchronous, as GetKeyState ; useless
; SetKeyboardState

; > An application can simulate a press of the PRINTSCRN key in order to obtain a screen snapshot and save it to the clipboard.
; > To do this, call keybd_event with the bVk parameter set to VK_SNAPSHOT.

#import [
	"user32.dll" stdcall [
		keybd_event: "keybd_event" [
			bVk			[byte!]
			bScan		[byte!]
			dwFlags		[integer!]
			dwExtraInfo	[pointer! [float64!]]		;-- points to ULONG (uint64); unused
		]
		mouse_event: "mouse_event" [
			dwFlags		[integer!]
			dx			[integer!]
			dy			[integer!]
			dwData		[integer!]					;-- for wheel, and buttons 3-4
			dwExtraInfo	[pointer! [float64!]]		;-- points to ULONG (uint64); unused
		]
		VkKeyScan: "VkKeyScanW" [					;-- Translates a character to the corresponding virtual-key code and shift state for the current keyboard.
			ch			[integer!]
			return:		[integer!]
		]
		MapVirtualKey: "MapVirtualKeyW" [			;-- Translates (maps) a virtual-key code into a scan code or character value, or translates a scan code into a virtual-key code.
			uCode		[integer!]
			uMapType	[integer!]
			return:		[integer!]
		]
		GetAsyncKeyState: "GetAsyncKeyState" [
		    nVirtKey    [integer!]
		    return:     [integer!]                     ;-- returns a 16-bit value
		]
	]
]


; #define KEYEVENTF_EXTENDEDKEY:		0001h
; #define KEYEVENTF_KEYUP:			0002h

; #define MOUSEEVENTF_ABSOLUTE:		8000h
; #define MOUSEEVENTF_LEFTDOWN:		0002h
; #define MOUSEEVENTF_LEFTUP:			0004h
; #define MOUSEEVENTF_MIDDLEDOWN:		0020h
; #define MOUSEEVENTF_MIDDLEUP:		0040h
; #define MOUSEEVENTF_MOVE:			0001h
; #define MOUSEEVENTF_RIGHTDOWN:		0008h
; #define MOUSEEVENTF_RIGHTUP:		0010h
; #define MOUSEEVENTF_XDOWN:			0080h
; #define MOUSEEVENTF_XUP:			0100h
; #define MOUSEEVENTF_WHEEL:			0800h
; #define MOUSEEVENTF_HWHEEL:			1000h
; #define XBUTTON1:					0001h
; #define XBUTTON2:					0002h


