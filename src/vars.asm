
; ------------------------
; Structures
; ------------------------


	struct sSample
type:		byte			; sample type (only 'P' is supported)
startBank:	byte			; start bank id
startOffset:	word			; start offset in bank
endBank:	byte			; end bank id
endLen:		word			; length in the final bank - 1
pitch:		byte			; pitch of the sample
flags:		byte			; playback flags
__reserved:	byte			; <<RESERVED>>
	ends

FLAGS_PRIORITY:	equ	0
FLAGS_LOOP:	equ	1
FLAGS_PANR:	equ	6
FLAGS_PANL:	equ	7


; ------------------------
; Z80 RAM
; ------------------------

WorkRAM:		equ	1FC0h	; driver's working memory
Stack_Boundary:		equ	1FE0h	; stack boundary
Stack:			equ	2000h	; start of the stack

	phase	WorkRAM
CommandInput:	ds	1		; command input byte (written by the main CPU):
					; - 00h - nothing
COMMAND_STOP:	equ	01h		; - 01h - STOP playback
COMMAND_PAUSE:	equ	02h		; - 02h - PAUSE playback
					; - 03..7Fh - ignored
					; - 80..FFh - play sample record from `SampleInput`
DriverReady:	ds	1		; flag to indicate that the driver is ready for operation
					; - 'R' (52h) - set when `InitDriver` finishes
					; - 00h or anything else - still initializing
VolumeInput:	ds	1		; volume (00h = max, 0Fh = min)

SampleInput:	ds	sSample		; input sample data
ActiveSample:	ds	sSample		; currently playing sample data

CurrentBank:	ds	1		; determines the currently active bank

LoopId:		ds	1		; id of the current loop
LOOP_IDLE:	equ	01h		; - `IdleLoop` (see `loop-idle.asm`)
LOOP_PCM:	equ	02h		; - `PCMLoop` (see `loop-pcm.asm`)
LOOP_PCM_TURBO:	equ	03h		; - `PCMTurboLoop (see `loop-pcm-turbo.asm`)

; WARNING! Unused!
BufferHealth:	ds	1		; playback buffer health (number of samples it can play without ROM access)
					; (00h - buffer is drained .. 0FFh - maximum health)

	ifdef __DEBUG__
Debug_ErrorCode:	ds	1	; last error code
ERROR__BAD_SAMPLE_TYPE:	equ	01h
ERROR__BAD_INTERRUPT:	equ	02h
ERROR__NOT_SUPPORTED:	equ	80h
	endif

	align	2
	assert	$ <= Stack_Boundary

WorkRAM_End:		equ	$

	dephase

; ------------------------
; I/O Ports
; ------------------------

YM_Port0_Reg:	equ	4000h
YM_Port0_Data:	equ	4001h
YM_Port1_Reg:	equ	4002h
YM_Port1_Data:	equ	4003h

BankRegister:	equ	6000h

	ifdef __DEBUG__
VMConsole:	equ	7000h
	endif

ROMWindow:	equ	8000h
