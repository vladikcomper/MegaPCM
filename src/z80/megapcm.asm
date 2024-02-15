
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

	include	'vars.asm'
	include	'trace.asm'		; trace support for Z80VM

; --------------------------------------------------------------

	device	NOSLOT64K

; --------------------------------------------------------------
; Exported symbols and equates
; --------------------------------------------------------------

	; Exported RAM variables
	export	DriverReady
	export	CommandInput
	export	VolumeInput
	export	SFXVolumeInput
	export	PanInput
	export	SFXPanInput
	export	ActiveSamplePitch
	export	VBlankActive
	export	CalibrationApplied
	export	CalibrationScore_ROM
	export	CalibrationScore_RAM
	export	LastErrorCode

	; Exported program locations
	export	SampleTable

	; Exported constants
	export	COMMAND_STOP
	export	COMMAND_PAUSE
	export	ERROR__BAD_INTERRUPT
	export	ERROR__BAD_SAMPLE_TYPE
	export	ERROR__UNKNOWN_COMMAND

; --------------------------------------------------------------
; Driver's entry points
; --------------------------------------------------------------

	org	00h
Driver_Start:
	di				; disable interrupts
	im	1			; interrupt mode 1
	jp	InitDriver

; --------------------------------------------------------------
; Bank-switch routines
; --------------------------------------------------------------
; NOTE: The must be stored at offset 08h to make use of RST
; instruction for fast calls.
; --------------------------------------------------------------

	org	08h
	include	'set-bank.asm'		; bank-switching routines

; --------------------------------------------------------------
; Driver version magic string
; --------------------------------------------------------------

	db	'MegaPCM v.2.0', 0

; --------------------------------------------------------------
; Vertical interrupts handler with dynamic jump
; --------------------------------------------------------------

	org	38h
VBlank:
	jp	VoidInterrupt	; NOTE: self-modifying code

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
; Playback functions (macros only)
; --------------------------------------------------------------

	include	'playback.asm'
	include	'playback-turbo.asm'

; --------------------------------------------------------------
; Mega PCM loops (Part 1)
; --------------------------------------------------------------

	include	'loop-pcm.asm'
	include	'loop-pcm-turbo.asm'

; --------------------------------------------------------------
; 256-byte sample buffer used for playback
; --------------------------------------------------------------

	align	100h

SampleBuffer:
	ds	100h, 0

	; Playback loops use high byte of `SampleBuffer` offset
	; for an insane optimization, so it should be 03h
	assert	(SampleBuffer>>8) == 3

; --------------------------------------------------------------
; Lookup tables (aligned on 256-byte boundary)
; --------------------------------------------------------------

	align	100h

VolumeTables:
	include	'volume-tables.asm'

DPCMTables:
	include	'dpcm-tables.asm'


; --------------------------------------------------------------
; Cycle waster (aligned on 256-byte boundary)
; --------------------------------------------------------------

	align	100h

	include	'waste-cycles.asm'

; --------------------------------------------------------------
; Mega PCM loops (Part 2)
; --------------------------------------------------------------

	include	'loop-dpcm.asm'
	include	'loop-calibration.asm'
	include	'loop-pause.asm'
	include	'loop-idle.asm'

; --------------------------------------------------------------
; Misc. modules
; --------------------------------------------------------------

	include	'init.asm'
	include	'play-sample.asm'

; --------------------------------------------------------------
; Sample table for sample ids >=81h
; --------------------------------------------------------------
; NOTE: Sample id 80h is considered "custom" and is read
; from Work RAM instead (see `SampleInput` in `vars.asm`).
;
; This basically allows to bypass limitations of sample table
; and generate pitches, start/end positions on the fly.
; --------------------------------------------------------------

SampleTable:
	; This table must be appended by the driver loader.

Driver_End:

; --------------------------------------------------------------
; Dumping the data ...
; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End

	; Dumps trace data to TRACEPATH
	TraceDataSave TRACEPATH
