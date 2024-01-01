
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; (c) 2023, Vladikcomper
; --------------------------------------------------------------

	include	'vars.asm'
	include	'trace.asm'		; trace support for Z80VM

; --------------------------------------------------------------

	device	NOSLOT64K

; --------------------------------------------------------------
	org	00h
Driver_Start:
	di				; disable interrupts
	im	1			; interrupt mode 1
	jp	InitDriver

; --------------------------------------------------------------
	org	08h
	include	'set-bank.asm'		; bank-switching routines

; --------------------------------------------------------------

	; Driver version magic string
	db	'MegaPCM v.2.0f', 0

; --------------------------------------------------------------
	org	38h
VBlank:
	jp	VoidInterrupt

VBlankRoutine:	equ	VBlank+1

; --------------------------------------------------------------
VoidInterrupt:
	TraceException	"Invalid interrupt"

	push	af
	ld	a, ERROR__BAD_INTERRUPT
	ld	(LastErrorCode), a
	pop	af
	ret

; --------------------------------------------------------------

	include	'init.asm'

; --------------------------------------------------------------

	include	'playback.asm'
	include	'playback-turbo.asm'

; --------------------------------------------------------------

	include	'loop-idle.asm'
	include	'loop-pcm.asm'
	include	'loop-pcm-turbo.asm'

; --------------------------------------------------------------
	align	100h
SampleBuffer:
	ds	100h, 0

	; `PCMTurboLoop` the high byte of `SampleBuffer` offset for insane optimization,
	; so it should be between 02h and 08h
	assert	((SampleBuffer>>8) > 2) && ((SampleBuffer>>8) < 8)

; --------------------------------------------------------------

	include	'loop-dpcm.asm'
	include	'loop-calibration.asm'
	include	'play-sample.asm'

; --------------------------------------------------------------
	align	100h

VolumeTables:
	include	'volume-tables.asm'

DPCMTables:
	include	'dpcm-tables.asm'

; --------------------------------------------------------------
SampleTable:
	; samples from 81h onwards go here

Driver_End:

; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End

	; Dumps trace data to 
	TraceDataSave TRACEPATH
