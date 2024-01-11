
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Idle loop program
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

IdleLoop:
	di					; don't want VBlank during idle loop

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
	exx						; 4
	push	bc					; 11
	ld	b, 254					; 7

.loop:
	push	af					; 11
	pop	af					; 10
	push	af					; 11
	pop	af					; 10
	add	hl, bc					; 15
	nop						; 4
	nop						; 4
	djnz	.loop					; 8/13
	; Cycles: (65 + 8) + ((65 + 13) * (b - 1)) = 19807

	inc	bc					; 6
	inc	bc					; 6
	inc	bc					; 6
	pop	bc					; 10


	ld	a, (CommandInput)		; 7	read command
	or	a				; 4	is it a sample (>80h)?
	jp	m, RequestSamplePlayback	; 10	if yes, jump
	ei					; 4	enable interrupts
	ret					; 10	wait until next VBlank
