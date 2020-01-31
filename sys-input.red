Red [
	title:   "input simulation routines"
	author:  @hiiamboris
	license: 'BSD-3
]

keybd_event*: routine [vk [integer!] scan [integer!] flags [integer!] "keyeventf_* mask"] [
	keybd_event as byte! vk as byte! scan flags null
]

mouse_event*: routine [x [integer!] y [integer!] flags [integer!] "mouseeventf_* mask" data [integer!]] [
	mouse_event flags x y data null
]

vkkeyscan*: routine [ch [integer!] return: [integer!]] [
	vkkeyscan ch
]

mapvirtualkey*: routine [code [integer!] type [integer!] return: [integer!]] [
	mapvirtualkey code type
]

getasynckeystate*: routine [vk [integer!] return: [integer!]] [
	getasynckeystate vk
]

