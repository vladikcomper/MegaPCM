
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
	jr	z,.nextbank		; 7/12	; if no, switch the bank
	; Cycles: 21

	; Check if sample playback is finished
	exx				; 4	;
	ld	a,c			; 4	; load last bank no.
	sub	b			; 4	; compare to current bank no.
	jr	nz,.sync		; 7/12	; if last bank isn't reached, branch
	dec	hl			; 6	; decrease number of bytes to play in last bank
	or	h			; 4	; is hl positive?
	jp	p,.end			; 10	; if yes, quit playback loop
	exx				; 4	;
	; Cycles: 43

	; Check if we should play a new sample
.chk_sample:
	ld	a,(DAC_Number)		; 13	; load DAC number
	or	a			; 4	; test it
	jp	z,Process_DPCM		; 10	; if zero, go on playing
	jp	Event_Interrupt		;	; otherwise, interrupt playback
	; Cycles: 27

	; Synchronization loop (20 cycles)
.sync:	exx				; 4
	nop				; 4
	jr	.chk_sample		; 12

	; Switch to next bank
.nextbank:
	ld	d,80h			; restore base address
	call	LoadNextBank
	jp	.chk_sample

	; Quit playback loop
.end:	exx
	jp	Event_EndPlayback

; ---------------------------------------------------------------
; Best cycles per loop:	221/2
; Max possible rate:	3,550 kHz / 111 = 32 kHz (PAL)
; ---------------------------------------------------------------

	align	100h	; it's important to align this way, or the code above won't work properly

DPCM_DeltaArray:
	db	0, 1, 2, 4, 8, 10h, 20h, 40h
	db	-80h, -1, -2, -4, -8, -10h, -20h, -40h
