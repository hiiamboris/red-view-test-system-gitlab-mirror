Red [
	title:   "image color counting facilities"
	author:  @hiiamboris
	license: 'BSD-3
]

#system [

	#include %/d/devel/red/red-view-test/sys-image-lock.reds
	
	rs-get-colorset: func [
		im			[red-image!]
		start		[integer!]				;--  0 for the whole image
		len  		[integer!]				;-- -1 for the whole image
		step 		[integer!]				;--  1 normally
		return: 	[red-block!]
		/local
			imdt [image-data! value]
			ret [red-block!]
			buf [series-buffer!] itail [int-ptr!] ibuf [int-ptr!]
			rbuf [red-integer!] where [red-integer!] other [red-integer!] tuple [red-tuple!]
			found? [logic!]
			blen [integer!] cnt [integer!] clr [integer!] tmp [integer!]
	][
		imdt/img: im
		image-lock imdt
		; bin: image/extract-data im EXTRACT_RGB			;-- <- main time consumer (2/3 of the whole) -- no use
		blen: imdt/width * imdt/height
		if len < 0 [len: blen - start]
		assert all [start >= 0 start <= blen start + len <= blen]
		ret: block/push-only* 64
		ibuf: (as int-ptr! imdt/data) + start
		itail: ibuf + len
		buf: GET_BUFFER(ret)
		rbuf: as red-integer! buf/offset
		cnt: 0
		while [ibuf < itail] [
			clr: ibuf/value and FFFFFFh					;-- ignore alpha
			ibuf: ibuf + step
										;-- find this color in the block
			where: rbuf
			found?: no
			loop cnt [
				if where/value = clr [found?: yes break]
				where: where + 2
			]
			either found? [
				where: where + 1			;-- next cell is count
				where/value: where/value + 1
				other: where - 2
				while [all [other > rbuf  other/value < where/value]] [
					tmp: other/value  other/value: where/value  where/value: tmp		;-- swap counts to keep sorted
					other: other - 1 where: where - 1
					tmp: other/value  other/value: where/value  where/value: tmp		;-- also swap colors
					other: other - 1 where: where - 1						;-- compare with the previous count as well
				]
			][								;-- add this pixel
				integer/make-in ret clr		;-- add color
				integer/make-in ret 1		;-- add count=1
				buf: GET_BUFFER(ret)
				rbuf: as red-integer! buf/offset	;-- refresh the buffer (could've been reallocated)
				cnt: cnt + 1				;-- incr color count
			]
		]
		image-release imdt

		where: rbuf
		loop cnt [		;-- make tuples out of integers
			clr: where/value
			tuple: as red-tuple! where
			tuple/header: TYPE_TUPLE or (3 << 19)
			;; ARGB:   BBGGRRAA (AA being most significant) on little-endian ;@@ TODO: also big-endian ver
			;; array1: RRGGBBAA (AA being most significant)
			tuple/array1: (clr and FFh << 16) or (clr and FF00h) or (clr >> 16 and FFh)		
			; tuple/array1: clr
			; tuple/make-rgba as cell! where  clr >> 16  clr >> 8 and FFh  clr and FFh  -1		this is bugged
			where: where + 2
		]
		as red-block! stack/set-last as cell! ret
	]

]

get-colorset: routine [im [image!] return: [block!]][rs-get-colorset im 0 -1 1]

get-hline-colorset: routine [im [image!] y [integer!] return: [block!] /local w][
	w: im/size and FFFFh
	rs-get-colorset  im  y - 1 * w  w  1
]

get-vline-colorset: routine [im [image!] x [integer!] return: [block!] /local w][
	w: im/size and FFFFh
	rs-get-colorset  im  x - 1  -1  w
]
