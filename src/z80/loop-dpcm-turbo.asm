
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.2
; --------------------------------------------------------------
; Turbo DPCM loop module
;
; (c) 2023-2026, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSample` structure
; --------------------------------------------------------------

DPCMTurboLoop:	; Classic DPCM (Turbo mode)
	di

	TraceMsg "Entering DPCMTurboLoop"

	ld	a, LOOP_DPCM_TURBO
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, DPCMTurboLoop_VBlank
	ld	(VBlankRoutine), hl

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Load DPCM delta table #0
	ld	hl, DPCM_DeltaTable_0
	call	LoadDPCMTable2_DI		; NOTE: This trashes *all* registers, so we have to do it after `LoadActiveSampleData_DI`

	jp	DPCMTurboLoop_Cont

; --------------------------------------------------------------
DPCMHQTurboLoop:	; DPCM-HQ (Turbo mode)
	di

	TraceMsg "Entering DPCMHQTurboLoop"

	ld	a, LOOP_DPCM_HQ_TURBO
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, DPCMTurboLoop_VBlank
	ld	(VBlankRoutine), hl

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Set initial ROM bank (required for reading the header)
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	; Load DPCM delta table based on last byte from the header (read back to header)
	ld	hl, (ActiveSample+sActiveSample.startOffset)
	dec	l				; move back to read last byte of the header (we're sure this won't cross the bank boundary or even 256-byte boundary)
	ld	a, (hl)				; a = Delta table index * 10h
	call	LoadDPCMTable_DI		; NOTE: This trashes *all* registers, so we have to do it after `LoadActiveSampleData_DI`
	; fallthrough

; --------------------------------------------------------------
DPCMTurboLoop_Cont:
	ld	ix, ActiveSample

DPCMTurboLoop_Reload_DI:
	; Init playback registers ...
	PlaybackDPCMTurbo_Init_DI	SampleBuffer, DPCMTables

	; Init read ahead registers ...
	ld	de, SampleBuffer

	ld	hl, (ActiveSample+sActiveSample.startOffset)
	ld	bc, (ActiveSample+sActiveSample.startLength)

	; Set initial ROM bank ...
	ei
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

; --------------------------------------------------------------
; DPCM Turbo: Main playback loop (readahead & playback)
; --------------------------------------------------------------
; Registers:
;	a'	= Current sample (decoded)
;	bc	= Remaining length in ROM bank
;	de 	= Sample buffer pos (read-ahead)
;	hl	= ROM pos
;	bc' 	= YM Port 0 Data
;	d'	= DPCM Decode Table base
;	e'	= DPCM byte
;	hl`	= Sample buffer pos (playback)
; --------------------------------------------------------------

	; Initial buffer fill
	ldi							; 16+3.3*
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, DPCMTurboLoop_NormalPhase.ReadAheadExhausted_DI ; 10	if bc == 0, branch


DPCMTurboLoop_NormalPhase_NoCycleStealing:
	ld	a, 0h						; +7*	used as entry point to the loop for poor emulators
								;	... that don't emulate cycle-stealing

DPCMTurboLoop_NormalPhase:
	; Decode and play Nibble 0 from `SampleBuffer`
	di							; 4
	PlaybackDPCMTurbo_Run_Nibble0_DI			; 41	af <=> af', de' <=> hl'

	; WARNING! Do not enable interrupts between Nibble 0 and Nibble 1 playback

	; Fill "read ahead" buffer (2 bytes)
	ldi							; 16+3.3*
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, .ReadAheadExhausted_DI			; 10	if bc == 0, branch
	ldi							; 16+3.3*
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, .ReadAheadExhausted_DI			; 10	if bc == 0, branch

.Playback_Nibble1_DI:
	; Decode and play nibble 1 from the sample buffer
	PlaybackDPCMTurbo_Run_Nibble1_EXAF_DI			; 42	af <=> af', de' <=> hl'

	; WARNING! Make sure no more than 170 cycles have passed since interrupts were disabled
	ei							; 4
	PlaybackDPCMTurbo_ChkReadaheadOk	e, d, DPCMTurboLoop_NormalPhase	; 18

	; Total "DPCMTurboLoop_NormalPhase" cycles: ~175 + 7*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	; Spend 111 + 7* cycles here in total (we cannot handle "read-ahead" now)

	; Sync block (pre playback)
	nop							; 4
	nop							; 4
	di							; 4

	; Decode and play nibble 0 from the sample buffer
	PlaybackDPCMTurbo_Run_Nibble0_DI			; 41	af <=> af', de' <=> hl'

	; Sync block (post-playback)
	push	af						; 11
	pop	af						; 10
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	nop							; 4
	jr	.Playback_Nibble1_DI				; 12

; --------------------------------------------------------------
.ReadAheadExhausted_DI:
	; Decode and play nibble 1 from the sample buffer
	PlaybackDPCMTurbo_Run_Nibble1_EXAF_DI			; 42	af <=> af', de' <=> hl'
	; Can use `af` now

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4
	ld	d, SampleBuffer>>8				; 7	fix after `ldi`

	; Are we done playing?
	ld	a, (CurrentBank)
	cp	(ix+sActiveSample.endBank)			; current bank is the last one?
	jr	nz, DPCMTurboLoop_NormalPhase_LoadNextBank	; if not, branch

; --------------------------------------------------------------
; DPCM Turbo: Draining loop (playback only)
; --------------------------------------------------------------

DPCMTurboLoop_DrainPhase:
	di							; 4
	
	; Decode and play nibble 0 from the sample buffer + drain check
	PlaybackDPCMTurbo_Run_Draining_Nibble0	e, .Drained_EXX_DI	; 60/24

	; Waste 36 cycles
	; WARNING! Do not enable interrupts between Nibble 0 and Nibble 1 playback
	nop							; 4
	push	hl						; 11
	add	hl, hl						; 11	WARNING! Trashes `f`
	pop	hl						; 10

	; Decode and play nibble 1 from the sample buffer
	PlaybackDPCMTurbo_Run_Draining_Nibble1			; 42

	; Waste 40 cycles
	ei							; 4
	inc	hl						; 6
	dec	hl						; 6
	inc	hl						; 6
	dec	hl						; 6
	jr	DPCMTurboLoop_DrainPhase			; 12
	; Total "DPCMTurboLoop_DrainPhase" cycles: 175 + 7*
	; *) additional cycles lost due to M68K bus access on average


; --------------------------------------------------------------
.Drained_EXX_DI:
	exx

	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei

	; Are we looping?
	bit	FLAGS_LOOP, (ix+sActiveSample.flags)		; is sample set to loop?
	ret	z						; if not, return
	; NOTE: `WaitVBlankEnd` auto-disables interrupts after execution
	call	WaitVBlankEnd					; we must wait until start of next frame
	jp	DPCMTurboLoop_Reload_DI				; re-enter playback loop

; --------------------------------------------------------------
DPCMTurboLoop_NormalPhase_LoadNextBank:
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
	; TODO: Make sure lack of "readahead buffer full" check won't cause issues (it shouldn't)
	jp	DPCMTurboLoop_NormalPhase

; --------------------------------------------------------------
; DPCM Turbo: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is when finishing `CalibrationLoop`, only if
; calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

DPCMTurboLoop_ApplyCalibration:
	ld	hl, DPCMTurboLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), DPCMTurboLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), DPCMTurboLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; DPCM Turbo: VBlank loop (playback only)
; --------------------------------------------------------------

DPCMTurboLoop_VBlank_Loop_Drained_EXX:
	; Waste 127 cycles
	exx						; 4
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13
	push	bc					; 11
	ld	b, 4					; 7
	djnz	$					; 49 (13*3 + 10)
	nop						; 4
	nop						; 4
	pop	bc					; 10
	inc	hl					; 6	 WARNING! Matches `dec hl` below
	jp	DPCMTurboLoop_VBlankPhase.DrainSynced	; 12

; --------------------------------------------------------------
DPCMTurboLoop_VBlank:
	push	af
	push	bc

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 240 samples to survive VBlank.
	ld	b, 240/2-1+1	; FIXME: Check this number

; --------------------------------------------------------------
DPCMTurboLoop_VBlankPhase:
	; Play nibble 0 in Draining mode
	PlaybackDPCMTurbo_Run_Draining_Nibble0	e, DPCMTurboLoop_VBlank_Loop_Drained_EXX	; 60/24

	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 29 cycles
	nop						; 4
	cp	(ix+0)					; 19
	inc	hl					; 6	 WARNING! Matches `dec hl` below

	; Play nibble 1 in Draining mode
	PlaybackDPCMTurbo_Run_Draining_Nibble1		; 42

.DrainSynced:
	; Waste 31 cycles
	dec	hl					; 6	 WARNING! Must be incremented above
	inc	hl					; 6
	dec	hl					; 6
	djnz	DPCMTurboLoop_VBlankPhase		; 13/8
	; Total "DPCMTurboLoop_VBlankPhase" cycles: 175 + 7*
	; *) emulated lost cycles on M68K bus access on average

.LastIteration:
	rst	ProcessCommandInput			; 11+22	returns a=0 once driver input is processed
	ld	(VBlankActive), a			; 13	report we're out of VBlank

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10
