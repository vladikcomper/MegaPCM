
; ------------------------
; Structures
; ------------------------

	struct Sample
pitch:		byte			; pitch of the sample
bank:		byte			; start bank id
offset:		word			; start offset in bank
flags:		byte			; playback flags
	ends


; ------------------------
; Z80 RAM
; ------------------------

CommandByte:	equ	1FE0h

Stack:		equ	2000h

; ------------------------
; I/O Ports
; ------------------------

YM_Port0_Ctrl:	equ	4000h
YM_Port0_Data:	equ	4001h
YM_Port1_Ctrl:	equ	4002h
YM_Port1_Data:	equ	4003h

BankRegister:	equ	6000h

ROMWindow:	equ	8000h
