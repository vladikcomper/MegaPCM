; ---------------------------------------------------------------

FLAGS_SFX:	equ	$01
FLAGS_LOOP:	equ	$02

FLAGS_PANR:	equ	$40
FLAGS_PANL:	equ	$80
FLAGS_PANLR:	equ	$C0

TYPE_NONE:	equ	$00
TYPE_PCM:	equ	'P'
TYPE_PCM_TURBO:	equ	'T'
TYPE_DPCM:	equ	'D'

; ---------------------------------------------------------------
dcSample: macro	type, samplePtr, sampleRate, flags
	dc.b	\type					; $00	- type

	if \type=TYPE_PCM
		if \sampleRate>25100
			inform 0, "Invalid sample rate. TYPE_PCM only supports sample rates <= 24500 Hz"
		endif
		dc.b	\flags+0				; $01	- flags
		dc.b	(\sampleRate)*256/25208			; $02	- pitch
		dc.b	0					; $03	- <RESERVED>
		dc.l	\samplePtr				; $04	- start offset
		dc.l	\samplePtr\_End				; $08	- end offset

	elseif \type=TYPE_PCM_TURBO
		if \sampleRate<>32000
			inform 0, "Invalid sample rate. TYPE_PCM_TURBO only supports sample rate of 32000 Hz"
		endif
		dc.b	\flags+0				; $01	- flags
		dc.b	$FF					; $02	- pitch
		dc.b	0					; $03	- <RESERVED>
		dc.l	\samplePtr				; $04	- start offset
		dc.l	\samplePtr\_End				; $08	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRate>18550
			inform 0, "Invalid sample rate. TYPE_DPCM only supports sample rates <= 18250 Hz"
		endif
		dc.b	\flags+0				; $01	- flags
		dc.b	(\sampleRate)*256/18643			; $02	- pitch
		dc.b	0					; $03	- <RESERVED>
		dc.l	\samplePtr				; $04	- start offset
		dc.l	\samplePtr\_End				; $08	- end offset

	elseif \type=TYPE_NONE
		dc.b	0, 0, 0
		dc.l	0, 0

	else
		inform 0, "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE"
	endc
	endm

incdac:	macro name, path
	even
\name:
	incbin	path
\name\_End:
	endm
