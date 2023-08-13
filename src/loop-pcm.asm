
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; PCM loop module
;
; (c) 2023, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSample` structure
;	iy	Pointer to `sDriverIO` structure
; --------------------------------------------------------------

PCMLoop_Init:
	di

	; Load initial bank ...
	ld	a, (ix+sSample.startBank)
	ld	(CurrentBank), a
	call	LoadBank

	; Init read ahead registers ...
	ld	de, SampleBuffer		; de = sample buffer
	ld	l, (ix+sSample.startOffset)
	ld	h, (ix+sSample.startOffset+1)	; hl = start offset

	ld	a, (ix+sSample.startBank)
	cp	(ix+sSample.endBank)		; start and end in the same bank?
	jr	nz, .calcLengthTillEndOfBank
	
	ld	c, (ix+sSample.endLen)
	ld	b, (ix+sSample.endLen+1)	; bc = length - 1
	inc	b				; bc = length + FFh
	jp	.readAheadDone

.calcLengthTillEndOfBank:
	; Not implemented
	call	Debug_ErrorTrap

.readAheadDone:

	; Init playback registers ...
	exx
	ex	af, af'
	xor	a				; a' = 0
	ex	af, af'
	ld	b, (ix+sSample.pitch)
	ld	c, 03h				; c = 03h (constant)
	ld	hl, SampleBuffer
	ld	de, YM_Port0_Data
	exx

	; Prepare DAC playback
	ld	a, 2Ah
	ld	(YM_Port0_Reg), a

; --------------------------------------------------------------
;
; --------------------------------------------------------------
; Playback registers:
;	a'	= Pitch counter
;	b'	= Pitch value
;	c'	= `03h`
;	de'	= YM Port 0 data
;	hl'	= Sample buffer pos (playback)
;
; Read ahead registers:
;	bc	= Length + 0FFh (so b = 0, c = -overshoot)
;	de 	= Sample buffer pos (read-ahead)
;	hl	= ROM pos
; --------------------------------------------------------------

PCMLoop_Main:
	DebugMsg "PCMLoop_Main iteration"

	; Playback routine
	di					; 4
	ld	a, e				; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Skip		; 7
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	inc	l				; 4	roll through 256-byte buffer
.playback_Skip:
	ld	a, l				; 4	a = buffer position
	add	c				; 4	a = buffer position + 3
	exx					; 4
	ei					; 4
	; Total cycles: 80 (pitch), 81 (no pitch)

	sub	e				; 4	a = buffer position + 3 - e
	jr	c, PCMLoop_Sync_NoBufferFill	; 7	if read-ahead buffer is exhausted, branch
	; Total cycles: 11

	; Fill buffer (4 bytes)
	ldi					; 16
	ldi					; 16
	ld	d, SampleBuffer>>8		; 7	fix `d` in case of carry from `e`
	xor	a				; 4
	or	b				; 4
	jr	nz, PCMLoop_Main		; 12
	; Total cycles: 67

	; Total "PCMLoop_Main" cycles: 158

PCMLoop_ReadAheadExhausted:
	; NOTICE: We could've avoided this if all offsets are
	; word-aligned.
	; Make sure playback won't read excess bytes! This should
	; be avoided by `de` + 3 < `hl'` invariant.

	; Correct `de` (buffer pos) in case of overshoot
	;
	; At this point, bc = 00FFh, 00FEh or lower
	; Values 00FEh or less mean we've read excess bytes
	ld	a, e				; a = e
	inc	c				; c = 0 or -1 (corrects "overshoot boundary")
	add	c				; a = e + (c + 1)
	ld	e, a				; e = e + (c + 1)

	; Are we done playing?
	ld	a, (CurrentBank)
	cp	(ix+sSample.endBank)		; current bank is the last one?
	jr	nz, PCMLoop_LoadNextBank	; if not, branch

; --------------------------------------------------------------
;
; --------------------------------------------------------------
; Playback registers:
;	a'	= Pitch counter
;	b'	= Pitch value
;	c'	= `03h`
;	de'	= YM Port 0 data
;	hl'	= Sample buffer pos (playback)
; --------------------------------------------------------------

PCMLoop_Drain:
	DebugMsg "PCMLoop_Drain iteration"

	; Playback routine
	ld	a, e				; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, PCMLoop_Drain_Done		; 7
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	inc	l				; 4	roll through 256-byte buffer
	exx					; 4
	; Total cycles: 64 (pitch), 65 (no pitch)

	; TODOH: CYCLCES
	jp	PCMLoop_Drain

; --------------------------------------------------------------

PCMLoop_Drain_Done:
	exx

	ld	a, ERROR__NOT_IMPLEMENTED
	call	Debug_ErrorTrap

; --------------------------------------------------------------
PCMLoop_LoadNextBank:
	ld	a, ERROR__NOT_IMPLEMENTED
	call	Debug_ErrorTrap

PCMLoop_Sync_NoBufferFill:
	ld	a, ERROR__NOT_IMPLEMENTED
	call	Debug_ErrorTrap

; --------------------------------------------------------------
;
; --------------------------------------------------------------

PCMLoop_VBlank:
	push	af
	push	bc

	ld	b, 10

PCMLoop_VBlank_Loop:

	; Playback routine
	ld	a, e				; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Skip		; 7
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	inc	l				; 4	roll through 256-byte buffer
.playback_Skip:
	exx					; 4
	; Total cycles: 64 (pitch), 65 (no pitch)

	; Check for new samples
	; TODO: ###

	djnz	PCMLoop_VBlank_Loop

	pop	bc
	pop	af
	ei
	reti
