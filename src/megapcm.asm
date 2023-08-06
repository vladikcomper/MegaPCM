
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; (c) 2023, Vladikcomper
; --------------------------------------------------------------

	define	__DEBUG__	; ###

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
	ifdef __DEBUG__
		include	"debug.asm"
	endif

; --------------------------------------------------------------

	include	'load-bank.asm'

	include	'loop-idle.asm'
	include	'loop-pcm.asm'

; --------------------------------------------------------------
SampleTable:
	db	0,0,0,0,0		; sample 80h is dynamic
	; Rest of the table goes here ...

	align	100h
SampleBuffer:
	incbin 'sample.bin'

Driver_End:

; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End
