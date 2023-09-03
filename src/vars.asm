
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

FLAGS_PRIORITY:	equ	7
FLAGS_LOOP:	equ	6


	ifdef __DEBUG__

	struct sDriverIO
IN_command:		byte		; IN	receives a sample or command from 68k
OUT_ready:		byte		; OUT	flag to indicate that the driver is ready for operation
OUT_dbg_loopId:		byte		; OUT	current loop number (DEBUG only)
OUT_dbg_errorCode:	byte		; OUT	error code set by Mega PCM (DEBUG only)
	ends

LOOP_IDLE:	equ	01h
LOOP_PCM:	equ	02h

ERROR__BAD_SAMPLE_TYPE:	equ	01h
ERROR__NOT_IMPLEMENTED:	equ	80h

	else

	struct sDriverIO
IN_command:		byte		; IN	receives a sample or command from 68k
OUT_ready:		byte		; OUT	flag to indicate that the driver is ready for operation
	ends

	endif


; ------------------------
; Z80 RAM
; ------------------------

WorkRAM:		equ	1FD0h		; driver's working memory
Stack_Boundary:		equ	1FE0h		; stack boundary
Stack:			equ	2000h		; start of the stack

	phase	WorkRAM

DriverIO_RAM:		ds	sDriverIO

CurrentBank:		ds	1

	ifdef __DEBUG__
Debug_BufferPos:	ds	2
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
