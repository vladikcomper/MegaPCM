
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
; Registers:
;	bc	= Length + 0FFh (so b = 0, c = -overshoot)
;	de 	= Sample buffer pos (read-ahead)
;	hl	= ROM pos
; --------------------------------------------------------------

PCMLoop_NormalPhase:
	DebugMsg "PCMLoop_NormalPhase iteration"

	; Handle playback
	PlaybackPitched_Run_Normal	e, PCMLoop_NormalPhase_ReadaheadFull
	; Total cycles: 91-92 (read-ahead ok), 96/97 (read-ahead full)

	; Handle "read-ahead" (if `PlaybackPitched_Run_Normal` decides so ...)
	ldi					; 16
	ldi					; 16
	ld	d, SampleBuffer>>8		; 7	fix `d` in case of carry from `e`
	jp	pe, PCMLoop_NormalPhase		; 10	if bc != 0, branch (WARNING: this requires everything to be word-aligned)
	; Total cycles: 49

	; Total "PCMLoop_NormalPhase" cycles: 140-141

; --------------------------------------------------------------
;PCMLoop_ReadAheadExhausted:
	; Are we done playing?
	ld	a, (CurrentBank)
	cp	(ix+sSample.endBank)			; current bank is the last one?
	jr	nz, PCMLoop_NormalPhase_LoadNextBank	; if not, branch

; --------------------------------------------------------------
; PCM: Draining loop (playback only)
; --------------------------------------------------------------

PCMLoop_DrainPhase:
	DebugMsg "PCMLoop_DrainPhase iteration"

	PlaybackPitched_Run_Draining	e, PCMLoop_DrainPhase_Done
	; Total cycles: 64 (pitch), 65 (no pitch)

	; Idle reads from ROM to keep timings accurate
	ld	a, (ROMWindow)		; 13
	ld	a, (ROMWindow)		; 13

	; TODOH: CYCLES
	jp	PCMLoop_DrainPhase

; --------------------------------------------------------------
PCMLoop_DrainPhase_Done:
	exx

	; Back to idle loop
	jp	IdleLoop_Init

; --------------------------------------------------------------
PCMLoop_NormalPhase_LoadNextBank:
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
	jp	PCMLoop_NormalPhase

; --------------------------------------------------------------
PCMLoop_NormalPhase_ReadaheadFull:
	; Idle reads from ROM to keep timings accurate
	ld	a, (ROMWindow)		; 13
	ld	a, (ROMWindow)		; 13

	; Back to the main loop
	jp	PCMLoop_NormalPhase

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

	; Waste 63 cycles
	rept 3
		pop	bc				; 10
		push	bc				; 11
	endr
	; Total cycles: 63

	djnz	PCMLoop_VBlank_Loop			; 10/13
	; Total cycles per iteration: 140-141 (TODO: Verify)

;PCMLoop_CheckCommand:
	ld	bc, DriverIO_RAM+sDriverIO.IN_command
	ld	a, (bc)					; a = command
	or	a					; is command > 00h?
	jr	z, .ChkSample_Done			; if not, branch

	; TODO: Finish this!

.ChkSample_Done:
	pop	bc
	pop	af
	ei
	reti
