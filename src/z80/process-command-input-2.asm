
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.2
; -----------------------------------------------------------------------------
; Functions for handling command inputs (Part 2)
;
; (c) 2023-2026, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; A continuation of `ProcessCommandInput`
; -----------------------------------------------------------------------------
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
; INPUT:
;	a	= Command (non-zero)
; -----------------------------------------------------------------------------
; OUTPUT:
;	a = 0 (unless stop or playback requested, then we don't even return)
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
