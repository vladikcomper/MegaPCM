
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Bankswitching routines
;
; (c) 2023, Vladikcomper
; --------------------------------------------------------------


; NOTE: This variable is a part of self-modifying instruction (see `SetBank`)
CurrentBank:	equ	SetBank.sm1+1

; -----------------------------------------------------------------------------
; Loads the specified bank
; -----------------------------------------------------------------------------
; INPUT:
;	a	= Bank id
; 
; USES:
;	a
; -----------------------------------------------------------------------------

SetBank:

._DYNAMIC_VALUE:	equ	0FFh	; initial bank value for self-modifying code

.sm1:	cp	._DYNAMIC_VALUE		; 7	are we in this bank already?
	jp	nz, SetBank2		; 10	if not, branch
	ret				; 10

; -----------------------------------------------------------------------------
; Loads the specified bank without checking if it's selected already
; -----------------------------------------------------------------------------
; INPUT:
;	a	= Bank id
; 
; USES:
;	a
; -----------------------------------------------------------------------------

	align	8			; align so it's RST-callable
SetBank2:
	ld	(CurrentBank), a	; 13	update current bank
	push	hl			; 11
	ld	hl, BankRegister	; 10

	rept 7			; 77 cycles
		ld	(hl), a		; 7	do pins A15-A21
		rrca			; 4
	endr
	ld	(hl),a			; 7	pin A22
	ld	(hl),l			; 7	pin A23 is always zero
	pop	hl			; 10
	ret				; 10
