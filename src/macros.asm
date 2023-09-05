
; --------------------------------------------------------------
;
; --------------------------------------------------------------

	macro	DebugMsg str
	ifdef __DEBUG__
	push	hl
	ld	hl, .string
	ld	(VMConsole), hl
	pop	hl
	jr	.string_end

.string:
	db	str, 0h
.string_end:
	endif
	endm

; --------------------------------------------------------------
;
; --------------------------------------------------------------

	macro	DebugErrorTrap	ErrorCode
	ifdef __DEBUG__
	ld	a, ErrorCode
	call	Debug_ErrorTrap
	endif
	endm
