
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Turbo PCM loop module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSampleInput` structure
; --------------------------------------------------------------

PCMTurboLoop:
	di

	TraceMsg "Entering PCMTurboLoop"

	ld	a, LOOP_PCM_TURBO
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, PCMTurboLoop_VBlank
	ld	(VBlankRoutine), hl

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`
	ld	ix, ActiveSample

; --------------------------------------------------------------
PCMTurboLoop_Reload:

	; Set initial ROM bank ...
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	di

	; Init read ahead registers ...
	ld	de, SampleBuffer
	ld	hl, (ActiveSample+sActiveSample.startOffset)
	ld	bc, (ActiveSample+sActiveSample.startLength)

	; Init playback registers ...
	PlaybackTurbo_Init_DI	SampleBuffer


; --------------------------------------------------------------
; PCM-Turbo: Main playback loop (readahead & playback)
; --------------------------------------------------------------
; Registers:
;	bc	= Remaining length in ROM bank
;	de 	= Sample buffer pos (read-ahead)
;	hl	= ROM pos
; --------------------------------------------------------------

PCMTurboLoop_NormalPhase_NoCycleStealing:
	ld	a, 0h						; +7*	used as entry point to the loop for poor emulators
								;	... that don't emulate cycle-stealing

PCMTurboLoop_NormalPhase:
	; Fill read-ahead buffer
	di							; 4
	ldi							; 16+3.3*
	ldi							; 16+3.3*
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, .ReadAheadExhausted_DI			; 10	if bc == 0, branch (WARNING: this requires everything to be word-aligned)

	; Handle playback
.Playback_DI:
	PlaybackTurbo_Run_DI					; 30	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	PlaybackTurbo_ChkReadaheadOk	e, d, PCMTurboLoop_NormalPhase	; 18
	; Total "PCMTurboLoop_NormalPhase" cycles: 105+*
	; *) additional cycles lost due to M68K bus access	

; --------------------------------------------------------------
.ReadAheadFull:
	; Waste 53 + 7* cycles (we cannot handle "read-ahead" now)
	push	hl						; 11
	inc	hl						; 6
	inc	hl						; 6
	add	hl, bc						; 11
	pop	hl						; 10
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
	ld	a, (CurrentBank)
	cp	(ix+sActiveSample.endBank)			; current bank is the last one?
	jr	nz, PCMTurboLoop_NormalPhase_LoadNextBank	; if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; PCM-Turbo: Draining loop (playback only)
; --------------------------------------------------------------

PCMTurboLoop_DrainPhase:
	; Handle playback in draining mode
	di							; 4
	PlaybackTurbo_Run_Draining	e, .Drained_EXX_DI	; 41/20
	ei							; 4

	; Waste 56+7* cycles (instead of handling readahead)
	push	hl						; 11
	push	bc						; 11
	add	hl, bc						; 11
	pop	bc						; 10
	pop	hl						; 10
	jp	PCMTurboLoop_DrainPhase				; 10
	; Total "PCMTurboLoop_DrainPhase" cycles: 105+*
	; *) additional cycles lost due to M68K bus access	

; --------------------------------------------------------------
.Drained_EXX_DI:
	exx

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei

	bit	FLAGS_LOOP, (ix+sActiveSample.flags)		; is sample set to loop?
	jp	nz, PCMTurboLoop_Reload				; re-enter playback loop

	; Return from the playback loop
	ret

; --------------------------------------------------------------
PCMTurboLoop_NormalPhase_LoadNextBank:
	; Prepare next bank id
	ld	a, (CurrentBank)
	inc	a

	; Setup sample source and length
	ld	hl, ROMWindow			; hl = 8000h (alt: ld h, ROMWindow<<8)
	ld	b, h				; bc = 8000h (alt: ld b, 80h)
	cp	(ix+sActiveSample.endBank)	; current bank is the last one?
	jr	nz, .length_ok			; if not, branch
	ld	bc, (ActiveSample+sActiveSample.endLength)
.length_ok:

	; Switch to the next ROM bank
	rst	SetBank2

	; Jump back to playback loop where we left off...
	di
	jp	PCMTurboLoop_NormalPhase.Playback_DI

; --------------------------------------------------------------
; PCM-Turbo: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is when finishing `CalibrationLoop`, only if
; calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

PCMTurboLoop_ApplyCalibration:
	ld	hl, PCMTurboLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), PCMTurboLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), PCMTurboLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; PCM-Turbo: VBlank loop (playback only)
; --------------------------------------------------------------

PCMTurboLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 21 cycles
	exx						; 4
	ld	a, 00h					; 7
	jp	PCMTurboLoop_VBlankPhase.FetchWindow	; 10

; --------------------------------------------------------------
PCMTurboLoop_VBlank:
	push	af
	push	bc

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 191 samples to survive VBlank.
	ld	b, 191-1+1

; --------------------------------------------------------------
PCMTurboLoop_VBlankPhase:
	; Handle sample playback in draining mode
	PlaybackTurbo_Run_Draining	e, PCMTurboLoop_VBlank_Loop_DrainDoneSync_EXX	; 41/20

.FetchWindow:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 44 + 7* cycles (simulate fetching samples)
	ld	a, 00h					; 7*	emulate M68K bus access delay
	push	bc					; 11
	ld	bc, 00h					; 10
	pop	bc					; 10
	djnz	PCMTurboLoop_VBlankPhase		; 8/13
	; Total "PCMTurboLoop_VBlankPhase" cycles: 105 + 7*
	; *) emulated lost cycles on M68K bus access

.LastIteration:
	; Handle sample playback in the last iteration
	nop						; 4
	PlaybackTurbo_Run_Draining_NoSync	e	; 41/24

	rst	ProcessCommandInput			; 11+22	returns a=0 once driver input is processed

	; TODO: assert a=0
	ld	(VBlankActive), a			; 13	report we're out of VBlank

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10
