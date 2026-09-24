
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.2
; -----------------------------------------------------------------------------
; Functions for handling command inputs (Part 1)
;
; (c) 2023-2026, Vladikcomper
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Reads and processes commands in `(CommandInput)` byte
; -----------------------------------------------------------------------------
; This must be called at the end of VBlank from a sample playback loop (e.g.
; `PCMLoop_VBlank`, `DPCMTurboLoop_VBlank`) to accept commands.
;
; If `(CommandInput)` is 00h, there's no new command, return.
;
; If `(CommandInput)` contains a command (01..7Fh):
;  - 01h (`COMMAND_STOP`) breaks the current loop;
;  - 02h (`COMMAND_PAUSE`) enters pause loop until pause is reset or new
;	sample is received (breaks the current loop in this case);
;  - 03..7Fh sets `ERROR__UNKNOWN_COMMAND`, but returns gracefully.
;
; If `(CommandInput)` is a sample id (80..FFh):
;  - If new sample priority is the same or higher than the actively playing
;	sample, breaks the current loop and requests new sample playback.
;  - If new sample priority is lower or it's not a sample, return.
;
; Once the command is read and processed, `(CommandInput)` is reset to 00h.
; -----------------------------------------------------------------------------
; OUTPUT:
;	a = 0 (unless stop or playback requested, then we don't even return)
; -----------------------------------------------------------------------------

ProcessCommandInput:

.CommandInput_Initial:	equ	00h	; command input value for self-modifying code

	; NOTE: This actually loads `a` with the value of `(CommandInput)`,
	; because `CommandInput` address itself is set to this operand.
.sm1:	ld	a, .CommandInput_Initial	; 7	read from (CommandInput)
	or	a				; 4	test the value
	ret	z				; 11/5	if input byte is 00h, return
	jp	ProcessCommandInput2		; 10	otherwise, jump to process it
	; Total cycles: 22 cycles (no new input), a lot (otherwise)

	assert $-ProcessCommandInput <= 8
