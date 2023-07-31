
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

	org	28h

	include	'update-dac.asm'

	include	'loop-buffer-test.asm'

; --------------------------------------------------------------
	align	100h
SampleBuffer:
	incbin 'sample.bin'

Driver_End:

; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End
