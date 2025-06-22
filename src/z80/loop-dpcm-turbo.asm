
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.1
; --------------------------------------------------------------
; Turbo DPCM loop module
;
; (c) 2023-2025, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSample` structure
; --------------------------------------------------------------

DPCMTurboLoop:
	di

	TraceMsg "Entering DPCMTurboLoop"

	ld	a, LOOP_DPCM_TURBO
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, DPCMTurboLoop_VBlank
	ld	(VBlankRoutine), hl

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Load DPCM delta table ###
	ld	hl, DPCM_DeltaTable_00
	call	LoadDPCMTable_DI

; --------------------------------------------------------------
DPCMTurboLoop_Reload:

	; Set initial ROM bank ...
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	di

	; Init read ahead registers ...
	ld	bc, SampleBuffer
	ld	h, DPCMTables>>8
	ld	de, (ActiveSample+sActiveSample.startOffset)
	exx
	ld	bc, (ActiveSample+sActiveSample.startLength)
	inc	c

	; Init playback registers ...
	PlaybackTurbo_Init_EXX_DI	SampleBuffer

	ei
	dec	c
	ld	a, 80h				; set initial sample to zero (80h)
	ld	(bc), a				; ''

; --------------------------------------------------------------
; DPCM: Main playback loop (readahead & playback)
; --------------------------------------------------------------
; Registers:
;	bc 	= Sample buffer pos (read-ahead)
;	de	= ROM pos
;	hl	= DPCM decode table pointer
;	c'	= Remaining length in ROM bank - 1 (LOW) + 1
;	b'	= Remaining length in ROM bank - 1 (HIGH)
; --------------------------------------------------------------

DPCMTurboLoop_NormalPhase_NoCycleStealing:
	nop					; +4*	used as entry point to the loop for poor emulators
						;	... that don't emulate cycle-stealing

DPCMTurboLoop_NormalPhase:
	; Handle "read-ahead" buffer
	ld	a, (de)				; 7+3.3*
	inc	de				; 6	increment ROM pointer
	ld	l, a				; 4	l = 2 DPCM samples (nibbles)
	ld	a, (bc)				; 7	a = previous sample
	inc	c				; 4	increment buffer pointer
	add	a, (hl)				; 7	a = first sample (decoded)
	inc	h				; 4	select DPCM table for the second nibble
	di					; 4	-- don't move this too far away from `ei` below
	ld	(bc), a				; 7	store first sample
	inc	c				; 4	increment buffer pointer
	add	a, (hl)				; 7	a = second sample (decoded)
	dec	h				; 4	reset DPCM table to the first nibble (for next iteration)
	ld	(bc), a				; 7	store second sample
	exx					; 4
	dec	c				; 4	decrement sample length
	jr	z, .ChkReadAheadExhausted_EXX_DI; 7/12	if borrow from a high byte, branch
	; Total cycles: 87

	; Handle playback
.Playback_EXX_DI:
	PlaybackTurbo_Run_EXX_DI				; 26	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	PlaybackTurbo_ChkReadaheadOk	c, b, DPCMTurboLoop_NormalPhase	; 18
	; Total cycles: 48

	; Total "DPCMTurboLoop_NormalPhase" cycles: ~135 + 3.3*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	; Waste 87 + 3* cycles (we cannot handle "read-ahead" now)
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	hl						; 11
	ld	l, 0						; 7
	pop	hl						; 10
	di							; 4
	exx							; 4
	jr	.Playback_EXX_DI				; 12

; --------------------------------------------------------------
.ChkReadAheadExhausted_EXX_DI:
	dec	b				; 4	decrement high byte of length
	jp	p, .Playback_EXX_DI		; 10	if no borrow, back to playback

.ReadAheadExhausted_EXX_DI:
	exx

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4

	; Are we done playing?
	ld	a, (CurrentBank)				; 13
	ld	hl, ActiveSample+sActiveSample.endBank		; 10
	cp	(hl)						; 7	current bank is the last one?
	jr	nz, DPCMTurboLoop_NormalPhase_LoadNextBank	; 7/12	if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; DPCM Turbo: Draining loop (playback only)
; --------------------------------------------------------------

DPCMTurboLoop_DrainPhase:
	; Handle playback in draining mode
	di							; 4
	PlaybackTurbo_Run_Draining	c, .Drained_EXX_DI	; 41
	ei							; 4

	; Waste 86 + 3* cycles
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	hl						; 11
	inc	hl						; 6
	inc	hl						; 6
	inc	hl						; 6
	pop	hl						; 10
	jr	DPCMTurboLoop_DrainPhase			; 12
	; Total "DPCMTurboLoop_DrainPhase" cycles: 135 + 3*
	; *) additional cycles lost due to M68K bus access on average


; --------------------------------------------------------------
.Drained_EXX_DI:
	exx

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei

	ld	a, (ActiveSample+sActiveSample.flags)	; a = flags
	and	1<<FLAGS_LOOP				; is sample set to loop?
	jp	nz, DPCMTurboLoop_Reload		; re-enter playback loop

	; Return from the playback loop
	ret

; --------------------------------------------------------------
DPCMTurboLoop_NormalPhase_LoadNextBank:
	; Prepare next bank id
	inc	a

	; Setup sample source and length
	cp	(hl)				; is next bank the last one?
	ld	h, DPCMTables>>8
	ld	de, ROMWindow			; de = 8000h (alt: ld b, ROMWindow<<8)
	di					; we can't allow interrupts when using shadow registers
	exx
	ld	bc, 7F00h			; bc' = 7F00h (7Fh+0, FFh+1)
	jr	nz, .lengh_ok			; if not the last bank, branch
	ld	bc, (ActiveSample+sActiveSample.endLength)
	inc	c
.lengh_ok:
	exx
	ei

	; Switch to the next ROM bank
	rst	SetBank2

	; Jump back to playback loop where we left off...
	di
	exx
	jp	DPCMTurboLoop_NormalPhase.Playback_EXX_DI

; --------------------------------------------------------------
; DPCM Turbo: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is when finishing `CalibrationLoop`, only if
; calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

DPCMTurboLoop_ApplyCalibration:
	; TODO:
	;ld 	hl, DPCMTurboLoop_NormalPhase_NoCycleStealing
	;ld 	(DPCMTurboLoop_NormalPhase.chkReadahead_sm1+1), hl
	;
	ld	hl, DPCMTurboLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), DPCMTurboLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), DPCMTurboLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; DPCM Turbo: VBlank loop (playback only)
; --------------------------------------------------------------

DPCMTurboLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 21 cycles
	exx						; 4
	ld	a, 00h					; 7
	jp	DPCMTurboLoop_VBlankPhase.FetchWindow	; 10

; --------------------------------------------------------------
DPCMTurboLoop_VBlank:
	push	af
	push	bc

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 144 samples to survive VBlank.
	ld	b, 144-2

; --------------------------------------------------------------
DPCMTurboLoop_VBlankPhase:
	; Handle sample playback in draining mode
	PlaybackTurbo_Run_Draining	c, DPCMTurboLoop_VBlank_Loop_DrainDoneSync_EXX	; 41/20	playback one sample

.FetchWindow:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 74 + 3* cycles
	push	bc					; 11
	pop	bc					; 10
	push	hl					; 11
	add	hl, hl					; 11
	add	hl, hl					; 11
	pop	hl					; 10
	djnz	DPCMTurboLoop_VBlankPhase		; 13/8
	; Total "DPCMTurboLoop_VBlankPhase" cycles: 135 + 3*
	; *) emulated lost cycles on M68K bus access on average

.LastIteration:
	; Handle sample playback in the last iteration
	PlaybackTurbo_Run_Draining_NoSync	c	; 41/24

	rst	ProcessCommandInput			; 11+22	returns a=0 once driver input is processed

	ld	a, 0					; 4 	a=0
	ld	(VBlankActive), a			; 13	report we're out of VBlank

	ld	bc, 0					; 10
	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10
