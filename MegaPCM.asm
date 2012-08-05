
; ===============================================================
; ---------------------------------------------------------------
; Mega PCM v.1.1
; (C) 2012, Vladikcomper
; ---------------------------------------------------------------

	cpu	z80

; ---------------------------------------------------------------
; Constants
; ---------------------------------------------------------------

; Memory variables

Stack		equ	1FF0h
Ptr_InitPlayback equ	Event_InitPlayback+1	; Init Playback event pointer
Ptr_SoundProc	equ	Event_SoundProc+1	; Sound process event pointer
Ptr_Interrupt	equ	Event_Interrupt+1	; Sound interrupt event pointer
Ptr_EndPlayback	equ	Event_EndPlayback+1	; End playback event pointer
DAC_Number	equ	1FFFh			; Number of DAC sample to play ($81-based)
						; There are special numbers to control playback:
						;	$80	- Stop Playback
						;	$7F	- Pause Playback
						;	$00	- Continue Playback

; System ports

YM_Port0_Ctrl	equ	4000h
YM_Port0_Data	equ	4001h
YM_Port1_Ctrl	equ	4002h
YM_Port1_Data	equ	4003h
BankRegister	equ	6000h

; Sample struct vars

flags	equ	0	; playback flags
pitch	equ	1	; pitch value
s_bank	equ	2	; start bank
e_bank	equ	3	; end bank
s_pos	equ	4	; start offset (in first bank)
e_pos	equ	6	; end offset (in last bank)


; ===============================================================
; ---------------------------------------------------------------
; Driver initialization code
; ---------------------------------------------------------------

	di				; disable interrupts
	di
	di

	; Setup variables
	ld	sp,Stack		; init SP
	xor	a			; a = 0
	ld	(DAC_Number),a		; reset DAC to play
	ld	h,a
	ld	l,a
	ld	(Ptr_InitPlayback),hl	; reset 'InitPlayback' event
	ld	(Ptr_SoundProc),hl	; reset 'SoundProc' event
	ld	(Ptr_Interrupt),hl	; reset 'Interrupt' event
	ld	(Ptr_EndPlayback),hl	; reset 'PlayOver' event
	ld	iy,YM_Port0_Ctrl

; ---------------------------------------------------------------
; Idle loop, waiting DAC number input
; ---------------------------------------------------------------

Idle_Loop:
	ld	hl,DAC_Number

Idle_WaitDAC:
	ld	a,(hl)			; load DAC number
	or	a			; test it
	jp	p,Idle_WaitDAC		; if it's positive, branch

; ---------------------------------------------------------------
; Load DAC sample according to its number and play it
; ---------------------------------------------------------------

LoadDAC:
	sub	81h			; subtract 81h from DAC number
	jr	c,Idle_WaitDAC		; if a = 80h, branch
	ld	(hl),0h			; reset DAC number in RAM

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
	add	a,a			; a = Mode*2
	add	a,a			; a = Mode*4
	add	a,a			; a = Mode*8
	ld	b,0h
	ld	c,a			; bc = Mode*8
	ld	hl,Events_List
	add	hl,bc			; hl = Events_List + Mode*8
	ld	de,Ptr_InitPlayback	; de = Events Pointers
	ld	bc,4FFh			; do 4 times, 'c' should never borrow 'b' on decrement
-	ldi				; transfer event pointer
	ldi				;
	inc	de			; skip a byte in events table ('jp' opcode)
	djnz	-

	jp	Event_InitPlayback	; launch 'InitPlayback' event

; ---------------------------------------------------------------
; Setup YM to playback DAC
; ---------------------------------------------------------------

SetupDAC:
	ld	(iy+0),2Bh		;
	ld	(iy+1),80h		; YM => Enable DAC
	ld	a,(ix+flags)		; load flags
	and	0C0h			; are pan bits set?
	jr	z,+			; if not, branch
        ld	(iy+2),0B6h		;
	ld	(iy+3),a		; YM => Set Pan
+	ld	(iy+0),2Ah		; setup YM to fetch DAC bytes
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
	jp	0h

Event_SoundProc:
	jp	0h
	
Event_Interrupt:
	jp	0h

Event_EndPlayback:
	jp	0h


; ===============================================================
; ---------------------------------------------------------------
; Routines to control sound playback (stop/pause/interrupt)
; ---------------------------------------------------------------
; NOTICE:
;	The following routines are 'Interrupt' event handlers,
;	they must't use any registers except A. If they does, 
;	it will break sample playback code.
;	You may do push/pop from stack though.
;	'StopDAC' is expection, as it breaks playback anyway.
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; DAC Interrupt: Normal Priority
; ---------------------------------------------------------------
; INPUT:
;	a	= Ctrl byte
; ---------------------------------------------------------------

Int_Normal:
	cp	80h			; stop flag?
	jp	z,StopDAC		; if yes, branch
	jp	m,PauseDAC		; if < 80h, branch
	ld	hl,DAC_Number
	jp	LoadDAC

; ---------------------------------------------------------------
; DAC Interrupt: High Priority
; ---------------------------------------------------------------
; INPUT:
;	a	= Ctrl byte
; ---------------------------------------------------------------

Int_NoOverride:
	cp	80h			; stop flag?
	jp	z,StopDAC		; if yes, branch
	jp	m,PauseDAC		; if < 80h, branch
	xor	a			; a = 0
	ld	(DAC_Number),a		; clear DAC number to prevent later ints
	jp	Event_SoundProc

; ---------------------------------------------------------------
; Code to wait while playback is paused
; ---------------------------------------------------------------

PauseDAC:
	ld	(iy+1),80h		; stop sound

-	ld	a,(DAC_Number)		; load ctrl byte
	or	a			; is byte zero?
	jr	nz,-			; if not, branch

	call	SetupDAC		; setup YM for playback
	jp	Event_SoundProc		; go on playing

; ---------------------------------------------------------------
; Stop DAC playback and get back to idle loop
; ---------------------------------------------------------------

StopDAC:
	ld	(iy+1),80h		; stop sound
	jp	Idle_Loop


; ===============================================================
; ---------------------------------------------------------------
; Routines to control bank-switching
; ---------------------------------------------------------------
; Bank-Switch Registers Set:
;	b'	= Current Bank Number
;	c'	= Last Bank Number
;	de'	= Bank Register
;	hl'	= End offset (bytes to play in last bank)
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; Inits bank-switch system and loads first bank
; ---------------------------------------------------------------

InitBankSwitching:
	exx
	ld	d,(ix+s_pos+1)
	ld	e,(ix+s_pos)	; de' = start offset (in first bank)
	ld	h,(ix+e_pos+1)
	ld	l,(ix+e_pos)	; hl' = end offset (in last bank)
	ld	b,(ix+s_bank)	; b'  = start bank number
	ld	c,(ix+e_bank)	; c'  = end bank number
	ld	a,b		; load start bank number
	cp	c		; does the sample end in the first bank?
	jr	nz,+		; if not, branch
	sbc	hl,de		; hl' = end offset - start offset
	set	7,h		; make the number 8000h-based
+	ld	de,BankRegister	; de' = bank register
	jp	LoadBank

; ---------------------------------------------------------------
; Subroutine to switch to the next bank
; ---------------------------------------------------------------

LoadNextBank:
	exx
	inc	b		; increase bank number
	ld	a,b		; load bank number

LoadBank:
	ld	(de), a	; A15
	rrca
	ld	(de), a	; A16
	rrca
	ld	(de), a	; A17
	rrca
	ld	(de), a	; A18
	rrca
	ld	(de), a	; A19
	rrca
	ld	(de), a	; A20
	rrca
	ld	(de), a	; A21
	rrca
	ld	(de), a	; A22
	xor	a	; a = 0
	ld	(de), a	; A23
	exx
	ret

; ===============================================================
; ---------------------------------------------------------------
; Routines to process PCM sound playback
; ---------------------------------------------------------------
; PCM Registers Set:
;	B	= Pitch Counter
;	C	= Pitch
;	DE	= <Unused>
;	HL	= PCM byte pointer
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; Init PCM playback or reload PCM file
; ---------------------------------------------------------------

Reload_PCM:

Init_PCM:    
	call	SetupDAC       
	call	InitBankSwitching
	ld	c,(ix+pitch)		; c  = pitch
	ld	h,(ix+s_pos+1)		;
	ld	l,(ix+s_pos)		; hl = Start offset
	set	7,h			; make it 8000h-based if it's not (perverts memory damage if playing corrupted slots)
	ld	(iy+0),2Ah		; YM => prepare to fetch DAC bytes

; ---------------------------------------------------------------
; PCM Playback Loop
; ---------------------------------------------------------------

Process_PCM:

	; Read sample's byte and send it to DAC with pitching
	ld	a,(hl)			; 7	; get PCM byte
	ld	b,c			; 4	; b = Pitch
	djnz	$			; 7/13+	; wait until pitch zero
	ld	(YM_Port0_Data),a	; 13	; write to DAC
	; Cycles: 31

	; Increment PCM byte pointer and switch the bank if necessary
	inc	hl			; 6	; next PCM byte
	bit	7,h			; 8	; has the bank warped?
	jr	z,++			; 7/12	; if yes, switch the bank
	; Cycles: 21

	; Check if sample playback is finished
	exx				; 4	;
	ld	a,c			; 4	; load last bank no.
	sub	b			; 4	; compare to current bank no.
	jr	nz,+			; 7/12	; if last bank isn't reached, branch
	dec	hl			; 6	; decrease number of bytes to play in last bank
	or	h			; 4	; is hl positive?
	jp	p,+++			; 10	; if yes, quit playback loop
	exx				; 4	;
	; Cycles: 43

	; Check if we should play a new sample
-	ld	a,(DAC_Number)		; 13	; load DAC number
	or	a			; 4	; test it
	jp	z,Process_PCM		; 10	; if zero, go on playing
	jp	Event_Interrupt		;	; otherwise, interrupt playback
	; Cycles: 27

	; Synchronization loop (20 cycles)
+	exx				; 4
	nop				; 4
	jr	-			; 12

	; Switch to next bank
+	ld	h,80h			; restore base addr
	call	LoadNextBank
	jp	-

	; Quit playback loop
+	exx
	jp	Event_EndPlayback

; ---------------------------------------------------------------
; Best cycles per loop:	122
; Max Possible rate:	3,550 kHz / 122 = 29 kHz (PAL)
; ---------------------------------------------------------------

; ===============================================================
; ---------------------------------------------------------------
; Routines to process DPCM sound playback
; ---------------------------------------------------------------
; DPCM Registers Set:
;	B	= Pitch Counter / also DAC Value
;	C	= Pitch
;	DE	= DPCM byte pointer
;	HL	= Delta Table
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; Init DPCM playback or reload DPCM file
; ---------------------------------------------------------------

Reload_DPCM:

Init_DPCM:
	call	SetupDAC
	call	InitBankSwitching
	ld	c,(ix+pitch)		; c  = pitch
	ld	d,(ix+s_pos+1)		;
	ld	e,(ix+s_pos)		; de = start offset
	set	7,d			; make it 8000h-based if it's not (perverts memory damage if playing corrupted slots)
	ld	h,DPCM_DeltaArray>>8	; load delta table base
	ld	(iy+0),2Ah		; YM => prepare to fetch DAC bytes
	ld	b,80h			; init DAC value

Process_DPCM:

	; Calculate and send 2 values to DAC
	ld	a,(de)			; 7	; get a byte from DPCM stream
	rrca				; 4	; get first nibble
	rrca				; 4	;
	rrca				; 4	;
	rrca				; 4	;
	and	0Fh			; 7	; mask nibble
	ld	l,a			; 4	; setup delta table index
	ld	a,b			; 4	; load DAC Value
	add	a,(hl)			; 7	; add delta to it
	ld	b,c			; 4	; b = Pitch
	djnz	$			; 7/13+	; wait until pitch zero
	ld	(YM_Port0_Data),a	; 13	; write to DAC
	ld	b,a			; 4	; b = DAC Value
	; Cycles: 73

	ld	a,(de)			; 7	; reload DPCM stream byte
	and	0Fh			; 7	; get second nibble
	ld	l,a			; 4	; setup delta table index
	ld	a,b			; 4	; load DAC Value
	add	a,(hl)			; 7	; add delta to it
	ld	b,c			; 4	; b = Pitch
	djnz	$			; 7/13+	; wait until pitch zero
	ld	(YM_Port0_Data),a	; 13	; write to DAC
	ld	b,a			; 4	; b = DAC Value
	; Cycles: 57

	; Increment DPCM byte pointer and switch the bank if necessary
	inc	de			; 6	; next DPCM byte
	bit	7,d			; 8	; has the bank warped?
	jr	z,++			; 7/12	; if no, switch the bank
	; Cycles: 21

	; Check if sample playback is finished
	exx				; 4	;
	ld	a,c			; 4	; load last bank no.
	sub	b			; 4	; compare to current bank no.
	jr	nz,+			; 7/12	; if last bank isn't reached, branch
	dec	hl			; 6	; decrease number of bytes to play in last bank
	or	h			; 4	; is hl positive?
	jp	p,+++			; 10	; if yes, quit playback loop
	exx				; 4	;
	; Cycles: 43

	; Check if we should play a new sample
-	ld	a,(DAC_Number)		; 13	; load DAC number
	or	a			; 4	; test it
	jp	z,Process_DPCM		; 10	; if zero, go on playing
	jp	Event_Interrupt		;	; otherwise, interrupt playback
	; Cycles: 27

	; Synchronization loop (20 cycles)
+	exx				; 4
	nop				; 4
	jr	-			; 12

	; Switch to next bank
+	ld	d,80h			; restore base address
	call	LoadNextBank
	jp	-

	; Quit playback loop
+	exx
	jp	Event_EndPlayback

; ---------------------------------------------------------------
; Best cycles per loop:	221/2
; Max possible rate:	3,550 kHz / 111 = 32 kHz (PAL)
; ---------------------------------------------------------------
                                        
	align	100h	; it's important to align this way, or the code above won't work properly

DPCM_DeltaArray:
	db	0, 1, 2, 4, 8, 10h, 20h, 40h
	db	-80h, -1, -2, -4, -8, -10h, -20h, -40h

; ---------------------------------------------------------------
; NOTICE ABOUT PLAYBACK RATES:
;	YM is only capable of producing DAC sound @ ~26 kHz
;	frequency, overpassing it leads to missed writes!
;	The fact playback code can play faster than that
;	means there is a good amount of room for more features,
;	i.e. to waste even more processor cycles! ;)
; ---------------------------------------------------------------

; ===============================================================

; Table of DAC samples goes right after the code.
; It remains empty here, you are meant to fill it in your hack's
; disassembly right after including compiled driver.

DAC_Table:
