
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
	or	a			; is command a sample 80h?
	jp	p, .loop		; if not, branch

LoadSample:
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
