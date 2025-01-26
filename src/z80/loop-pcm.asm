
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; PCM loop module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSampleInput` structure
; --------------------------------------------------------------

PCMLoop:
	di

	TraceMsg "Entering PCMLoop"

	ld	a, LOOP_PCM
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, PCMLoop_VBlank
	ld	(VBlankRoutine), hl

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`
	ld	ix, ActiveSample

; --------------------------------------------------------------
PCMLoop_Reload:

	; Set initial ROM bank ...
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	di							; 4

	; Init read ahead registers ...
	ld	hl, (ActiveSample+sActiveSample.startOffset)	; 16
	ld	bc, (ActiveSample+sActiveSample.startLength)	; 20
	ld	de, SampleBuffer				; 10

	; Init playback registers ...
	Playback_Init_DI	SampleBuffer			; 106

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4

	; NOTE: Interrupts may still be disabled here because EI's effect
	; isn't immediate. We must make sure the next instruction following
	; EI *isn't* DI, otherwise it won't enable interrupts at all.
	nop							; 4

; --------------------------------------------------------------
; PCM: Normal playback phase (readahead & playback)
; --------------------------------------------------------------
; Registers:
;	bc	= Remaining length in ROM bank
;	de 	= Sample buffer pos (read-ahead)
;	hl	= ROM pos
; --------------------------------------------------------------

PCMLoop_NormalPhase_NoCycleStealing:
	ld	a, 0h						; +7*	used as entry point to the loop for poor emulators
								;	... that don't emulate cycle-stealing

PCMLoop_NormalPhase:
	; Handle "read-ahead" buffer
	di							; 4
	ldi							; 16+3.3*
	ldi							; 16+3.3*
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, .ReadAheadExhausted_DI			; 10	if bc != 0, branch (WARNING: this requires everything to be word-aligned)

	; Handle playback
.Playback_DI:
	Playback_Run_DI						; 60-61	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	Playback_ChkReadaheadOk	e, d, PCMLoop_NormalPhase	; 18
	; Total "PCMLoop_NormalPhase" cycles: 135-136 + 6.6*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	; Waste 53+7* cycles (we cannot handle "read-ahead" now)
	push	af						; 11
	ld	a, 00h						; 7
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	pop	af						; 10
	di							; 4
	jr	.Playback_DI					; 12

; --------------------------------------------------------------
.ReadAheadExhausted_DI:
	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4

	; Are we done playing?
	ld	a, (CurrentBank)				; 13
	cp	(ix+sActiveSample.endBank)			; 19	current bank is the last one?
	jr	nz, PCMLoop_NormalPhase_LoadNextBank		; 7/12	if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; PCM: Draining phase (playback only)
; --------------------------------------------------------------

PCMLoop_DrainPhase:
	; Handle playback in draining mode
	di								; 4
	Playback_Run_Draining	e, .Drained_EXX_DI			; 71-72
	ei								; 4

	; Waste 56+7* cycles (instead of handling readahead)
	push	bc							; 11
	inc	bc							; 6
	inc	bc							; 6
	inc	bc							; 6
	inc	bc							; 6
	inc	bc							; 6
	pop	bc							; 10
	jr	PCMLoop_DrainPhase					; 12
	; Total "PCMLoop_DrainPhase" cycles: 135-136 + 7*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.Drained_EXX_DI:
	exx

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei

	bit	FLAGS_LOOP, (ix+sActiveSample.flags)	; is sample set to loop?
	jp	nz, PCMLoop_Reload			; re-enter playback loop

	; Return from the playback loop
	ret

; --------------------------------------------------------------
PCMLoop_NormalPhase_LoadNextBank:
	; Prepare next bank id
	ld	a, (CurrentBank)
	inc	a

	; Setup sample source and length
	ld	hl, ROMWindow			; hl = 8000h (alt: ld h, ROMWindow<<8)
	ld	b, h				; bc = 8000h (alt: ld b, 80h)
	cp	(ix+sActiveSample.endBank)	; current bank is the last one?
	jr	nz, .lengh_ok			; if not, branch
	ld	bc, (ActiveSample+sActiveSample.endLength)
.lengh_ok:

	; Switch to the next ROM bank
	rst	SetBank2

	; Jump back to playback loop where we left off...
	di
	jp	PCMLoop_NormalPhase.Playback_DI

; --------------------------------------------------------------
; PCM: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is called when finishing `CalibrationLoop`, only
; if calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

PCMLoop_ApplyCalibration:
	ld	hl, PCMLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), PCMLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), PCMLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; PCM: VBlank phase (playback only)
; --------------------------------------------------------------

PCMLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 48 cycles
	exx						; 4
	nop						; 4
	inc	bc					; 6
	dec	bc					; 6
	inc	bc					; 6
	dec	bc					; 6
	nop						; 4
	jr	PCMLoop_VBlankPhase_Sync		; 12

; --------------------------------------------------------------
PCMLoop_VBlank:
	push	af
	push	bc

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 144 samples to survive VBlank.
	ld	b, 144-3+1

; --------------------------------------------------------------
PCMLoop_VBlankPhase:
	; Handle sample playback in draining mode
	Playback_Run_Draining	e, PCMLoop_VBlank_Loop_DrainDoneSync_EXX	; 71-72/24	playback one sample

PCMLoop_VBlankPhase_Sync:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 44 + 7* cycles
	push	hl					; 11
	inc	hl					; 6
	add	hl, hl					; 11
	pop	hl					; 10
	djnz	PCMLoop_VBlankPhase			; 13/8
	; Total "PCMLoop_VBlankPhase" cycles: 135-136 + 7*
	; *) emulated lost cycles on M68K bus access

; --------------------------------------------------------------
PCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback and reload volume
	Playback_Run_Draining_NoSync	e		; 71-72/28
	exx						; 4
	Playback_LoadVolume_EXX				; 45
	exx						; 4
	nop						; 4
	; WARNING! This should've wasted 1 more cycle!

	; Handle sample playback and reload pitch
	Playback_Run_Draining_NoSync	e		; 71-72/28
	Playback_LoadPitch				; 21	reload pitch

	rst	ProcessCommandInput			; 11+22	returns a=0 once driver input is processed

	; Slightly early, but report we're out of VBlank
	; TODO: assert a=0
	ld	(VBlankActive), a			; 13

	; Handle sample playback one last time
	Playback_Run_Draining_NoSync	e		; 71-72/28

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10
