
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; (c) 2023, Vladikcomper
; --------------------------------------------------------------

	include	'vars.asm'
	include	'macros.asm'

; --------------------------------------------------------------

	device	NOSLOT64K

	org	00h

Driver_Start:
	include	'init.asm'

; --------------------------------------------------------------
	org	38h
VBlank:
	jp	VoidInterrupt

VBlankRoutine:	equ	VBlank+1

; --------------------------------------------------------------
VoidInterrupt:
	ifdef __DEBUG__
		reti	; ###
	else
		reti
	endif

; --------------------------------------------------------------

	include	'playback-pitched.asm'

; --------------------------------------------------------------
	ifdef __DEBUG__
		include	"debug.asm"
	endif

; --------------------------------------------------------------

	include	'load-bank.asm'

	include	'loop-idle.asm'
	include	'loop-pcm.asm'

; --------------------------------------------------------------
	align	100h
SampleBuffer:
	ds	100h, 0

; --------------------------------------------------------------
SampleTable:
	dw	0,0,0,0,0		; sample 80h is dynamic
	; Rest of the table goes here ...

Driver_End:

; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End
