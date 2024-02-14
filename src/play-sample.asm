
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Functions for initiating sample playback
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------


; --------------------------------------------------------------
; Plays a given sample by id and clears input
; --------------------------------------------------------------
; INPUT:
;	a	- sample id to load (>=80h)
; --------------------------------------------------------------

RequestSamplePlayback:
	ld	sp, Stack
	ld	hl, CommandInput
	ld	(hl), 00h
	call	PlaySample
	jp	IdleLoop		; back to idling


; --------------------------------------------------------------
; Plays a given sample by id
; --------------------------------------------------------------
; INPUT:
;	a	- sample id to load (>=80h)
; --------------------------------------------------------------

PlaySample:
	sub	80h			; 7	is command a sample 80h?
	jr	z, .loadFromSampleInput	; 7/12	if yes, fetch it from `SampleInput`

	; For ids >=81h, load the desired entry from `SampleTable`
	; Implements: `ix = SampleTable + (sampleId - 81h) * 9`
	ld	c, a			; 4	bc = sampleIndex
	ld	b, 0h			; 7	''
	add	a			; 4	a = sampleIndex * 2
	ld	h, b			; 4	hl = sampleIndex * 2
	ld	l, a			; 4	''
	add	hl, hl			; 11	hl = sampleIndex * 4
	add	hl, hl			; 11	hl = sampleIndex * 8
	add	hl, bc			; 11	hl = sampleIndex * 9
	ld	ix, SampleTable-9	; 14
	ex	de, hl			; 4
	add	ix, de			; 15	ix = SampleTable + (sampleIndex - 1) * 9
	jp	PlaySample2		; 10

.loadFromSampleInput:
	ld	ix, SampleInput		; 14
	; fallthrough

	; Total cycles:
	; - A == 80h: 43 cycles + `PlaySample` cycles
	; - A != 80h: 113 cycles + `PlaySample` cycles

; --------------------------------------------------------------
; Plays the loaded sample
; --------------------------------------------------------------
; INPUT:
;	ix	- Sample pointer (`sSampleInput` struct)
; --------------------------------------------------------------

PlaySample2:
	; Load panning value for this sample
	assert SFXPanInput == PanInput+1		; `PanInput` and `SFXPanInput` should follow each other in memory

	ld	hl, PanInput
	bit	FLAGS_SFX, (ix+sSampleInput.flags)	; are we playing SFX?
	jr	z, .panInputReady			; if not, branch
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

; --------------------------------------------------------------
EnterPlaybackLoop:
	; Determine loop to run based on sample type
	ld	a, (ix+sSampleInput.type)
	cp	'P'			; is type 'P' (PCM)?
	jp	z, PCMLoop		; if yes, jump to PCM loop
	cp	'T'			; is type 'T' (PCM-Turbo)?
	jp	z, PCMTurboLoop		; if yes, jump to PCM-Tubro loop
	cp	'D'			; is type 'D' (DPCM)?
	jp	z, DPCMLoop		; if yes, jump to DPCM loop

	; Other type values are considered unknown
	; We set an error code and execute `StopSamplePlayback`
	; as a fallback.
	TraceException	"Unknown sample type"

	ld	a, ERROR__BAD_SAMPLE_TYPE
	ld	(LastErrorCode), a
	; fallthrough

; --------------------------------------------------------------
; Completely stops any playback and resets to the idle loop
; --------------------------------------------------------------

StopSamplePlayback:
	xor	a
	ld	(CommandInput), a
	ld	sp, Stack
	call	DisableDAC
	jp	IdleLoop
