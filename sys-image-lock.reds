Red/System [
	title:   "fast image locking used by edge detection and colorset enumeration"
	author:  @hiiamboris
	license: 'BSD-3
]

#define zero32 [as float32! 0.0]

image-data!: alias struct! [
	img			[red-image!]			;-- should be set before a call to image-lock
	bitmap		[integer!]				;-- set by image-lock (only used in release-call)
	width		[integer!]				;-- set by image-lock
	height		[integer!]				;-- set by image-lock
	data		[byte-ptr!]				;-- set by image-lock (array of 32-bit integers ARGB) (stride is 32-bit alignment only)
	h-contrasts	[float32-ptr!]			;-- used by edge detector
	v-contrasts	[float32-ptr!]			;-- used by edge detector
]

image-lock: func [imdt [image-data!]][
	imdt/data: as byte-ptr! image/acquire-buffer imdt/img :imdt/bitmap
	imdt/width:  OS-image/width?  imdt/img/node
	imdt/height: OS-image/height? imdt/img/node
]

image-release: func [imdt [image-data!]][
	image/release-buffer imdt/img imdt/bitmap false
]
