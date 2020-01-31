Red [
	title:   "user input simulation mezzanines"
	author:  @hiiamboris
	license: 'BSD-3
]


; TODO: recording (https://www.codeproject.com/Articles/19522/Recording-mouse-and-keyboard-events-and-playing-th)
#include %keycodes.red

simulator: context [

	WHEEL_DELTA:				120

	KEYEVENTF_EXTENDEDKEY:		0001h
	KEYEVENTF_KEYUP:			0002h

	MOUSEEVENTF_ABSOLUTE:		8000h
	MOUSEEVENTF_LEFTDOWN:		0002h
	MOUSEEVENTF_LEFTUP:			0004h
	MOUSEEVENTF_MIDDLEDOWN:		0020h
	MOUSEEVENTF_MIDDLEUP:		0040h
	MOUSEEVENTF_MOVE:			0001h
	MOUSEEVENTF_RIGHTDOWN:		0008h
	MOUSEEVENTF_RIGHTUP:		0010h
	MOUSEEVENTF_XDOWN:			0080h
	MOUSEEVENTF_XUP:			0100h
	MOUSEEVENTF_WHEEL:			0800h
	MOUSEEVENTF_HWHEEL:			1000h
	XBUTTON1:					0001h
	XBUTTON2:					0002h

	MAPVK_VK_TO_VSC:    0 ; uCode is a virtual-key code and is translated into a scan code. If it is a virtual-key code that does not distinguish between left- and right-hand keys, the left-hand scan code is returned. If there is no translation, the function returns 0.
	MAPVK_VSC_TO_VK:    1 ; uCode is a scan code and is translated into a virtual-key code that does not distinguish between left- and right-hand keys. If there is no translation, the function returns 0.
	MAPVK_VK_TO_CHAR:   2 ; uCode is a virtual-key code and is translated into an unshifted character value in the low-order word of the return value. Dead keys (diacritics) are indicated by setting the top bit of the return value. If there is no translation, the function returns 0.
	MAPVK_VSC_TO_VK_EX: 3

	vk-to-char: func [vk [integer!]] [mapvirtualkey* vk MAPVK_VK_TO_CHAR]	;-- returns 0 if not translatable
	vk-to-scan: func [vk [integer!]] [mapvirtualkey* vk MAPVK_VK_TO_VSC]
	scan-to-vk: func [sc [integer!]] [mapvirtualkey* sc MAPVK_VSC_TO_VK_EX]
	char-to-vk: func [ch [char! integer!] /only "just vkey" /local vk modz] [
		ch: to integer! ch
		vk: vkkeyscan* ch		;-- FFFFh if no translation; 100h = shift, 200h = ctrl, 400h = alt
		modz: clear []
		case [
			FFFFh = vk [return none]
			only       [return vk and FFh]
			vk and 100h > 0 [append modz 'shift]
			vk and 200h > 0 [append modz 'ctrl]
			vk and 400h > 0 [append modz 'alt]
		]
		object [vkey: vk and FFh  mods: copy modz]
	]

	word-to-vk: func [w [word!]] [
		w: switch/default w [
			shift			[VK_LSHIFT]
			ctrl control	[VK_LCONTROL]
			alt menu		[VK_LMENU]
			enter return	[VK_RETURN]
			;@@ need more?
		][w]
		assert [find/match form w "VK_"  'w]
		get w
	]
	
	sim-vkey-event: function [vk [integer!] down? [logic!]] [	;@@ TODO: extended keys?
		flags: either down? [0][KEYEVENTF_KEYUP]
		keybd_event* vk vk-to-scan vk flags
	]

	sim-char-event: function [ch [char!] down? [logic!]] [
		sim-vkey-event char-to-vk/only ch down?	;@@ TODO: check for validity of vk
	]

	sim-mouse-move: function [xy [pair!]] [
		scr: system/view/screens/1/size
		x: to integer! round 0.5 + xy/x / scr/x * 65535
		y: to integer! round 0.5 + xy/y / scr/y * 65535
		mouse_event* x y MOUSEEVENTF_MOVE + MOUSEEVENTF_ABSOLUTE 0
	]

	sim-mouse-button: function [btn [word!] down? [logic!]] [
		data: 0
		flags: switch btn [
			lmb mb1 left   [               either down? [MOUSEEVENTF_LEFTDOWN]  [MOUSEEVENTF_LEFTUP]]
			rmb mb2 right  [               either down? [MOUSEEVENTF_RIGHTDOWN] [MOUSEEVENTF_RIGHTUP]]
			mmb mb3 middle [               either down? [MOUSEEVENTF_MIDDLEDOWN][MOUSEEVENTF_MIDDLEUP]]
			xmb1 mb4 aux-1 [data: XBUTTON1 either down? [MOUSEEVENTF_XDOWN]     [MOUSEEVENTF_XUP]]
			xmb2 mb5 aux-2 [data: XBUTTON2 either down? [MOUSEEVENTF_XDOWN]     [MOUSEEVENTF_XUP]]
		]
		mouse_event* 0 0 flags data
	]

	sim-mouse-wheel: function [down? [logic!]] [
		mouse_event* 0 0 MOUSEEVENTF_WHEEL WHEEL_DELTA * pick [-1 1] down?
	]

]



{ lower-level DSL:
	keyboard input:
		+/- char! - printables
		+/- VK_key - any key (TBD: short aliases for VK_ crap)
			^ should be specific keys (left/right), not just "shift"
	mouse input:
		pair! - pointer coordinate (in units - that is, up to system/view/screens/1/size)
		+/- LMB/MB1 - left button
		+/- RMB/MB2 - right button
		+/- MMB/MB3 - middle button
		+/- AUX-1/XMB-1/MB4 - button 4
		+/- AUX-2/XMB-2/MB5 - button 5
		more buttons
	touch input (TBD):
		zoom-in
		zoom-out
		pan-(direction)
		etc
}

simulate-input-raw: function [input [block!] /local state subj xy] [
	move: func [xy][simulator/sim-mouse-move xy]
	sim: func [subj state][
		down?: '+ = state
		case [
			find [lmb rmb mmb xmb1 aux-1 xmb2 aux-2 mb1 mb2 mb3 mb4 mb5] subj
				[simulator/sim-mouse-button subj down?]
			'wheel = subj [simulator/sim-mouse-wheel not down?]
			word? subj [simulator/sim-vkey-event simulator/word-to-vk subj down?]
			char? subj [simulator/sim-char-event subj down?]
			'else [? subj ? state do make error! "TODO"]
		]
	]
	unless parse input [any [
		set state ['+ | '-] set subj [char! | word!] (sim subj state)
	|	set xy pair! (move xy)
	]] [? input do make error! "TODO 2"]
]


{ higher level DSL:
	key combos:
		ctrl+ stuff
		alt+ stuff
		shift+ stuff
		ends with char! or VK
		and multiple at once: push mod keys and then normal key, release normal key and mod keys
		TBD: parse rules
	mouse - single buttons:
		LMB/MB1
		RMB/MB2
		more?
	touch input: same as for input-raw
}

; ;@@ TODO: need this?
; simulate-input: func [input [block!]] [
; ]

