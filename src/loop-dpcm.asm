
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
; --------------------------------------------------------------

DPCMLoop_Init:
	di

	DebugMsg "Entering DPCMLoop"

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
	jp	c, IdleLoop_Init		; if endBank < startBank, abort playback
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
DPCMLoop_Reload:

	; Set initial ROM bank ...
	ld	a, (ActiveSample+sActiveSample.startBank)
	rst	SetBank

	di

	; Init read ahead registers ...
	ld	de, SampleBuffer
	ld	bc, (ActiveSample+sActiveSample.startOffset)
	ld	hl, (ActiveSample+sActiveSample.startLength)

	; Init playback registers ...
	Playback_Init_DI	SampleBuffer

	ei
	dec	e
	ld	a, 80h				; set initial sample to zero (80h)
	ld	(de), a				; ''

; --------------------------------------------------------------
; DPCM: Main playback loop (readahead & playback)
; --------------------------------------------------------------
; Registers:
;	bc	= ROM pos
;	de 	= Sample buffer pos (read-ahead)
;	hl	= Remaining length in ROM bank - 1
; --------------------------------------------------------------

DPCMLoop_NormalPhase:
	DebugMsg "DPCMLoop_NormalPhase iteration"

	; Handle "read-ahead" buffer
	ld	a, (bc)				; 7+3.3*
	inc	bc				; 6	increment dest pointer
	push	hl				; 11
	ld	h, DPCMTables>>8		; 7	select DPCM table for the first nibble
	ld	l, a				; 4
	ld	a, (de)				; 7	a = previous sample
	inc	e				; 4	increment buffer pointer
	add	a, (hl)				; 7	a = first sample
	di					; 4	don't move this too far away
	ld	(de), a				; 7	send to buffer
	inc	e				; 4	increment buffer pointer
	inc	h				; 4	select DPCM table for the second nibble
	add	a, (hl)				; 7	a = second sample
	ld	(de), a				; 7	send to buffer
	pop	hl				; 10
	dec	l				; 4	decrement low byte of length
	jr	z, .ChkReadAheadExhausted_DI	; 7/12	if borrow from a high byte, branch

	; Handle playback
.Playback_DI:
	Playback_Run_DI						; 60-61	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	Playback_ChkReadaheadOk	e, DPCMLoop_NormalPhase		; 21
	; Total cycles: 49

	; Total "DPCMLoop_NormalPhase" cycles: ~192-193 + 3.3*
	; *) additional cycles lost due to M68K bus access on average

; --------------------------------------------------------------
.ReadAheadFull:
	DebugMsg "PCMLoop_NormalPhase_ReadAheadFull iteration"

	; Waste 107 + 3* cycles (we cannot handle "read-ahead" now)
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	bc						; 11
	dec	bc						; 6
	pop	bc						; 10
	nop							; 4
	di							; 4
	jr	.Playback_DI					; 12

; --------------------------------------------------------------
.ChkReadAheadExhausted_DI:
	dec	h				; 4	decrement high byte of length
	jp	nz, .Playback_DI		; 10	if no borrow, back to playback

.ReadAheadExhausted_DI:
	; NOTE: Enabling interrupts so we don't miss VBlank if it fires.
	; Initial VBlank trigger lasts ~171 cycles, so we shouldn't disable
	; interrupts for longer than that. Missing VBlank may mess up
	; "DMA protection" (avoiding ROM access during VBlank)
	ei							; 4

	; Are we done playing?
	ld	a, (CurrentBank)				; 13
	cp	(ix+sActiveSample.endBank)			; 19	current bank is the last one?
	jr	nz, DPCMLoop_NormalPhase_LoadNextBank		; 7/12	if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; DPCM: Draining loop (playback only)
; --------------------------------------------------------------

DPCMLoop_DrainPhase:
	DebugMsg "DPCMLoop_DrainPhase iteration"

	; Handle playback in draining mode
	di							; 4
	Playback_Run_Draining	e, .Drained_EXX_DI		; 71-72
	ei							; 4

	; Waste 113 + 3* cycles
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	af						; 11
	pop	af						; 10
	push	bc						; 11
	dec	bc						; 6
	inc	bc						; 6
	pop	bc						; 10
	nop							; 4
	nop							; 4
	jr	DPCMLoop_DrainPhase				; 12
	; Total "DPCMLoop_DrainPhase" cycles: ~192-193 + 3*
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
	jp	nz, DPCMLoop_Reload			; re-enter playback loop

	; Back to idle loop
	jp	IdleLoop_Init

; --------------------------------------------------------------
DPCMLoop_NormalPhase_LoadNextBank:
	; Prepare next bank id
	ld	a, (CurrentBank)
	inc	a

	; Setup sample source and length
	ld	bc, ROMWindow			; bc = 8000h (alt: ld b, ROMWindow<<8)
	ld	h, b				; hl = 8000h (7Fh+1, FFh+1)
	ld	l, c				; ''
	cp	(ix+sActiveSample.endBank)	; current bank is the last one?
	jr	nz, .lengh_ok			; if not, branch
	ld	hl, (ActiveSample+sActiveSample.endLength)
.lengh_ok:

	; Switch to the next ROM bank
	rst	SetBank2

	; Ready to continue playback!
	jp	DPCMLoop_NormalPhase


; --------------------------------------------------------------
; PCM: VBlank loop (playback only)
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
	; This means in worst-case scenario, we must play 104 samples to survive VBlank.
	ld	b, 104-2

; --------------------------------------------------------------
DPCMLoop_VBlankPhase:
	DebugMsg "DPCMLoop_VBlankPhase iteration"

	; Handle sample playback in draining mode
	Playback_Run_Draining	e, DPCMLoop_VBlank_Loop_DrainDoneSync_EXX	; 71-72/24	playback one sample

DPCMLoop_VBlankPhase_Sync:
	; Slightly late, but report we're in VBlank
	ld	a, 0FFh					; 7
	ld	(VBlankActive), a			; 13

	; Waste 101 + 3* cycles
	ld	a, 00h					; 7
	push	bc					; 11
	pop	bc					; 10
	push	bc					; 11
	pop	bc					; 10
	push	bc					; 11
	pop	bc					; 10
	push	bc					; 11
	pop	bc					; 10
	djnz	DPCMLoop_VBlankPhase			; 13/8
	; Total "PCMLoop_VBlankPhase" cycles: 192-193 + 3*
	; *) emulated lost cycles on M68K bus access on average

; --------------------------------------------------------------
DPCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback and reload volume
	Playback_Run_Draining_NoSync	e		; 71-72/28
	exx						; 4
	Playback_LoadVolume_EXX				; 51
	exx						; 4
	Playback_LoadPitch				; 21	reload pitch
	push	bc					; 11
	pop	bc					; 10

DPCMLoop_VBlankPhase_CheckCommandOrSample:
	ld	a, (CommandInput)			; 13	a = command
	or	a					; 4	is command > 00h?
	jr	z, .ChkCommandOrSample_Done		; 7/12	if not, branch
	jp	p, .ChkCommandOrSample_Command		;	if command = 01..7Fh, branch

	; Only low-priority samples can be overriden
	bit	FLAGS_SFX, (ix+sActiveSample.flags)	; is sample high priority?
	jp	z, .ResetDriver_ToLoadSample		; if not, branch

.ChkCommandOrSample_ResetInput:
	; Reset command
	xor	a
	ld	(CommandInput), a

.ChkCommandOrSample_Done:
	; Slightly early, but report we're out of VBlank
	ld	(VBlankActive), a			; 13

	; Handle sample playback one last time
	Playback_Run_Draining_NoSync	e		; 71-72/28

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10

; --------------------------------------------------------------
.ChkCommandOrSample_Command:
	dec	a					; is command 01h (`COMMAND_STOP`)?
	jp	z, .ResetDriver_ToIdleLoop		; if yes, branch
	dec	a					; is command 02h (`COMMAND_PAUSE`)?
	ifdef __DEBUG__
		jr	z, .PausePlayback			; if yes, branch

		; other commands are considered invalid in DEBUG builds and cause error traps
		DebugErrorTrap ERROR__NOT_SUPPORTED
	else
		jr	nz, .ChkCommandOrSample_ResetInput		; if unknown command, ignore
	endif

.PausePlayback:
	; There's a trick to it: While the "pause command" is set,
	; we reset sample pitch to 0, cancelling pitch reload above.
	; As soon as this command is unset, the pitch reload will restore it.
	Playback_ResetPitch				; set pitch to 00h
	jr	.ChkCommandOrSample_Done

; --------------------------------------------------------------
.ResetDriver_ToIdleLoop:
	ld	sp, Stack				; reset stack
	jp	IdleLoop_Init				;

; --------------------------------------------------------------
.ResetDriver_ToLoadSample:
	ld	sp, Stack				; reset stack
	ld	hl, CommandInput
	jp	LoadSample				; load sample stored in A


