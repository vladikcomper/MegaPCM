
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

	DebugMsg "Entering PCMLoop"

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
	ld	c, a				; c = 0 - l
	sbc	h				; a = 0 - h - l - carry
	add	l				; a = 0 - h - carry
	ld	b, a				; b = 0 - h - carry

.readAheadDone:

	; Init playback registers ...
	PlaybackPitched_Init	de, 2

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
	; Total cycles: 90-91 (playback ok)

	; Handle "read-ahead" (if `PlaybackPitched_Run_Normal` decides so ...)
	ldi					; 16
	ldi					; 16
	ld	d, SampleBuffer>>8		; 7	fix `d` in case of carry from `e`
	jp	pe, PCMLoop_NormalPhase		; 10	if bc != 0, branch (WARNING: this requires everything to be word-aligned)
	; Total cycles: 49

	; Total "PCMLoop_NormalPhase" cycles: 139-140

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

	PlaybackPitched_Run_Draining	e, PCMLoop_DrainPhase_Done_EXX_DI
	; Total cycles: 72-73 (playback ok), 28 (drained)

	; Idle reads from ROM to keep timings accurate
	ld	a, (ROMWindow)			; 13
	nop					; 4
	ld	a, (ROMWindow)			; 13
	nop					; 4
	; Total cycles: 30

	; Waste 21 cycles
	push	bc				; 11
	pop	bc				; 10
	; Total cycles: 21

	jr	PCMLoop_DrainPhase		; 12
	; Total "PCMLoop_DrainPhase" cycles: 139-140

; --------------------------------------------------------------
PCMLoop_DrainPhase_Done_EXX_DI:
	; NOTE: We won't re-enable interrupts here
	exx

	bit	FLAGS_LOOP, (ix+sSample.flags)		; is sample set to loop?
	jp	nz, PCMLoop_Init			; re-enter playback loop

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
	ld	b, 80h				; bc = 8000h (alt: ld b, h)
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
	; Cycles spent so far: 96-97
	; Cycles to waste: 140-141 - 96-97 = 44-45

	; Idle reads from ROM to keep timings accurate
	ld	a, (ROMWindow)		; 13
	ld	a, (ROMWindow)		; 13

	nop				; 4
	nop				; 4
	; Waste 8 cycles

	; Back to the main loop
	jp	PCMLoop_NormalPhase	; 10

; --------------------------------------------------------------
;
; --------------------------------------------------------------

PCMLoop_VBlank:
	push	af
	push	bc

	ld	b, 38-1		; TODO: Verify this

PCMLoop_VBlankPhase:
	; Playback routine
	; NOTE: When out of buffer, it's recommended to stay inside this loop,
	; but we currently just bail out.
	PlaybackPitched_Run_DrainingVBlank	e, PCMLoop_VBlank_Loop_DrainDoneSync_EXX
	; Total cycles: 64-65 (playback ok), 24 (drained)

PCMLoop_VBlankPhase_Sync:
	; Waste 62 cycles
	push	bc					; 11
	ld	b, 03h		 			; 7
	djnz	$					; 13 * 2 + 8
	pop	bc					; 10
	; Total cycles: 62

	djnz	PCMLoop_VBlankPhase			; 8/13
	; Total "PCMLoop_VBlankPhase" cycles: 139-140

	; Last iteration is special:
	; We reload pitch from memory to make it dynamic and
	; we don't have a sync branch, since we're out of the loop
	PlaybackPitched_Run_DrainingVBlank_ReloadPitch_NoSync	e, (ix+sSample.pitch)
	; Total cycles: 83-84 (playback ok), 28 (drained)

; --------------------------------------------------------------
PCMLoop_CheckCommandOrSample:
	ld	a, (DriverIO_RAM+sDriverIO.IN_command)	; a = command
	or	a					; is command > 00h?
	jr	z, .ChkCommandOrSample_Done		; if not, branch
	jp	p, .ChkCommandOrSample_Command		; if command = 01..7Fh, branch

	; Only low-priority samples can be overriden
	bit	FLAGS_PRIORITY, (ix+sSample.flags)	; is sample high priority?
	jp	z, .ResetDriver_ToLoadSample		; if not, branch

.ChkCommandOrSample_Done:
	pop	bc
	pop	af
	ei
	ret

; --------------------------------------------------------------
.ChkCommandOrSample_Command:
	dec	a					; is command 01h (STOP)?
	jp	z, .ResetDriver_ToIdleLoop		; if yes, branch
	dec	a					; is command 02h (PAUSE)?
	ifdef __DEBUG__
		jr	z, .PausePlayback
		ld	a, ERROR__NOT_IMPLEMENTED
		call	Debug_ErrorTrap
	else
		jr	nz, .ChkCommandOrSample_Done		; if unknown command, ignore
	endif

.PausePlayback:
	; There's a trick to it: While the "pause command" is set,
	; we reset sample pitch to 0, cancelling pitch reload above.
	; As soon as this command is unset, the pitch reload will restore it.
	exx
	ld	b, 0					; set pitch to 00h
	exx
	jr	.ChkCommandOrSample_Done

; --------------------------------------------------------------
.ResetDriver_ToIdleLoop:
	ld	sp, Stack				; reset stack
	jp	IdleLoop_Init				;

; --------------------------------------------------------------
.ResetDriver_ToLoadSample:
	ld	sp, Stack				; reset stack
	jp	LoadSample				; load sample stored in A

; --------------------------------------------------------------
PCMLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 40 cycles
	exx						; 4
	inc	bc					; 6
	dec	bc					; 6
	inc	bc					; 6
	dec	bc					; 6
	jr	PCMLoop_VBlankPhase_Sync		; 12
