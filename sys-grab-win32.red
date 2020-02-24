Red [
	title:   "win32 screen grabbing"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [
	#import [
		"user32.dll" stdcall [
			GetDC: "GetDC" [
				hWnd		[handle!]
				return:		[handle!]
			]
			ReleaseDC: "ReleaseDC" [
				hWnd		[handle!]
				hDC			[handle!]
				return:		[integer!]
			]
			GetSystemMetrics: "GetSystemMetrics" [
				index		[integer!]
				return:		[integer!]
			]
		]
		"gdi32.dll" stdcall [
			BitBlt: "BitBlt" [
				hdcDest		[handle!]
				nXDest		[integer!]
				nYDest		[integer!]
				nWidth		[integer!]
				nHeight		[integer!]
				hdcSrc		[handle!]
				nXSrc		[integer!]
				nYSrc		[integer!]
				dwRop		[integer!]
				return:		[integer!]
			]
		]
		"gdiplus.dll" stdcall [
			GdipGetDC: "GdipGetDC" [
				graphics	[integer!]
				hdc			[int-ptr!]
				return:		[integer!]
			]
			GdipReleaseDC: "GdipReleaseDC" [
				graphics	[integer!]
				hdc			[integer!]
				return:		[integer!]
			]
			GdipGetImageGraphicsContext: "GdipGetImageGraphicsContext" [
				image		[integer!]
				graphics	[int-ptr!]
				return:		[integer!]
			]
			GdipCreateBitmapFromScan0: "GdipCreateBitmapFromScan0" [
				width		[integer!]
				height		[integer!]
				stride		[integer!]
				format		[integer!]
				scan0		[byte-ptr!]
				bitmap		[int-ptr!]
				return:		[integer!]
			]
		]
	]
]

;@@ TODO: get rid of this and use `to-image` once images become garbage-collected?
;@@ for now, it's both memory efficient and able to grab only a portion of the screen

grab-screenshot*: routine [
	into	[any-type!]			;-- `image!` or `none!` -- since GC doesn't collect images, makes sense to reuse them
	offset	[any-type!]			;-- `pair!` or `none!`
	size	[any-type!]			;-- `pair!` or `none!`
	return: [image!]
	/local
		w [integer!] h [integer!] x [integer!] y [integer!]
		scrdc [handle!] gpdc [integer!]
		gfx [integer!] gpimg [integer!]
		img [red-image!] p [red-pair!] inode [img-node!]
		new? [logic!]
][
	x: 0 y: 0
	if TYPE_OF(offset) = TYPE_PAIR [
		p: as red-pair! offset
		x: p/x y: p/y
	]

	w: GetSystemMetrics 0		;-- SM_CXSCREEN
	h: GetSystemMetrics 1		;-- SM_CYSCREEN
	either TYPE_OF(size) = TYPE_PAIR [
		p: as red-pair! size
		w: p/x  h: p/y
	][
		w: w - x  h: h - y
	]

	scrdc: GetDC null

	new?: TYPE_OF(into) <> TYPE_IMAGE
	either new? [
		gpimg: 0
		GdipCreateBitmapFromScan0 w h 0 PixelFormat32bppARGB null :gpimg
		img: image/init-image  as red-image! stack/push*  OS-image/make-node as node! gpimg
	][
		img: as red-image! into
		inode: as img-node! (as series! img/node/value) + 1
		gpimg: inode/handle
	]

	gfx: 0
	GdipGetImageGraphicsContext gpimg :gfx

	gpdc: 0
	GdipGetDC gfx :gpdc
	BitBlt as handle! gpdc 0 0 w h scrdc x y 40CC0020h	;-- CAPTUREBLT | SRCCOPY -- former for layered windows capture!
	GdipReleaseDC gfx gpdc
	ReleaseDC null scrdc

	as red-image! stack/set-last as cell! img
]

