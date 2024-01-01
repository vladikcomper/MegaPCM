
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
	; fallthrough

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
	; Determine loop to run based on sample type
	ld	a, (ix+sSampleInput.type)
	cp	'P'			; is type 'P' (PCM)?
	jp	z, PCMLoop_Init		; if yes, jump to PCM loop
	cp	'T'			; is type 'T' (PCM-Turbo)?
	jp	z, PCMTurboLoop_Init	; if yes, jump to PCM-Tubro loop
	cp	'D'			; is type 'D' (DPCM)?
	jp	z, DPCMLoop_Init	; if yes, jump to DPCM loop

	; Other type values are considered unknown
	; We set and error code and execute `StopSamplePlayback`
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
	jp	IdleLoop_Init
