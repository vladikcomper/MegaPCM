
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Idle loop program
;
; (c) 2023, Vladikcomper
; --------------------------------------------------------------

IdleLoop_Init:
	di					; don't want VBlank during idle loop

	DebugMsg "Entering IdleLoop"

	ld	a, LOOP_IDLE
	ld	(LoopId), a

	ifdef __DEBUG__
		ld	hl, VoidInterrupt
		ld	(VBlankRoutine), hl
	endif

; --------------------------------------------------------------
IdleLoop_Main:
	ld	hl, CommandInput

.loop:
	ld	a, (hl)			; read command
	or	a
	jp	p, .loop

; --------------------------------------------------------------
LoadSample:
	sub	80h			; is command a sample 80h?
	jr	z, LoadFromSampleInput

LoadFromSampleTable:
	; Calculate sample's index (part 1)
	add	a			; a = sampleIndex * 2
	ld	c, a
	ld	b, 0h			; bc = sampleIndex * 2

	; Mark command as accepted
	ld	(hl), b			; IN_command = 00h

	; Calculate sample's index (part 2)
	ld	h, b
	ld	l, c			; hl = sampleIndex * 2
	add	hl, hl			; hl = sampleIndex * 4
	add	hl, hl			; hl = sampleIndex * 8
	add	hl, bc			; hl = sampleIndex * 10
	ld	ix, SampleTable-10
	ex	de, hl
	add	ix, de			; ix = SampleTable + (sampleIndex - 1) * 10

	jp	PlaySample

; --------------------------------------------------------------
LoadFromSampleInput:
	xor	a
	ld	(hl), a			; CommandInput = 00h
	
	ld	hl, SampleInput
	ld	de, ActiveSample
	ld	(DriverReady), a	; cannot accept inputs during sample data copy (otherwise we can overwrite it mid-copy)
	rept sSample-1	; copy "SampleInput" to "ActiveSample" (minus 1 reserved byte)
		ldi
	endr
	ld	a, 'R'
	ld	(DriverReady), a	; can accept inputs now

	ld	ix, ActiveSample

; --------------------------------------------------------------
PlaySample:
	; Determine loop to run based on sample type
	ld	a, (ix+sSample.type)
	cp	'P'			; is type 'P' (PCM)?
	jp	z, PCMLoop_Init		; if yes, jump to PCM loop

	ifdef __DEBUG__
		; Error out on illegal sample
		push	af			; remember A for analysis

		DebugErrorTrap	ERROR__BAD_SAMPLE_TYPE
	else
		jp	IdleLoop_Main
	endif
