
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Tubro PCM loop module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSampleInput` structure
; --------------------------------------------------------------

PCMTurboLoop_Init:
	di

	TraceMsg "Entering PCMTurboLoop"

	ld	a, LOOP_PCM_TURBO
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, PCMTurboLoop_VBlank
	ld	(VBlankRoutine), hl

	; 
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
	jp	c, IdleLoop_Init		; if endBank < startBank, abort playback
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
; PCM-Tubro: Main playback loop (readahead & playback)
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
	TraceMsg "PCMTurboLoop_NormalPhase iteration"

	; Fill read-ahead buffer
	di							; 4
	ldi							; 16+*
	ldi							; 16+*
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
	TraceMsg "PCMTurboLoop_NormalPhase_ReadAheadFull iteration"

	; Waste 53 cycles (we cannot handle "read-ahead" now)
	ld	a, (ROMWindow)					; 13+*	idle read from ROM keeps timings accurate
	ld	a, 0h						; 7	''
	ld	a, (ROMWindow)					; 13+*	''
	nop							; 4
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
; PCM-Tubro: Draining loop (playback only)
; --------------------------------------------------------------

PCMTurboLoop_DrainPhase:
	TraceMsg "PCMTurboLoop_DrainPhase iteration"

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

	; Back to idle loop
	jp	IdleLoop_Init

; --------------------------------------------------------------
PCMTurboLoop_NormalPhase_LoadNextBank:
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
	jp	PCMTurboLoop_NormalPhase

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
; PCM-Tubro: VBlank loop (playback only)
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
	TraceMsg "PCMTurboLoop_VBlankPhase iteration"

	; Handle sample playback in draining mode
	PlaybackTurbo_Run_Draining	e, PCMTurboLoop_VBlank_Loop_DrainDoneSync_EXX	; 41/20
	; Total cycles: 64-65 (playback ok), 24 (drained)

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

PCMTurboLoop_VBlankPhase_CheckCommandOrSample:
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
	ld	(VBlankActive), a			; 13	report we're out of VBlank

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
	; WARNING! Pause is currently not supported!
	jr	.ChkCommandOrSample_Done

; --------------------------------------------------------------
.UnkownCommand:
	TraceException	"Uknown command"
	ld	a, ERROR__UNKNOWN_COMMAND
	ld	(LastErrorCode), a
	jr	.ChkCommandOrSample_ResetInput
