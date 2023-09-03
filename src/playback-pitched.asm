
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.0
;
; Inline functions for pitched playback
; -----------------------------------------------------------------------------
; (c) 2023, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initializes pitched playback registers
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadaheadPtr	- Register with readahead position (bc, de, hl)
; 
; INPUT:
;	ix	= Sample pointer
; 
; OUTPUT:
;	a'	= Pitch counter
;	b'	= Pitch value
;	c'	= `03h`
;	de'	= YM Port 0 data
;	hl'	= Playback position (in SampleBuffer)
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Init regReadaheadPtr
	push	regReadaheadPtr
	exx
	ex	af, af'
	xor	a				; a' = 0
	ex	af, af'
	ld	b, (ix+sSample.pitch)
	ld	c, 03h				; c = 03h (constant)
	pop	hl				; hl = regReadaheadPtr
	ld	de, YM_Port0_Data
	exx
	endm

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_Normal	regReadAheadPtrLow, procReadaheadFull
	di					; 4
	ld	a, regReadAheadPtrLow		; 4	a = "read-ahead" position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Skip		; 7/12	if buffer is drained, branch
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7/12	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
.playback_Skip:
	ld	a, l				; 4	a = buffer position
	add	c				; 4	a = buffer position + 3
	exx					; 4
	ei					; 4
	; Cycles: 44 (drained), 80 (playback/pitched), 81 (playback/didn't pitch)

	sub	regReadAheadPtrLow		; 4	a = buffer position + 3 - regReadAheadPtrLow
	jr	c, procReadaheadFull		; 7/12	if "read-ahead" position is about to collide with "playback", branch
	; Cycles: 11 (read-ahead ok), 16 (read-ahead full)

	; Total cycles:
	; - 55 cycles (playback drained, read-ahead ok)
	; - 91-92 cycles (playback ok, read-ahead ok)
	; - 96-97 cycles (playback ok, read-ahead full)

	endm

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_Draining	regReadAheadPtrLow, procDrainDone

	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, procDrainDone		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	exx					; 4
	; Total cycles: 64 (pitch), 65 (no pitch), 24 (drain done)

	endm

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

; WARNING! Unused
	macro	PlaybackPitched_Run_DrainingSeq	regReadAheadPtrLow

	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Skip		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
.playback_Skip:
	exx					; 4
	; Total cycles: 64 (pitch), 65 (no pitch), 28 (skipped)

	endm

