
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.1
; --------------------------------------------------------------
; DPCM loop module
;
; (c) 2023-2026, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSample` structure
; --------------------------------------------------------------

DPCM0Loop:	; Classic DPCM / DPCM-HQ Table #0
	di

	TraceMsg "Entering DPCM0Loop"

	ld	a, LOOP_DPCM
	ld	(LoopId), a

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Load DPCM delta table #0
	ld	hl, DPCM_DeltaTable_0
	call	LoadDPCMTable_DI		; NOTE: This trashes *all* registers, so we have to do it after `LoadActiveSampleData_DI`

	jp	DPCMLoop_Cont

; --------------------------------------------------------------
DPCM1Loop:	; DPCM-HQ Table #1
	di

	TraceMsg "Entering DPCM1Loop"

	ld	a, LOOP_DPCM
	ld	(LoopId), a

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Load DPCM delta table #1
	ld	hl, DPCM_DeltaTable_1
	call	LoadDPCMTable_DI		; NOTE: This trashes *all* registers, so we have to do it after `LoadActiveSampleData_DI`
	; fallthrough

; --------------------------------------------------------------
DPCMLoop_Cont:
	; Setup VInt ...
	ld	hl, DPCMLoop_VBlank
	ld	(VBlankRoutine), hl

; --------------------------------------------------------------
DPCMLoop_Reload:

	; Set initial ROM bank ...
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	di

	; Init read ahead registers ...
	ld	bc, SampleBuffer
	ld	h, DPCMTables>>8
	ld	de, (ActiveSample+sActiveSample.startOffset)
	ld	ix, (ActiveSample+sActiveSample.startLength)
	; TODO: Do this in `LoadActiveSampleData_DI` (create DPCM-specific version)
	; or in `MegaPCM_LoadSampleTable` on 68k side.
	dec	ix				; ix = Remaining length in ROM bank - 1
	inc	ixl				; ixl = Remaining length in ROM bank - 1 (LOW) + 1

	; Init playback registers ...
	Playback_Init_DI	SampleBuffer

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
;	ixl	= Remaining length in ROM bank - 1 (LOW) + 1
;	ixh	= Remaining length in ROM bank - 1 (HIGH)
; --------------------------------------------------------------

DPCMLoop_NormalPhase_NoCycleStealing:
	nop					; +4*	used as entry point to the loop for poor emulators
						;	... that don't emulate cycle-stealing

DPCMLoop_NormalPhase:
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
	dec	ixl				; 8	decrement sample length
	jr	z, .ChkReadAheadExhausted_DI	; 7/12	if borrow from a high byte, branch
	; Total cycles: 87

	; Handle playback
.Playback_DI:
	Playback_Run_DI2					; 60-61	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	; NOTE: "sample buffer pos" (`bc`) always lags 1 sample behind
	; as an optimization (because DPCM decoder re-fetches last sample),
	; so `ChkReadaheadOk` check thinks read ahead buffer is full
	; 1 sample early, but this isn't a big deal for us, since buffer
	; is 256 samples large anyways.
	Playback_ChkReadaheadOk	c, b, DPCMLoop_NormalPhase	; 18
	; Total cycles: 82-83

	; Total "DPCMLoop_NormalPhase" cycles: ~169-170 + 3.3*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	; Waste 87 + 3* cycles (we cannot handle "read-ahead" now)
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	hl						; 11
	add	hl, bc						; 11
	pop	hl						; 10
	di							; 4
	jr	.Playback_DI					; 12

; --------------------------------------------------------------
.ChkReadAheadExhausted_DI:
	dec	ixh				; 8	decrement high byte of length
	jp	p, .Playback_DI			; 10	if no borrow, back to playback

.ReadAheadExhausted_DI:
	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4

	; Are we done playing?
	ld	a, (CurrentBank)				; 13
	ld	hl, ActiveSample+sActiveSample.endBank		; 10
	cp	(hl)						; 7	current bank is the last one?
	jr	nz, DPCMLoop_NormalPhase_LoadNextBank		; 7/12	if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; DPCM: Draining loop (playback only)
; --------------------------------------------------------------

DPCMLoop_DrainPhase:
	; Handle playback in draining mode
	di							; 4
	; NOTE: We correct "sample buffer pos" pointer here (`bc`)
	; As an optimization, in the normal phase loop (`DPCMLoop_NormalPhase`)
	; "sample buffer pos" points to the start of the last sample, not the
	; next sample to write (because DPCM decoder needs to re-fetch it)
	; Why can't we do this correction permanently when reaching drain phase?
	; Because VBlank also does the same correction and applying it twice
	; may break it.
	inc	c						; 4	correct `bc` pointer
	Playback_Run_Draining	c, .Drained_EXX_DI		; 71-72
	dec	c						; 4	undo `bc` pointer correction
	ei							; 4

	; Waste 82 + 3* cycles
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	hl						; 11
	ld	hl, 0						; 10
	pop	hl						; 10
	jr	DPCMLoop_DrainPhase				; 12
	; Total "DPCMLoop_DrainPhase" cycles: ~169-170 + 3*
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
	jp	nz, DPCMLoop_Reload			; re-enter playback loop

	; Return from the playback loop
	ret

; --------------------------------------------------------------
DPCMLoop_NormalPhase_LoadNextBank:
	; Prepare next bank id
	inc	a

	; Setup sample source and length
	ld	de, ROMWindow			; de = 8000h (alt: ld b, ROMWindow<<8)
	ld	ix, 7F00h			; ix = 7F00h (7Fh+0, 0FFh+1)
	cp	(hl)				; current bank is the last one?
	jr	nz, .length_ok			; if not, branch
	ld	ix, (ActiveSample+sActiveSample.endLength)
	dec	ix				; ix = Remaining length in ROM bank - 1
	inc	ixl				; ixl = Remaining length in ROM bank - 1 (LOW) + 1
.length_ok:
	ld	h, DPCMTables>>8

	; Switch to the next ROM bank
	rst	SetBank2

	; Jump back to playback loop where we left off...
	di
	jp	DPCMLoop_NormalPhase.Playback_DI

; --------------------------------------------------------------
; DPCM: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is when finishing `CalibrationLoop`, only if
; calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

DPCMLoop_ApplyCalibration:
	ld	hl, DPCMLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), DPCMLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), DPCMLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; DPCM: VBlank loop (playback only)
; --------------------------------------------------------------

DPCMLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 48 cycles
	exx						; 4
	nop						; 4
	inc	bc					; 6
	dec	bc					; 6
	inc	bc					; 6
	dec	bc					; 6
	nop						; 4
	jr	DPCMLoop_VBlankPhase_Sync		; 12

; --------------------------------------------------------------
DPCMLoop_VBlank:
	push	af
	push	bc
	inc	c					; correct "read ahead" pointer (see comment on previous `inc c` instruction)

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 116 samples to survive VBlank.
	ld	b, 116-2

; --------------------------------------------------------------
DPCMLoop_VBlankPhase:
	; Handle sample playback in draining mode
	Playback_Run_Draining	c, DPCMLoop_VBlank_Loop_DrainDoneSync_EXX	; 71-72/24	playback one sample

DPCMLoop_VBlankPhase_Sync:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 78 + 3* cycles
	push	bc					; 11
	pop	bc					; 10
	push	hl					; 11
	add	hl, hl					; 11
	add	hl, hl					; 11
	pop	hl					; 10
	nop						; 4
	djnz	DPCMLoop_VBlankPhase			; 13/8
	; Total "DPCMLoop_VBlankPhase" cycles: 169-170 + 3*
	; *) emulated lost cycles on M68K bus access on average

; --------------------------------------------------------------
DPCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback and reload volume
	Playback_Run_Draining_NoSync	c		; 71-72/28
	exx						; 4
	Playback_LoadVolume_EXX				; 45
	exx						; 4
	Playback_LoadPitch				; 21	reload pitch

	rst	ProcessCommandInput			; 11+22	returns a=0 once driver input is processed

	; Handle sample playback one last time
	Playback_Run_Draining_NoSync	c		; 71-72/28

	; Report we're out of VBlank
	xor	a
	ld	(VBlankActive), a			; 13

	pop	bc					; 10	also undoes "read ahead" pointer correction
	pop	af					; 10
	ei						; 4
	ret						; 10
