
LoadBank:
	push	hl			; 11
	ld	hl, BankRegister	; 10

	rept 7			; 77 cycles
		ld	(hl),a		; 7	; do pins A15-A21
		rrca			; 4
	endr
	ld	(hl),a			; 7	; pin A22
	ld	(hl),l			; 7	; pin A23 is always zero
	pop	hl			; 10
	ret				; 10
