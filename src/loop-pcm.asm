
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

	; Setup VInt ...
	ld	hl, PCMLoop_VBlank
	ld	(VBlankRoutine), hl

	; Init read ahead registers ...
	ld	de, SampleBuffer		; de = sample buffer
	ld	l, (ix+sSample.startOffset)
	ld	h, (ix+sSample.startOffset+1)	; hl = start offset
	res	0, l				; hl = start offset & 0FFFEh

	ld	a, (ix+sSample.startBank)
	cp	(ix+sSample.endBank)		; start and end in the same bank?
	jr	nz, .calcLengthTillEndOfBank

	ld	c, (ix+sSample.endLen)
	ld	b, (ix+sSample.endLen+1)	; bc = length
	res	0, c				; bc = length & 0FFFEh
	jp	.readAheadDone

.calcLengthTillEndOfBank:
	; Implements: bc = 10000h - hl, or simply bc = -hl
	xor	a				; a = 0
	sub	l				; a = 0 - l
	ld	e, a				; e = 0 - l
	sbc	h				; a = 0 - h - l - carry
	add	l				; a = 0 - h - carry
	ld	d, a				; d = 0 - h - carry

.readAheadDone:

	; Init playback registers ...
	PlaybackPitched_Init	de

	; Prepare DAC playback
	ld	a, 2Ah
	ld	(YM_Port0_Reg), a

; --------------------------------------------------------------
; PCM: Main playback loop (readahead & playback)
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

PCMLoop_Normal:
	DebugMsg "PCMLoop_Normal iteration"

	; Handle playback
	PlaybackPitched_Run_Normal	e, PCMLoop_Sync_ReadaheadFull
	; Total cycles: 91-92 (read-ahead ok), 96/97 (read-ahead full)

	; Handle "read-ahead"
	ldi					; 16
	ldi					; 16
	ld	d, SampleBuffer>>8		; 7	fix `d` in case of carry from `e`
	jp	pe, PCMLoop_Normal		; 10	if bc != 0, branch (WARNING: this requires everything to be word-aligned)
	; Total cycles: 49

	; Total "PCMLoop_Normal" cycles: 140-141

; --------------------------------------------------------------
PCMLoop_ReadAheadExhausted:
	; Are we done playing?
	ld	a, (CurrentBank)
	cp	(ix+sSample.endBank)		; current bank is the last one?
	jr	nz, PCMLoop_LoadNextBank	; if not, branch

; --------------------------------------------------------------
; PCM: Draining loop (playback only)
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

	PlaybackPitched_Run_Draining	e, PCMLoop_Drain_Done
	; Total cycles: 64 (pitch), 65 (no pitch)

	; Idle reads from ROM to keep timings accurate
	ld	a, (ROMWindow)		; 13
	ld	a, (ROMWindow)		; 13

	; TODOH: CYCLES
	jp	PCMLoop_Drain

; --------------------------------------------------------------

PCMLoop_Drain_Done:
	exx

	ld	a, ERROR__NOT_IMPLEMENTED
	call	Debug_ErrorTrap

; --------------------------------------------------------------
PCMLoop_LoadNextBank:
	; Increment current bank index
	ld	a, (CurrentBank)
	inc	a
	ld	(CurrentBank), a

	; Setup sample source and length
	ld	hl, ROMWindow			; hl = 8000h (alt: ld h, ROMWindow<<8)
	ld	b, 8h				; bc = 8000h (alt: ld b, h)
	cp	(ix+sSample.endBank)		; current bank is the last one?
	jr	nz, .lengh_ok			; if not, branch
	ld	c, (ix+sSample.endLen)
	ld	b, (ix+sSample.endLen+1)	; bc = length
	res	0, c				; bc = length & 0FFFEh
.lengh_ok:

	; Switch to bank stored in A
	call	LoadBank

	; Ready to continue playback!
	jp	PCMLoop_Normal

; --------------------------------------------------------------
PCMLoop_Sync_ReadaheadFull:
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
	PlaybackPitched_Run_DrainingSeq	e
	; Total cycles: 64 (pitch), 65 (no pitch)

	djnz	PCMLoop_VBlank_Loop

	; TODO: Check for new samples

	pop	bc
	pop	af
	ei
	reti
