
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; DPCM loop module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------
; INPUT:
;	ix	Pointer to `sSample` structure
; --------------------------------------------------------------

DPCMLoop:
	di

	TraceMsg "Entering DPCMLoop"

	ld	a, LOOP_DPCM
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, DPCMLoop_VBlank
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
	push	hl				; (ActiveSample+sActiveSample.startOffset) = hl

	res	7, d				; de = end offset & 7FFFh
	dec	de				; de = (end offset & 7FFFh) - 1
	ld	a, d
	and	e
	inc	a				; is de = -1?
	jr	nz, .lengthOk			; if not, branch
	dec	b
	ld	d, 7Fh				; de = 7FFFh (use max end length)
.lengthOk:
	; WARNING! This value is incorrect for single-bank samples; luckily, it's ignored
 	inc	d				; increment `d` by one so Z flag means borrow on decrement
 	inc	e				; increment 'e' by one so Z flag means borrow on decrement
	push	de				; (ActiveSample+sActiveSample.endLength) = de
	dec	d
	dec	e

	ld	a, b				; a = endBank
	cp	c				; endBank == startBank?
	jr	nz, .isMultibank		; if not, branch
	jp	c, StopSamplePlayback		; if endBank < startBank, abort playback
	res	7, h
	ex	de, hl				; hl = end length - 1, de = start length
	sbc	hl, de				; hl = length - 1
	jp	.setFirstBankLen

.isMultibank:
	; Implements: de = 10000h - hl - 1, or simply de = -hl-1
	xor	a				; a = 0
	sub	l				; a = 0 - l
	ld	e, a				; e = 0 - l
	sbc	h				; a = 0 - h - l - carry
	add	l				; a = 0 - h - carry
	ld	d, a				; d = 0 - h - carry
	ex	de, hl
	dec	hl

.setFirstBankLen:
 	inc	h				; increment `h` by one so Z flag means borrow on decrement
 	inc	l				; increment 'l' by one so Z flag means borrow on decrement
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
;	ixh	= Remaining length in ROM bank - 1 (HIGH) + 1
; --------------------------------------------------------------

DPCMLoop_NormalPhase_NoCycleStealing:
	nop					; +4*	used as entry point to the loop for poor emulators
						;	... that don't emulate cycle-stealing

DPCMLoop_NormalPhase:
	TraceMsg "DPCMLoop_NormalPhase iteration"

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
	Playback_Run_DI						; 60-61	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	Playback_ChkReadaheadOk	c, b, DPCMLoop_NormalPhase	; 18
	; Total cycles: 46

	; Total "DPCMLoop_NormalPhase" cycles: ~169-170 + 3.3*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	TraceMsg "PCMLoop_NormalPhase_ReadAheadFull iteration"

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
	jp	nz, .Playback_DI		; 10	if no borrow, back to playback

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
	TraceMsg "DPCMLoop_DrainPhase iteration"

	; Handle playback in draining mode
	di							; 4
	Playback_Run_Draining	c, .Drained_EXX_DI		; 71-72
	ei							; 4

	; Waste 90 + 3* cycles
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	hl						; 11
	inc	hl						; 6
	inc	hl						; 6
	inc	hl						; 6
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
	ld	ix, 8000h			; ix = 8000h (7Fh+1, FFh+1)
	cp	(hl)				; current bank is the last one?
	jr	nz, .lengh_ok			; if not, branch
	ld	ix, (ActiveSample+sActiveSample.endLength)
.lengh_ok:
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

	; NOTE: VBlank takes ~8653 cycles on NTSC or up to ~20008 on PAL (V28 mode).
	; This means in worst-case scenario, we must play 116 samples to survive VBlank.
	ld	b, 116-2

; --------------------------------------------------------------
DPCMLoop_VBlankPhase:
	TraceMsg "DPCMLoop_VBlankPhase iteration"

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
	; Total "PCMLoop_VBlankPhase" cycles: 169-170 + 3*
	; *) emulated lost cycles on M68K bus access on average

; --------------------------------------------------------------
DPCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback and reload volume
	Playback_Run_Draining_NoSync	c		; 71-72/28
	exx						; 4
	Playback_LoadVolume_EXX				; 45
	exx						; 4
	Playback_LoadPitch				; 21	reload pitch

DPCMLoop_VBlankPhase_CheckCommandOrSample:
	ld	a, (CommandInput)			; 13	a = command
	or	a					; 4	is command > 00h?
	jr	z, .ChkCommandOrSample_Done		; 7/12	if not, branch
	jp	p, .ChkCommandOrSample_Command		;	if command = 01..7Fh, branch

	; Only low-priority samples can be overriden
	assert	FLAGS_SFX==0				; `FLAGS_SFX` should be 0 for the next optimization to work ...

	ld	a, (ActiveSample+sActiveSample.flags)
	rrca						; push `FLAGS_SFX` to Carry
	jr	nc, .PlaySample				; if not SFX, branch

.ChkCommandOrSample_ResetInput:
	; Reset command
	xor	a
	ld	(CommandInput), a

.ChkCommandOrSample_Done:
	; Handle sample playback one last time
	Playback_Run_Draining_NoSync	c		; 71-72/28

	; Report we're out of VBlank
	xor	a
	ld	(VBlankActive), a			; 13

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

.PlaySample:
	ld	a, (CommandInput)			; a = sample
	jp	RequestSamplePlayback

; --------------------------------------------------------------
.UnkownCommand:
	TraceException	"Uknown command"
	ld	a, ERROR__UNKNOWN_COMMAND
	ld	(LastErrorCode), a
	jr	.ChkCommandOrSample_ResetInput
