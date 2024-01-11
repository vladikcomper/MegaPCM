
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

PCMLoop_Init:
	di

	TraceMsg "Entering PCMLoop"

	ld	a, LOOP_PCM
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, PCMLoop_VBlank
	ld	(VBlankRoutine), hl

	ld	(StackCopy), sp			; backup stack

	; Fetch input sample data (see `sSampleInput` struct) ...
	; TODO: Disable sample input?
	ld	sp, ix				; load sample in the stack
	inc	sp				; skip type
	pop	af				; a = pitch, f = flags
	pop	bc				; c = startBank
						; b = endBank
	pop	hl				; hl = start offset (first bank)
	pop	de				; de = end offset (last bank)

	; Initialize active sample playback parameters (see `sActiveSample`) ...
	ld	sp, ActiveSample+sActiveSample
	push	af				; (ActiveSample+sActiveSample.pitch) = a
						; (ActiveSample+sActiveSample.flags) = f
	ex	af, af'

	set	7, h				; make sure hl points to ROM bank
	res	0, l				; hl = start offset & 0FFFEh
	push	hl				; (ActiveSample+sActiveSample.startOffset) = hl

	ld	a, d
	and	7Fh
	ld	d, a				; de = end offset & 7FFFh
	res	0, e				; de = end offset & 7FFEh
	or	e				; (de & 7FFEh) == 0?
	jr	nz, .lengthOk
	dec	b				; b = endBank - 1 (use previous bank)
	ld	d, 80h				; de = 8000h (use max end length)
.lengthOk:
	; WARNING! This value is incorrect for single-bank samples; luckily, it's ignored
	push	de				; (ActiveSample+sActiveSample.endLength) = de

	ld	a, b				; a = endBank
	cp	c				; endBank == startBank?
	jr	nz, .isMultibank		; if not, branch
	jp	c, StopSamplePlayback		; if endBank < startBank, abort playback
	res	7, h
	ex	de, hl				; hl = end length, de = start length
	sbc	hl, de				; hl = length
	jp	.setFirstBankLen

.isMultibank:
	; Implements: de = 10000h - hl, or simply de = -hl
	xor	a				; a = 0
	sub	l				; a = 0 - l
	ld	e, a				; e = 0 - l
	sbc	h				; a = 0 - h - l - carry
	add	l				; a = 0 - h - carry
	ld	d, a				; d = 0 - h - carry
	ex	de, hl

.setFirstBankLen:
	push	hl				; (ActiveSample+sActiveSample.startLength) = hl
	push	bc				; (ActiveSample+sActiveSample.startBank) = c
						; (ActiveSample+sActiveSample.endBank) = b

	assert FLAGS_SFX==0			; we need this assertion to ensure trick below works

	ld	hl, VolumeInput			; hl = VolumeInput
	ex	af, af'				; a = pitch, f = flags
	jr	nc, .setVolumeInputPtr		; Carry = FLAGS_SFX
	inc	l				; hl = SFXVolumeInput
.setVolumeInputPtr:
	push	hl				; (ActiveSample+sActiveSample.volumeInputPtr) = hl

	ld	sp, (StackCopy)			; restore stack
	ld	ix, ActiveSample

	; Setup YM for DAC playback
	ld	iy, YM_Port0_Reg
	xor	a
	ld	(DriverReady), a		; cannot interrupt driver now ...
	ld	(iy+0), 2Bh			; YM => Enable DAC
	ld	(iy+1), 80h			; ''
	ld	a, (ActiveSample+sActiveSample.flags)	; load flags
	and	0C0h				; are pan bits set?
	jr	z, .panDone			; if not, branch
        ld	(iy+2), 0B6h			; YM => Set Pan
	ld	(iy+3), a			; ''
.panDone:
	ld	a, 'R'
	ld	(DriverReady), a		; ready to fetch inputs now
	ld	(iy+0), 2Ah			; setup YM to fetch DAC bytes

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
	Playback_Init_DI	SampleBuffer			; 112

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
; PCM: Main playback loop (readahead & playback)
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
	TraceMsg "PCMLoop_NormalPhase iteration"

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
	Playback_ChkReadaheadOk	e, PCMLoop_NormalPhase		; 21
	; Total "PCMLoop_NormalPhase" cycles: 138-139 + 6.6*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	TraceMsg "PCMLoop_NormalPhase_ReadAheadFull iteration"

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
; PCM: Draining loop (playback only)
; --------------------------------------------------------------

PCMLoop_DrainPhase:
	TraceMsg "PCMLoop_DrainPhase iteration"

	; Handle playback in draining mode
	di								; 4
	Playback_Run_Draining	e, .Drained_EXX_DI			; 71-72
	ei								; 4

	; Waste 59+7* cycles (instead of handling readahead)
	push	af							; 11
	inc	bc							; 6
	pop	af							; 10
	push	af							; 11
	dec	bc							; 6
	pop	af							; 10
	jr	PCMLoop_DrainPhase					; 12
	; Total "PCMLoop_DrainPhase" cycles: 138-139 + 7*
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

	; Back to idle loop
	jp	IdleLoop_Init

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

	; Ready to continue playback!
	jp	PCMLoop_NormalPhase

; --------------------------------------------------------------
; PCM: Apply calibration for inaccurate emulators
; --------------------------------------------------------------
; NOTE: This is when finishing `CalibrationLoop`, only if
; calibration is required. Calibration cannot be reverted.
; --------------------------------------------------------------

PCMLoop_ApplyCalibration:
	ld	hl, PCMLoop_NormalPhase.chkReadahead_sm1+1
	ld	(hl), PCMLoop_NormalPhase_NoCycleStealing&0FFh
	inc	hl
	ld	(hl), PCMLoop_NormalPhase_NoCycleStealing>>8
	ret

; --------------------------------------------------------------
; PCM: VBlank loop (playback only)
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
	TraceMsg "PCMLoop_VBlankPhase iteration"

	; Handle sample playback in draining mode
	Playback_Run_Draining	e, PCMLoop_VBlank_Loop_DrainDoneSync_EXX	; 71-72/24	playback one sample

PCMLoop_VBlankPhase_Sync:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 47 + 7* cycles
	push	bc					; 11
	ld	(VBlankActive), a			; 13	wasteful write
	ld	a, 00h					; 7*	emulate M68K bus access delay
	pop	bc					; 10
	djnz	PCMLoop_VBlankPhase			; 13/8
	; Total "PCMLoop_VBlankPhase" cycles: 138-139 + 7*
	; *) emulated lost cycles on M68K bus access

; --------------------------------------------------------------
PCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback and reload volume
	Playback_Run_Draining_NoSync	e		; 71-72/28
	nop						; 4
	exx						; 4
	Playback_LoadVolume_EXX				; 51
	exx						; 4
	nop						; 4

	; Handle sample playback and reload pitch
	Playback_Run_Draining_NoSync	e		; 71-72/28
	Playback_LoadPitch				; 21	reload pitch

PCMLoop_VBlankPhase_CheckCommandOrSample:
	ld	a, (CommandInput)			; 13	a = command
	or	a					; 4	is command > 00h?
	jr	z, .ChkCommandOrSample_Done		; 7/12	if not, branch
	jp	p, .ChkCommandOrSample_Command		;	if command = 01..7Fh, branch

	; Only low-priority samples can be overriden
	bit	FLAGS_SFX, (ix+sActiveSample.flags)	; is sample high priority?
	jp	z, RequestSamplePlayback		; if not, branch

.ChkCommandOrSample_ResetInput:
	; Reset command
	xor	a
	ld	(CommandInput), a

.ChkCommandOrSample_Done:
	; Slightly early, but report we're out of VBlank
	ld	(VBlankActive), a			; 13
	nop						; 4

	; Handle sample playback one last time
	Playback_Run_Draining_NoSync	e		; 71-72/28

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10

; --------------------------------------------------------------
.ChkCommandOrSample_Command:
	dec	a					; is command 01h (`COMMAND_STOP`)?
	jp	z, StopSamplePlayback			; if yes, branch
	dec	a					; is command 02h (`COMMAND_PAUSE`)?
	jr	nz, .UnkownCommand			; if yes, branch

.PausePlayback:
	; There's a trick to it: While the "pause command" is set,
	; we reset sample pitch to 0, cancelling pitch reload above.
	; As soon as this command is unset, the pitch reload will restore it.
	Playback_ResetPitch				; set pitch to 00h
	jr	.ChkCommandOrSample_Done

; --------------------------------------------------------------
.UnkownCommand:
	TraceException	"Uknown command"
	ld	a, ERROR__UNKNOWN_COMMAND
	ld	(LastErrorCode), a
	jr	.ChkCommandOrSample_ResetInput
