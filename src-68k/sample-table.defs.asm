; ---------------------------------------------------------------

FLAGS_SFX:	equ	$01
FLAGS_LOOP:	equ	$02

TYPE_NONE:	equ	$00
TYPE_PCM:	equ	'P'
TYPE_PCM_TURBO:	equ	'T'
TYPE_DPCM:	equ	'D'

; ---------------------------------------------------------------
; Maximum playback rates:
TYPE_PCM_TURBO_MAX_RATE:	equ	32000 ; Hz
TYPE_DPCM_MAX_RATE:		equ	18643 ; Hz
TYPE_PCM_MAX_RATE:		equ	25100 ; Hz

; Internal driver's base rates for pitched playback.
; NOTICE: They are slightly lower than max rates,
; because the higest pitch is 256/256, not 256/256.
TYPE_DPCM_BASE_RATE:		equ	18550 ; Hz
TYPE_PCM_BASE_RATE:		equ	25208 ; Hz

; ---------------------------------------------------------------
dcSample: macro	type, samplePtr, sampleRate, flags
	dc.b	\type					; $00	- type

	if \type=TYPE_PCM
		if \sampleRate>25100
			inform 0, "Invalid sample rate. TYPE_PCM only supports sample rates <= 25100 Hz"
		endif
		dc.b	\flags+0				; $01	- flags (optional)
		dc.b	(\sampleRate+0)*256/25208		; $02	- pitch (optional)
		dc.b	0					; $03	- <RESERVED>
		dc.l	\samplePtr				; $04	- start offset
		dc.l	\samplePtr\_End				; $08	- end offset

	elseif \type=TYPE_PCM_TURBO
		if \sampleRate<>32000
			inform 0, "Invalid sample rate. TYPE_PCM_TURBO only supports sample rate of 32000 Hz"
		endif
		dc.b	\flags+0				; $01	- flags (optional)
		dc.b	$FF					; $02	- pitch (optional)
		dc.b	0					; $03	- <RESERVED>
		dc.l	\samplePtr				; $04	- start offset
		dc.l	\samplePtr\_End				; $08	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRate>18550
			inform 0, "Invalid sample rate. TYPE_DPCM only supports sample rates <= 18550 Hz"
		endif
		dc.b	\flags+0				; $01	- flags (optional)
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
