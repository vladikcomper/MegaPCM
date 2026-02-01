
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.1
; -----------------------------------------------------------------------------
; Functions for starting and stopping sample playback
;
; (c) 2023-2026, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Plays a given sample by id and clears input (NO RETURN)
; -----------------------------------------------------------------------------
; INPUT:
;	a	- sample id to load (>=80h)
; -----------------------------------------------------------------------------

RequestSamplePlayback_NR:	; NR = No return
	add	a			; 4	a = sampleIndex * 2 (also discards bit 7)
	ld	l, a			; 4	hl = sampleIndex * 2
	ld	h, SampleInput>>10	; 7	hl = sampleIndex * 2 + SampleInput/4
	add	hl, hl			; 11	hl = sampleIndex * 4 + SampleInput/2
	add	hl, hl			; 11	hl = sampleIndex * 8 + SampleInput
	;fallthrough

; -----------------------------------------------------------------------------
; INPUT:
;	hl	- sample pointer (sSampleInput struct)
; -----------------------------------------------------------------------------

RequestSamplePlayback2_NR:	; NR = No return
	xor	a			; a = 0
	ld	(CommandInput), a	; reset command input
	ld	sp, Stack		; reset stack
	call	PlaySample		; <= hl
	jp	IdleLoop		; back to idling


; =============================================================================
; -----------------------------------------------------------------------------
; Plays the loaded sample
; -----------------------------------------------------------------------------
; INPUT:
;	hl	- Sample pointer (`sSampleInput` struct)
; -----------------------------------------------------------------------------

PlaySample:
	TraceMsg "Entering PlaySample"

	push	hl

	; Failsafe against playing non-samples
	assert FLAGS_SAMPLE == 7

	ld	a, (hl)
	add	a					; are we playing a sample at all (`FLAGS_SAMPLE` set)?
	jr	nc, StopSamplePlayback_NR		; if not, halt immediately

	; Load panning value for this sample
	assert FLAGS_SFX == 6
	assert SFXPanInput == PanInput+1		; `PanInput` and `SFXPanInput` should follow each other in memory

	ld	hl, PanInput
	add	a					; are we playing SFX (`FLAGS_SFX` set)?
	jr	nc, .panInputReady			; if not, branch
	inc	l					; if yes, use `SFXPanInput` instead of `PanInput`
.panInputReady:
	ld	c, (hl)					; c = panning

	; Setup YM for DAC playback: enable DAC, set pan
	assert (YM_Port0_Reg&0FFh) == 0

	ld	hl, DriverReady				;	hl = DriverReady
	ld	de, YM_Port0_Reg			;	de = YM_Port0_Reg
	ld	b, e					;	b = 0
	ld	a, 'R'					;	a = 'R'
	ld	(hl), b					;	DriverReady = 0
	ex	de, hl					; 4	de = DriverReady, hl = YM_Port0_Reg
	ld	(hl), 2Bh				; 10	YM (Port 0) => Enable DAC / Disable FM6
	inc	l					; 4	''
	ld	(hl), 80h				; 10	''
	inc	l					; 4	YM (Port 1) => Set panning
	ld	(hl), 0B6h				; 10	''
	inc	l					; 4	''
	ld	(hl), c					; 7	''
	ld	l, b					; 4	back to Port 0
	ld	(hl), 2Ah				; 10	YM (Port 0) => prepare DAC output
	ld	(de), a					; 7	DriverReady = 'R'

	; Start actual sample playback now
	pop	ix					; ix = Sample pointer
	call	EnterPlaybackLoop

DisableDAC:
	; Playback's done, disable DAC
	ld	hl, DriverReady				;	de = DriverReady
	ld	de, YM_Port0_Reg			;	hl = YM_Port0_Reg
	ld	a, 'R'					;	a = 'R'
	ld	(hl), e					; 	DriverReady = 0
	ex	de, hl					; 4	de = DriverReady, hl = YM_Port0_Reg
	ld	(hl), 2Bh				; 10	YM (Port 0) => Disable DAC / Enable FM6
	inc	l					; 4	''
	ld	(hl), 00h				; 10	''
	ld	(de), a					; 7	DriverReady = 'R'
	ret

; -----------------------------------------------------------------------------
EnterPlaybackLoop:
	assert MASK_TYPE == %1110

	; Determine loop to run based on the sample type
	ld	a, (ix+sSampleInput.flags)		; 19
	and	MASK_TYPE				; 7	a = sample type bits
	add	.LoopTable&0FFh				; 7
	ld	(.sm1+1), a				; 13
.sm1:	ld	hl, (.LoopTable+00h)			; 16
	jp	(hl)					; 4

; -----------------------------------------------------------------------------
.LoopTable:
	dw	StopSamplePlayback_NR			; +00h
	dw	PCMLoop					; +02h
	dw	PCMTurboLoop				; +04h
	dw	DPCM0Loop				; +06h	Classic DPCM / DPCM-HQ Table #0
	dw	DPCM0TurboLoop				; +08h	''
	dw	DPCM1Loop				; +0Ah	DPCM-HQ Table #1
	dw	DPCM1TurboLoop				; +0Ch	''
	dw	StopSamplePlayback_NR			; +0Eh
.LoopTable_End:

	; Loop table shouldn't cross 256-byte boundary for 8-bit addition to work
	assert (.LoopTable_End>>8)==(.LoopTable>>8)

; -----------------------------------------------------------------------------
; Completely stops any playback and resets to the idle loop
; -----------------------------------------------------------------------------

StopSamplePlayback_NR:
	TraceMsg "Entering StopSamplePlayback_NR"

	xor	a
	ld	(CommandInput), a
	ld	sp, Stack
	call	DisableDAC
	jp	IdleLoop

; -----------------------------------------------------------------------------
; Loads active sample data from `sSampleInput` to `sActiveSample`
; -----------------------------------------------------------------------------
; INPUT:
;	ix	- Pointer to `sSampleInput` struct
; -----------------------------------------------------------------------------

LoadActiveSampleData_DI:
	TraceMsg "Entering LoadActiveSampleData_DI"

	; TODO: Assert interrupts disabled
	ld	(StackCopy), sp			; backup stack

	; Fetch input sample data (see `sSampleInput` struct) ...
	; TODO: Disable sample input?
	ld	sp, ix				; load sample in the stack
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
	jp	c, StopSamplePlayback_NR	; if endBank < startBank, abort playback
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

	assert FLAGS_SFX==6			; we need this assertion to ensure trick below works

	ld	hl, VolumeInput			; hl = VolumeInput
	ex	af, af'				; a = pitch, f = flags
	jr	nz, .setVolumeInputPtr		; Z = FLAGS_SFX
	inc	l				; hl = SFXVolumeInput
.setVolumeInputPtr:
	push	hl				; (ActiveSample+sActiveSample.volumeInputPtr) = hl

	ld	sp, (StackCopy)			; restore stack
	ret
