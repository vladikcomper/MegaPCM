
; ===============================================================
; ---------------------------------------------------------------
; Mega PCM v.1.1
; (C) 2012, Vladikcomper
; ---------------------------------------------------------------

	org	0

; ---------------------------------------------------------------
; Constants
; ---------------------------------------------------------------

; Memory variables

Stack:			equ	1FF0h
DAC_Number:		equ	1FFFh			; Number of DAC sample to play ($81-based)
							; There are special numbers to control playback:
							;	$80	- Stop Playback
							;	$7F	- Pause Playback
							;	$00	- Continue Playback

; System ports

YM_Port0_Ctrl:		equ	4000h
YM_Port0_Data:		equ	4001h
YM_Port1_Ctrl:		equ	4002h
YM_Port1_Data:		equ	4003h
BankRegister:		equ	6000h

; Sample struct vars

flags:		equ	0	; playback flags
pitch:		equ	1	; pitch value
s_bank:		equ	2	; start bank
e_bank:		equ	3	; end bank
s_pos:		equ	4	; start offset (in first bank)
e_pos:		equ	6	; end offset (in last bank)


; ===============================================================
; ---------------------------------------------------------------
; Driver initialization code
; ---------------------------------------------------------------

	di				; disable interrupts
	di
	di

	; Setup variables
	ld	sp, Stack		; init SP
	xor	a			; a = 0
	ld	(DAC_Number), a		; reset DAC to play
	ld	h, a
	ld	l, a
	ld	(Ptr_InitPlayback), hl	; reset 'InitPlayback' event
	ld	(Ptr_SoundProc), hl	; reset 'SoundProc' event
	ld	(Ptr_Interrupt), hl	; reset 'Interrupt' event
	ld	(Ptr_EndPlayback), hl	; reset 'PlayOver' event
	ld	iy, YM_Port0_Ctrl

; ---------------------------------------------------------------
; Idle loop, waiting DAC number input
; ---------------------------------------------------------------

Idle_Loop:
	ld	hl, DAC_Number

Idle_WaitDAC:
	ld	a, (hl)			; load DAC number
	or	a			; test it
	jp	p, Idle_WaitDAC		; if it's positive, branch

; ---------------------------------------------------------------
; Load DAC sample according to its number and play it
; ---------------------------------------------------------------

LoadDAC:
	sub	81h			; subtract 81h from DAC number
	jr	c, Idle_WaitDAC		; if a = 80h, branch
	ld	(hl), 0h		; reset DAC number in RAM

	; Load DAC table entry
	ld	ix,DAC_Table		; ix = DAC Table
	ld	h,0h
	ld	l,a			; hl = DAC
	add	hl,hl			; hl = DAC*2
	add	hl,hl			; hl = DAC*4
	add	hl,hl			; hl = DAC*8
	ex	de,hl
	add	ix,de			; ix = DAC_Table + DAC*8

	; Init events table according to playback mode
	ld	a,(ix+flags)		; a = Flags
	and	7h			; mask only Mode
	add	a, a			; a = Mode*2
	add	a, a			; a = Mode*4
	add	a, a			; a = Mode*8
	ld	b, 0h
	ld	c, a			; bc = Mode*8
	ld	hl, Events_List
	add	hl, bc			; hl = Events_List + Mode*8
	ld	de, Ptr_InitPlayback	; de = Events Pointers
	ld	bc, 4FFh		; do 4 times, 'c' should never borrow 'b' on decrement
.ldpointer:
	ldi				; transfer event pointer
	ldi				;
	inc	de			; skip a byte in events table ('jp' opcode)
	djnz	.ldpointer

	jp	Event_InitPlayback	; launch 'InitPlayback' event

; ---------------------------------------------------------------
; Setup YM to playback DAC
; ---------------------------------------------------------------

SetupDAC:
	ld	(iy+0), 2Bh		;
	ld	(iy+1), 80h		; YM => Enable DAC
	ld	a, (ix+flags)		; load flags
	and	0C0h			; are pan bits set?
	jr	z, .nopan		; if not, branch
	ld	(iy+2), 0B6h		;
	ld	(iy+3), a		; YM => Set Pan
.nopan:	ld	(iy+0), 2Ah		; setup YM to fetch DAC bytes
	ret

; ---------------------------------------------------------------

Events_List:
	;	Initplayback,	SoundProc,	Interrupt,	EndPlayback	;
	dw	Init_PCM,	Process_PCM,	Int_Normal,	StopDAC		; Mode 0
	dw	Init_PCM,	Process_PCM,	Int_NoOverride,	StopDAC		; Mode 1
	dw	Init_PCM,	Process_PCM,	Int_Normal,	Reload_PCM	; Mode 2
	dw	Init_PCM,	Process_PCM,	Int_NoOverride,	Reload_PCM	; Mode 3
	dw	Init_DPCM,	Process_DPCM,	Int_Normal,	StopDAC		; Mode 4
	dw	Init_DPCM,	Process_DPCM,	Int_NoOverride,	StopDAC		; Mode 5
	dw	Init_DPCM,	Process_DPCM,	Int_Normal,	Reload_DPCM	; Mode 6
	dw	Init_DPCM,	Process_DPCM,	Int_NoOverride,	Reload_DPCM	; Mode 7

; ===============================================================
; ---------------------------------------------------------------
; Dynamic Events Table, filled from 'Events_List'
; ---------------------------------------------------------------

Event_InitPlayback:
	jp		0h

Event_SoundProc:
	jp		0h
	
Event_Interrupt:
	jp		0h

Event_EndPlayback:
	jp		0h

; ---------------------------------------------------------------

Ptr_InitPlayback:	equ	Event_InitPlayback+1	; Init Playback event pointer
Ptr_SoundProc:		equ	Event_SoundProc+1	; Sound process event pointer
Ptr_Interrupt:		equ	Event_Interrupt+1	; Sound interrupt event pointer
Ptr_EndPlayback:	equ	Event_EndPlayback+1	; End playback event pointer

; ---------------------------------------------------------------

	include	"interrupts.asm"

; ---------------------------------------------------------------

	include	"bankswitch.asm"

; ---------------------------------------------------------------

	include	"play-pcm.asm"

; ---------------------------------------------------------------

	include	"play-dpcm.asm"

; ===============================================================

; Table of DAC samples goes right after the code.
; It remains empty here, you are meant to fill it in your hack's
; disassembly right after including compiled driver.

DAC_Table:
