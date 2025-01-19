
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Pause loop program
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

PauseLoop:
	di

	TraceMsg "Entering PauseLoop"

	ld	a, (LoopId)
	ld	(LoopIdCopy), a
	ld	a, LOOP_PAUSE
	ld	(LoopId), a

	; WARNING! Always backup all registers except for `af`!
	push	hl
	ld	hl, (VBlankRoutine)
	ld	(VBlankRoutineCopy), hl
	ld	hl, PauseLoop_VBlank
	ld	(VBlankRoutine), hl
	pop	hl

	; Wait for VBlank now
	ei

.waitVBlank:
	; TODO: Break out of loop in case if VBlank is disabled for good
	nop
	nop
	jr	.waitVBlank

; --------------------------------------------------------------
; Pause loop: VBlank phase
; --------------------------------------------------------------

PauseLoop_VBlank:
	; WARNING! Reused code from `CalibrationLoop`
	; Alter cycles to your liking

	; We need to spend total of 20008 cycles in VBlank
	; Jump code below takes 89 cycles and each routine takes 62 cycles
	; Thus, we need to waste: 20008 - 89 - 62 = 19857
	push	hl					; 11
	ld	hl, 19857-10-11-10			; 10
	call	WasteCycles				; 19857-10-11-10
	pop	hl					; 10

	; NOTE: We can't simply call `rst ProcessCommandInput`, because this
	; loop handles pause/unpause commands differently (otherwise pause
	; command would cause a recursion)
	ld	a, (CommandInput)			; 13	a = command
	or	a					; 4	is command > 00h?
	jr	z, .Unpause				; 7/12	if not, branch
	jp	p, .ChkCommandOrSample_Command		;	if command = 01..7Fh, branch
	call	ProcessCommandInput2.Sample
	ld	a, COMMAND_PAUSE			;	restore paused state/command if sample wasn't accepted
	ld	(CommandInput), a			;	(because `ProcessCommandInput` resets `(CommandInput)`)

.Done:
	ei						; 4	enable interrupts
	ret						; 10	wait until next VBlank

; --------------------------------------------------------------
.ChkCommandOrSample_Command:
	dec	a					; is command 01h (`COMMAND_STOP`)?
	jp	z, StopSamplePlayback_NR		; if yes, branch
	dec	a					; is command 02h (`COMMAND_PAUSE`)?
	jr	z, .Done				; if yes, branch

.UnkownCommand:
	TraceException	"Uknown command"
	ld	a, ERROR__UNKNOWN_COMMAND
	ld	(LastErrorCode), a
	xor	a
	ld	(CommandInput), a			; reset command
	jr	.Done

; --------------------------------------------------------------
.Unpause:
	push	hl
	ld	hl, (VBlankRoutineCopy)			; restore previous VBlank routine
	ld	(VBlankRoutine), hl			; ''
	pop	hl
	ld	a, (LoopIdCopy)				; restore previous loop id
	ld	(LoopId), a				; ''

	inc	sp					; skip return address
	inc	sp					; ''
	ret						; return to caller
