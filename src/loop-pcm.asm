
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

PCMLoop_Init:
	di

	DebugMsg "Entering PCMLoop"

	ld	a, LOOP_PCM
	ld	(LoopId), a

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
	; Prepare YM playback
	ld	iy, YM_Port0_Reg
	xor	a
	ld	(DriverReady), a		; cannot interrupt driver now ...
	ld	(iy+0), 2Bh			; YM => Enable DAC
	ld	(iy+1), 80h			; ''
	ld	a, (ix+sSample.flags)		; load flags
	and	0C0h				; are pan bits set?
	jr	z, .panDone			; if not, branch
        ld	(iy+2), 0B6h			; YM => Set Pan
	ld	(iy+3), a			; ''
.panDone:
	ld	a, 'R'
	ld	(DriverReady), a		; ready to fetch inputs now
	ld	(iy+0), 2Ah			; setup YM to fetch DAC bytes

	; Setup volume source (VolumeInput or SFXVolumeInput)
	ld	a, VolumeInput&0FFh
	bit	FLAGS_SFX, (ix+sSample.flags)
	jr	z, .setVolumeSource
	ld	a, SFXVolumeInput&0FFh
.setVolumeSource:
	ld	(PCMLoop_Init.selfModVolumeSource), a
	ld	(PCMLoop_VBlankPhase_CheckCommandOrSample.selfModVolumeSource), a

	; Init playback registers ...
	Playback_Init	de, (ix+sSample.pitch)

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

	; Handle "read-ahead" buffer
	di
	ldi							; 16
	ldi							; 16
	ld	d, SampleBuffer>>8				; 7	fix `d` in case of carry from `e`
	jp	po, PCMLoop_NormalPhase_ReadAheadExhausted_DI	; 10	if bc != 0, branch (WARNING: this requires everything to be word-aligned)

	; Handle playback
PCMLoop_NormalPhase_Playback_DI:
	Playback_Run						; 67-68	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
	Playback_ChkReadaheadOk	e, PCMLoop_NormalPhase		; 14
	; Total "PCMLoop_NormalPhase" cycles: 134-135

; --------------------------------------------------------------
PCMLoop_NormalPhase_ReadAheadFull:
	DebugMsg "PCMLoop_NormalPhase_ReadAheadFull iteration"

	; Waste 49 cycles (we cannot handle "read-ahead" now)
	ld	a, (ROMWindow)					; 13	idle read from ROM keeps timings accurate
	ld	a, 0h						; 7	''
	ld	a, (ROMWindow)					; 13	''
	di							; 4
	jr	PCMLoop_NormalPhase_Playback_DI			; 12

; --------------------------------------------------------------
PCMLoop_NormalPhase_ReadAheadExhausted_DI:
	ei							; 4

	; Are we done playing?
	ld	a, (CurrentBank)				; 13
	cp	(ix+sSample.endBank)				; 19	current bank is the last one?
	jr	nz, PCMLoop_NormalPhase_LoadNextBank		; 7/12	if not, branch

	; TODO: Make sure we waste as many cycles as half of the drain iteration

; --------------------------------------------------------------
; PCM: Draining loop (playback only)
; --------------------------------------------------------------

PCMLoop_DrainPhase:
	DebugMsg "PCMLoop_DrainPhase iteration"

	; Handle playback in draining mode
	di								; 4
	Playback_Run_Draining	e, PCMLoop_DrainPhase_Done_EXX_DI	; 71-72
	ei								; 4

	; Waste 55 cycles (instead of handling readahead)
	ld	a, (ROMWindow)						; 13	idle read from ROM keeps timings accurate
	ld	c, 0FFh							; 7
	ld	a, (ROMWindow)						; 13
	dec	bc							; 6
	nop								; 4
	jr	PCMLoop_DrainPhase					; 12
	; Total "PCMLoop_DrainPhase" cycles: 134-135

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
;
; --------------------------------------------------------------

PCMLoop_VBlank:
	push	af
	push	bc

	ld	b, 38-1					; TODO: Verify this
							; TODO: Different draining for PAL

; --------------------------------------------------------------
PCMLoop_VBlankPhase:
	DebugMsg "PCMLoop_VBlankPhase iteration"

	; Handle sample playback in draining mode
	Playback_Run_Draining	e, PCMLoop_VBlank_Loop_DrainDoneSync_EXX	; 71-72	playback one sample

PCMLoop_VBlankPhase_Sync:
	; Waste 63 cycles
	push	bc					; 11
	nop						; 4
	pop	bc					; 10
	push	bc					; 11
	nop						; 4
	pop	bc					; 10
	djnz	PCMLoop_VBlankPhase			; 13/8
	; Total "PCMLoop_VBlankPhase" cycles: 134-135

; --------------------------------------------------------------
PCMLoop_VBlankPhase_LastIteration:
	; Handle sample playback for the last iteration
	Playback_Run_Draining_NoSync	e		; 71-72/28
	Playback_LoadPitch	b, (ix+sSample.pitch)	; 27	reload pitch

PCMLoop_VBlankPhase_CheckCommandOrSample:
	ld	a, (CommandInput)			; 13	a = command
	or	a					; 4	is command > 00h?
	jr	z, .ChkCommandOrSample_Done		; 7/12	if not, branch
	jp	p, .ChkCommandOrSample_Command		;	if command = 01..7Fh, branch

	; Only low-priority samples can be overriden
	bit	FLAGS_SFX, (ix+sSample.flags)	; is sample high priority?
	jp	z, .ResetDriver_ToLoadSample		; if not, branch

.ChkCommandOrSample_ResetInput:
	; Reset command
	xor	a
	ld	(CommandInput), a

.ChkCommandOrSample_Done:
	; Handle sample playback one last time
	nop
	nop
	Playback_Run_Draining_NoSync	e		; 71-72/28
	exx
	Playback_LoadVolume_EXX				; 31	reload volume
	exx

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

; --------------------------------------------------------------
PCMLoop_VBlank_Loop_DrainDoneSync_EXX:
	; Waste 47 cycles
	exx						; 4
	ld	a, 00h					; 7
	inc	bc					; 6
	dec	bc					; 6
	inc	bc					; 6
	dec	bc					; 6
	jr	PCMLoop_VBlankPhase_Sync		; 12
