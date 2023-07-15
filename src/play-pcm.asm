
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
	jr	z,.nextbank		; 7/12	; if yes, switch the bank
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
	jp	z,Process_PCM		; 10	; if zero, go on playing
	jp	Event_Interrupt		;	; otherwise, interrupt playback
	; Cycles: 27

	; Synchronization loop (20 cycles)
.sync:	exx				; 4
	nop				; 4
	jr	.chk_sample		; 12

	; Switch to next bank
.nextbank:
	ld	h,80h			; restore base addr
	call	LoadNextBank
	jp	.chk_sample

	; Quit playback loop
.end:	exx
	jp	Event_EndPlayback

; ---------------------------------------------------------------
; Best cycles per loop:	122
; Max Possible rate:	3,550 kHz / 122 = 29 kHz (PAL)
; ---------------------------------------------------------------