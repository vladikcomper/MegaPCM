
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Naming convetions:
;
; - `SomeLabel_EXX` - routine expects alternative regiters
;	(`exx` must be executed before calling or jumping to it!)
; - `SomeLabel_DI` - routine expects interrupts to be disabled
;	(`di` must be executed before calling or jumping to it!)
; - `SomeLabel_NR` - routine is a NO RETURN
;	(it fully resets stack and currently running loop)
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
	export	LoopId
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
	export	LOOP_IDLE
	export	LOOP_PAUSE
	export	LOOP_PCM
	export	LOOP_PCM_TURBO
	export	LOOP_DPCM
	export	LOOP_CALIBRATION
	export	TYPE_NONE
	export	TYPE_PCM
	export	TYPE_PCM_TURBO
	export	TYPE_DPCM
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
	include	'loop-calibration.asm'
	include	'loop-idle.asm'

; --------------------------------------------------------------
; Mega PCM buffers and tables (aligned on 256-byte boundaries)
; --------------------------------------------------------------

	align	100h

; --------------------------------
; 256-byte playback ring buffer
; --------------------------------

SampleBuffer:
	ds	100h, 0

	; Playback loops use high byte of `SampleBuffer` offset
	; for an insane optimization, so it should be 03h
	assert	(SampleBuffer>>8) == 3

; -----------------
; Volume tables
; -----------------

VolumeTables:
	include	'volume-tables.asm'

; -----------------
; Sample table
; -----------------

SampleInput:
	ds	sSampleInput, 0		; special dynamic sample slot (sample 80h)

SampleTable:				; slots >=81h
	; This table must be appended by the driver loader.
	ds	sSampleInput*7Fh, 0
SampleTable_End:

	; Sample table's base offset (including the dynamic sample) must be
	; a multiple of 4000h for an insane optimization
	assert	((SampleInput>>8) % 4) == 0

; -------------------------
; DPCM decode tables
; -------------------------

DPCMTables:
	ds	100h, 0	; for nibble 0
	ds	100h, 0	; for nibble 1

; --------------------------------------------------------------
; Cycle waster (aligned on 256-byte boundary)
; --------------------------------------------------------------

	align	100h

	include	'waste-cycles.asm'

; --------------------------------------------------------------
; Mega PCM loops (Part 2)
; --------------------------------------------------------------

	include	'loop-dpcm.asm'
	include	'load-dpcm-table.asm'
	include	'loop-dpcm-turbo.asm'
	include	'loop-pause.asm'

; --------------------------------------------------------------
; Misc. modules
; --------------------------------------------------------------

	include	'init.asm'
	include	'play-sample.asm'
	include 'process-command.asm'

Driver_End:

; --------------------------------------------------------------
; Dumping the data ...
; --------------------------------------------------------------

	; Dumps final assembled code to the OUTPATH
	savebin	OUTPATH, Driver_Start, Driver_End

	; Dumps trace data to TRACEPATH
	TraceDataSave TRACEPATH
