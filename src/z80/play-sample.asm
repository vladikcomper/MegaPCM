
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.1
; -----------------------------------------------------------------------------
; Functions for starting and stopping sample playback
;
; (c) 2023-2025, Vladikcomper
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
	dw	DPCMLoop				; +06h
	dw	StopSamplePlayback_NR			; +08h
	dw	StopSamplePlayback_NR			; +0Ah
	dw	StopSamplePlayback_NR			; +0Ch
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
