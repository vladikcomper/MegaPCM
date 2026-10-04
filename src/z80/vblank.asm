
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.2
; -----------------------------------------------------------------------------
; VBlank entry point and utilities
;
; (c) 2023-2026, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; VBlank handler
; -----------------------------------------------------------------------------

	assert $ == 38h	; VBlank handler must be located at offset 38h

VBlank:
	jp	VoidInterrupt	; NOTE: self-modifying code

VBlankRoutine:	equ	VBlank+1

; -----------------------------------------------------------------------------
VoidInterrupt:
	TraceException	"Invalid interrupt"
	ret

; -----------------------------------------------------------------------------
; Waits for VBlank, then wastes cycles until end of VBlank
; -----------------------------------------------------------------------------
; NOTES:
; 1) MegaPCM commands to play samples are still processed during VBlank;
; 2) By the end of this call, interrupts are disabled.	
; -----------------------------------------------------------------------------
; USES:
;	af, hl
; -----------------------------------------------------------------------------

WaitVBlankEnd:
	di
	ld	hl, (VBlankRoutine)
	ld	(VBlankRoutineCopy), hl
	ld	hl, WaitVBlankEnd_VBlank
	ld	(VBlankRoutine), hl
	; fallthrough

; -----------------------------------------------------------------------------
; Idle loop that waits for VBlank and does nothing
; -----------------------------------------------------------------------------
; NOTE: This loop is No-Return (NR) by default, only VBlank handler itself
; may break out of it by skipping its return address in the stack.
; -----------------------------------------------------------------------------

WaitVBlank_NR:
	ei
	
.waitLoop:
	nop
	nop
	jr	.waitLoop

; -----------------------------------------------------------------------------
; VBlank routine used by `WaitVBlankEnd`
; -----------------------------------------------------------------------------
; USES:
;	af, hl
; -----------------------------------------------------------------------------

WaitVBlankEnd_VBlank:
	ld	hl, 19857-10			; 10
	call	WasteCycles			; 19857-10

	rst	ProcessCommandInput		; 11+22	returns a=0 once driver input is processed

	ld	hl, (VBlankRoutineCopy)		; restore previous VBlank routine
	ld	(VBlankRoutine), hl		; ''

	inc	sp				; skip return address
	inc	sp				; ''
	ret					; return to caller
