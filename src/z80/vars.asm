
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Variables, structures and constants definitions
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; ------------------------
; Structures
; ------------------------


	struct	sSampleInput
flags:		byte			; playback flags
pitch:		byte			; pitch of the sample
startBank:	byte			; start bank id
endBank:	byte			; end bank id
startOffset:	word			; offset in the start bank
endOffset:	word			; offset in the end bank
	ends

	struct	sActiveSample
volumeInputPtr:	word			; volume input source (`VolumeInput` or `SFXVolumeInput`)
startBank:	byte			; start bank id
endBank:	byte			; end bank id (NOTE: corrected)
startLength:	word			; length in start bank
endLength:	word			; length in end bank (used if bankswitching to the end bank)
startOffset:	word			; start bank offset (corrected)
flags:		byte			; playback flags
pitch:		byte			; pitch of the sample
	ends

; WARNING! Don't change location of priority or type bits!
MASK_PRIORITY:	equ	%11110000	; applied to mask priority bits only
MASK_TYPE:	equ	%00001110	; applied to mask type bits only

TYPE_NONE:		equ	0
TYPE_PCM:		equ	2
TYPE_PCM_TURBO:		equ	4
TYPE_DPCM_TBL0:		equ	6	; classic DPCM / DPCM-HQ table #0
TYPE_DPCM_TBL0_TURBO:	equ	8
TYPE_DPCM_TBL1:		equ	0Ah	; DPCM-HQ table #1
TYPE_DPCM_TBL1_TURBO:	equ	0Ch

PRIORITY_0:	equ	0
PRIORITY_1:	equ	10h
PRIORITY_2:	equ	20h
PRIORITY_3:	equ	40h

FLAGS_LOOP:	equ	0		; if set, sample loops indefinitely
FLAGS_TYPE_0:	equ	1		; bit 0 of sample type
FLAGS_TYPE_1:	equ	2		; bit 1 of sample type
FLAGS_TYPE_2:	equ	3		; bit 2 of sample type
FLAGS_PRIO_0:	equ	4		; bit 0 of priority level
FLAGS_PRIO_1:	equ	5		; bit 1 of priority level
FLAGS_SFX:	equ	6		; bit 2 of priority, also indicates SFX samples
FLAGS_SAMPLE:	equ	7		; bit 3 of priority, also indicates this slot is a playable sample (not metadata/reserved)

; ---------------------------------------------
; Variables baked into self-modifying code
; ---------------------------------------------


; NOTE: This variable is a part of self-modifying instruction in `SetBank:`
CurrentBank:	equ	SetBank.sm1+1		; currently loaded bank

; NOTE: This variable is a part of self-modifying instruction in `ProcessCommandInput:`
CommandInput:	equ	ProcessCommandInput.sm1+1; command input byte (written by the M68K):
						; - 00h - nothing
COMMAND_STOP:	equ	01h			; - 01h - STOP playback
COMMAND_PAUSE:	equ	02h			; - 02h - PAUSE playback
						; - 03..7Fh - ignored
						; - 80..FFh - play sample record from `SampleInput`

; ------------------------
; Main RAM variables
; ------------------------

Stack:			equ	1FC0h		; start of the stack
WorkRAM:		equ	1FC0h		; driver's working memory

		phase	WorkRAM
StackFailsafe:		dw	1		; set to 0000h, failsafe return value in unlikely case of stack corruption
DriverReady:		ds	1		; flag to indicate that the driver is ready for operation
						; - 'R' (52h) - set when `InitDriver` finishes
						; - 00h or anything else - still initializing
VolumeInput:		ds	1		; normal samples volume (00h = max, 0Fh = min)
SFXVolumeInput:		ds	1		; SFX samples volume (00h = max, 0Fh = min)
PanInput:		ds	1		; panning of normal samples (40h, 80h or C0h)
SFXPanInput:		ds	1		; panning of SFX samples (40h, 80h or C0h)

		; `VolumeInput` and `SFXVolumeInput` should be within the same 256-byte block
		; for some optimizations to work
		assert (VolumeInput>>8)==(SFXVolumeInput>>8)
		assert (VolumeInput+1)==(SFXVolumeInput)

ActiveSample:		ds	sActiveSample	; currently playing sample data
ActiveSamplePitch:	equ	ActiveSample+sActiveSample.pitch	; pointer to the pitch of active sample

LoopId:			ds	1		; id of the current loop
LOOP_IDLE:		equ	01h		; - `IdleLoop` (see `loop-idle.asm`)
LOOP_PAUSE:		equ	02h		; - `PauseLoop` (see `loop-pause.asm`)
LOOP_PCM:		equ	10h		; - `PCMLoop` (see `loop-pcm.asm`)
LOOP_PCM_TURBO:		equ	18h		; - `PCMTurboLoop (see `loop-pcm-turbo.asm`)
LOOP_DPCM:		equ	20h		; - `DPCMLoop` (see `loop-dpcm.asm`)
LOOP_DPCM_TURBO:	equ	28h		; - `DPCMTurboLoop` (see `loop-dpcm-turbo.asm`)
LOOP_DPCM_HQ:		equ	30h		; - `DPCMHQLoop` (see `loop-dpcm.asm`)
LOOP_DPCM_HQ_TURBO:	equ	38h		; - `DPCMHQTurboLoop` (see `loop-dpcm-turbo.asm`)
LOOP_CALIBRATION:	equ	80h		; - `CalibrationLoop` (see `loop-calibration.asm`)
LoopIdCopy:		ds	1		; id of previously active loop (saved by `PauseLoop` for instance)

StackCopy:		dw	1		; stores a copy of stack pointer
VBlankRoutineCopy:	dw	1		; stores previous VBlank routine for nested loops

VBlankActive:		ds	1		; set if inside VBlank
CalibrationApplied:	ds	1		; set if callibration is applied for crappy emulators
CalibrationScore_ROM:	dw	1		; ROM read count per frame reported by calibration loop
CalibrationScore_RAM:	dw	1		; RAM read count per frame reported by calibration loop

LastErrorCode:		ds	1	; last error code
ERROR__BAD_INTERRUPT:	equ	02h
ERROR__BAD_SAMPLE_TYPE:	equ	01h
ERROR__UNKNOWN_COMMAND:	equ	80h

			align	2
WorkRAM_End:		equ	$
	
		assert	WorkRAM_End <= 2000h			; WorkRAM should overflow past Z80 RAM
		assert	(WorkRAM>>8)==((WorkRAM_End-1)>>8)	; WorkRAM shouldn't cross 256-byte boundary for some optimizations to work

		dephase

; ------------------------
; I/O Ports
; ------------------------

YM_Port0_Reg:		equ	4000h
YM_Port0_Data:		equ	4001h
YM_Port1_Reg:		equ	4002h
YM_Port1_Data:		equ	4003h

BankRegister:		equ	6000h

ROMWindow:		equ	8000h
