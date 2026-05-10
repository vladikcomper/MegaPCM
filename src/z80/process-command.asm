
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.1
; -----------------------------------------------------------------------------
; Functions for handling command inputs
;
; (c) 2023-2025, Vladikcomper
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Reads and processes commands in `(CommandInput)` byte
; -----------------------------------------------------------------------------
; The first chunk (`ProcessCommandInput:`) is copied to 0000h by `InitDriver`
; This allows to call it as:
;	rst	ProcessCommandInput	; 11+22 cycles (if no new input)
;
; This must be called at the end of VBlank from a sample playback loop (e.g.
; `Loop_PCM`, `Loop_DPCM`, `Loop_PCM_Turbo`).
;
; If `(CommandInput)` contains a command (00..7Fh):
;  - 01h (`COMMAND_STOP`) breaks the current loop;
;  - 02h (`COMMAND_PAUSE`) enters pause loop until pause is reset or new
;	sample is received (breaks the current loop in this case);
;  - 03..7Fh sets `ERROR__UNKNOWN_COMMAND`, but returns gracefully.
;
; If `(CommandInput)` is a sample id (80..FFh):
;  - 
; -----------------------------------------------------------------------------
; OUTPUT:
;	a = 0
; -----------------------------------------------------------------------------

ProcessCommandInput_CodePatch:	phase 0	; for copying the routine below at offset 0000h
ProcessCommandInput:

.CommandInput_Initial:	equ	00h	; command input value for self-modifying code

	; NOTE: This actually loads `a` with the value of `(CommandInput)`,
	; because `CommandInput` address itself is set to this operand.
.sm1:	ld	a, .CommandInput_Initial	; :00h	7	read from (CommandInput)
	or	a				; :02h	4	test the value
	ret	z				; :03h	11/5	if input byte is 00h, return
	jp	ProcessCommandInput2		; :04h	10	otherwise, jump to process it
	; Total cycles:
	; - No new input: 22 cycles
	; - Other cases: not counted
	dephase

ProcessCommandInput_CodePatch_End:

	assert ProcessCommandInput_CodePatch_End-ProcessCommandInput_CodePatch <= 8

; -----------------------------------------------------------------------------
ProcessCommandInput2:
	jp	p, .Command			; it's command (01..7Fh), branch

.Sample:
	; WARNING! We shouldn't read `(CommandInput)` from now on to avoid any
	; data races (e.g. 68K stopping Z80 and overwriting it to a non-sample)
	push	hl				; 11
	push	af				; 11
	add	a				; 4	a = sampleIndex * 2 (also discards bit 7)
	ld	l, a				; 4	hl = sampleIndex * 2
	ld	h, SampleInput>>10		; 7	hl = sampleIndex * 2 + SampleInput/4
	add	hl, hl				; 11	hl = sampleIndex * 4 + SampleInput/2
	add	hl, hl				; 11	hl = sampleIndex * 8 + SampleInput
	ld	a, (ActiveSample+sActiveSample.flags) ; 13	a = active sample flags
	and	MASK_PRIORITY			; 7	mask only priority bits
	cp	(hl)				; 7	does the new sample has higher priority?
	jp	c, RequestSamplePlayback2_NR	; 7/12	if yes, branch
	pop	af				; 10
	pop	hl

.ResetCommandInput:
	xor	a
	ld	(CommandInput), a
	ret

; --------------------------------------------------------------
.Command:
	dec	a					; is command 01h (`COMMAND_STOP`)?
	jp	z, StopSamplePlayback_NR		; if yes, branch
	dec	a					; is command 02h (`COMMAND_PAUSE`)?
	jp	nz, .UnkownCommand			; if not, branch

.PausePlayback:
	; TODO: Reset VBlankActive flag
	call	PauseLoop				; enter pause loop until cancelled
	xor	a
	ret

.UnkownCommand:
	TraceException	"Uknown command"
	ld	a, ERROR__UNKNOWN_COMMAND
	ld	(LastErrorCode), a
	jp	.ResetCommandInput
