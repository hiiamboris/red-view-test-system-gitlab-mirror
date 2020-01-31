Red [
	title:   "UI-related routines"
	author:  @hiiamboris
	license: 'BSD-3
]


get-client-offset: routine [
	"Returns the offset (in pixels) of the 0x0 client area coordinate of the window"
	hwnd [any-type!] "handle! or integer!"	;-- both have /value as 3rd integer (integer is a hack due to handle being unloadable)
	return: [pair!]
	/local p h
][
	assert any [
		TYPE_OF(hwnd) = TYPE_HANDLE
		TYPE_OF(hwnd) = TYPE_INTEGER
	]
	h: as red-handle! hwnd
	p: gui/screen-to-client as handle! h/value 0 0
	as red-pair! stack/set-last as cell! pair/push 0 - p/x 0 - p/y
]

get-window-borders: routine [
	"Returns thickness (in pixels) of Left x Top & Right x Bottom borders (including title bar & menu)"
	hwnd [any-type!] "handle! or integer!"	;-- both have /value as 3rd integer (integer is a hack due to handle being unloadable)
	return: [block!]
	/local han x y w h b [red-block! value]
][
	probe TYPE_OF(hwnd)
	assert any [
		TYPE_OF(hwnd) = TYPE_HANDLE
		TYPE_OF(hwnd) = TYPE_INTEGER
	]
	han: as red-handle! hwnd
	x: 0  y: 0  w: 0  h: 0
	gui/window-border-info? as handle! han/value :x :y :w :h		;-- x & y are negative
	print-wide [x y "^/"]
	assert x <= 0
	assert y <= 0
	block/make-at b 4
	pair/make-in b 0 - x 0 - y
	pair/make-in b w + x h + y
	as red-block! stack/set-last as cell! b
]


