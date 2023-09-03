
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

	ifdef __DEBUG__
		ld	hl, VoidInterrupt
		ld	(VBlankRoutine), hl
		ld	(iy+sDriverIO.OUT_dbg_loopId), LOOP_IDLE
	endif

; --------------------------------------------------------------
IdleLoop_Main:
	ld	hl, DriverIO_RAM+sDriverIO.IN_command

.loop:
	ld	a, (hl)			; read command
	or	a			; is command a sample 80h?
	jp	p, .loop		; if not, branch

LoadSample:
	; Calculate sample's index (part 1)
	sub	80h			; a = sampleIndex (80..FFh -> 00..7Fh)
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
	ld	ix, SampleTable
	ex	de, hl
	add	ix, de			; ix = SampleTable + sampleIndex * 10

	; Determine loop to run based on sample type
	ld	a, (ix+sSample.type)
	cp	'P'			; is type 'P' (PCM)?
	jp	z, PCMLoop_Init		; if yes, jump to PCM loop

	ifdef __DEBUG__
		; Error out on illegal sample
		push	af			; remember A for analysis
		ld	a, ERROR__BAD_SAMPLE_TYPE
		call	Debug_ErrorTrap
	else
		jp	IdleLoop_Main
	endif
