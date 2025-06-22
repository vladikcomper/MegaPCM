
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

	call	LoadActiveSampleData_DI		; `ActiveSample` is initialized with data from `ix`

	; Load DPCM delta table
	ld	hl, DPCM_DeltaTable_00
	call	LoadDPCMTable_DI

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
	Playback_Run_DI						; 60-61	playback a buffered sample
	ei							; 4	we only allow interrupts before buffering samples
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
	ld	ix, 7F00h			; ix = 7F00h (7Fh+0, FFh+1)
	cp	(hl)				; current bank is the last one?
	jr	nz, .lengh_ok			; if not, branch
	ld	ix, (ActiveSample+sActiveSample.endLength)
	inc	ixl				; ixl = Remaining length in ROM bank - 1 (LOW) + 1
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

	pop	bc					; 10
	pop	af					; 10
	ei						; 4
	ret						; 10

; --------------------------------------------------------------
; Generates fast DPCM decode tables
; --------------------------------------------------------------
; INPUT:
;	hl	Source deltas array
;
; USES:
;	af, bc, de, hl, bc', de', hl', ix, iy, Blast processing
; --------------------------------------------------------------

LoadDPCMTable_DI:
	; TODO: Catch nested attempts to use `(StackCopy)`
	ld	(StackCopy), sp			; 20

	; Generate nibble 0 table
	ld	sp, DPCMTables+0100h		; 10	start filling from the end of the table 0
	ld	bc, 16				; 10	bc = deltas length
	add	hl, bc				; 11	skip to the end of the table
	ld	b, c				; 4	b = 16 -- repeat the following block 16 times

.GenerateNibble0Table_Loop:
	dec	hl				; 6	previous delta entry
	ld	e, (hl)				; 7	e = delta
	ld	d, e				; 4	d = delta
	rept	16/2
		push	de			; 11	fill table row with repeated delta
	endr					; =88
	djnz	.GenerateNibble0Table_Loop	; 13/8
	; Cycles: 10+10+11+4 + (6+7+4+88+13) * 16 - (13-8) = 1918

	; Generate nibble 1 table
	ld	sp, hl				; 6
	pop	af				; 10	af = bytes 00..01
	pop	de				; 10	de = bytes 02..03
	pop	hl				; 10	hl = bytes 04..05
	exx					; 4
	pop	bc				; 10	bc' = bytes 06..07
	pop	de				; 10	de' = bytes 08..09
	pop	hl				; 10	hl' = bytes 0A..0B
	exx					; 4
	pop	ix				; 14	ix = bytes 0C..0D
	pop	iy				; 14	iy = bytes 0E..0F
	ld	sp, DPCMTables+0200h		; 10	start filling from the end of the table 1
	ld	b, 16				; 7	repeat the following block 16 times

.GenerateNibble1Table_Loop:
	push	iy				; 15	bytes 0E..0F
	push	ix				; 15	bytes 0C..0D
	exx					; 4
	push	hl				; 11	bytes 0A..0B
	push	de				; 11	bytes 08..09
	push	bc				; 11	bytes 06..07
	exx					; 4
	push	hl				; 11	bytes 04..05
	push	de				; 11	bytes 02..03
	push	af				; 11	bytes 00..01
	djnz	.GenerateNibble1Table_Loop	; 13/8	repeat 16 more times
	; Cycles: 7+6+10+10+10+4+10+10+10+4+14+14+10 + (15+15+4+11+11+11+4+11+11+11+13) * 16 - (13-8) = 1986

	ld	sp, (StackCopy)			; 20	restore stack
	ret					; 10
	; Total cycles: 20 + 1918 + 1986 + 20 + 10 = 3954 (~7.72 cycles per byte)

; --------------------------------------------------------------
DPCM_DeltaTable_00:	; standard DPCM table
	db	000h, 001h, 002h, 004h, 008h, 010h, 020h, 040h
	db	080h, 0FFh, 0FEh, 0FCh, 0F8h, 0F0h, 0E0h, 0C0h

DPCM_DeltaTable_02:	; DPCM-HQ table
	db	0DEh, 0EBh, 0F3h, 0F8h, 0FBh, 0FDh, 0FEh, 0FFh
	db	000h, 001h, 002h, 003h, 005h, 008h, 00Dh, 015h
