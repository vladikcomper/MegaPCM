
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
; INPUT:
;	ix	- Currently loaded sample (`sActiveSample` struct)
;
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

	; Only low-priority samples can be overriden
	bit	FLAGS_PRIORITY, (ix+sActiveSample.flags); is sample high priority?
	jp	nz, .ResetCommandInput			; if yes, always ignore new samples
	bit	FLAGS_SFX, (ix+sActiveSample.flags)	; is current sample SFX?
	jp	z, RequestSamplePlayback_NR		; if not, accept new sample unconditionally
	push	ix
	push	hl
	push	af
	; TODO: Faster version that gets sample in `hl`
	call	GetSample				; 17+113/43	ix = Sample
	ld	a, (ix+sSampleInput.flags)		; get new sample flags
	and	(1<<FLAGS_SFX)|(1<<FLAGS_PRIORITY)	; is it SFX or high priority sample?
	jp	z, .ToResetCommandInput			; if not, branch
	pop	af					; a = sample
	; TODO: Reset VBlankActive flag
	jp	RequestSamplePlayback_NR

.ToResetCommandInput:
	pop	af
	pop	hl
	pop	ix

.ResetCommandInput:
	xor	a
	ld	a, (CommandInput)
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
