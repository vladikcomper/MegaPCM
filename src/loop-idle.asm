
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Idle loop program
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

IdleLoop:
	di

	TraceMsg "Entering IdleLoop"

	ld	a, LOOP_IDLE
	ld	(LoopId), a

	ld	hl, IdleLoop_VBlank
	ld	(VBlankRoutine), hl

	; Wait for VBlank now
	ei

.waitVBlank:
	; TODO: Break out of loop in case if VBlank is disabled for good
	nop
	nop
	jr	.waitVBlank

; --------------------------------------------------------------
; Idle loop: VBlank phase
; --------------------------------------------------------------

IdleLoop_VBlank:
	; WARNING! Reused code from `CalibrationLoop`
	; Alter cycles to your liking

	; We need to spend total of 20008 cycles in VBlank
	; Jump code below takes 89 cycles and each routine takes 62 cycles
	; Thus, we need to waste: 20008 - 89 - 62 = 19857
	ld	hl, 19857-10			; 10
	call	WasteCycles			; 19857-10

	ld	a, (CommandInput)		; 13	read command
	or	a				; 4	is it a sample (>80h)?
	jp	m, RequestSamplePlayback	; 10	if yes, jump
	ei					; 4	enable interrupts
	ret					; 10	wait until next VBlank
