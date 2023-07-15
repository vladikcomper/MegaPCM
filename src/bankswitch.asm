
; ===============================================================
; ---------------------------------------------------------------
; Routines to control bank-switching
; ---------------------------------------------------------------
; Bank-Switch Registers Set:
;	b'	= Current Bank Number
;	c'	= Last Bank Number
;	de'	= Bank Register
;	hl'	= End offset (bytes to play in last bank)
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; Inits bank-switch system and loads first bank
; ---------------------------------------------------------------

InitBankSwitching:
	exx
	ld	d, (ix+s_pos+1)
	ld	e, (ix+s_pos)		; de' = start offset (in first bank)
	ld	h, (ix+e_pos+1)
	ld	l, (ix+e_pos)		; hl' = end offset (in last bank)
	ld	b, (ix+s_bank)		; b'  = start bank number
	ld	c, (ix+e_bank)		; c'  = end bank number
	ld	a, b			; load start bank number
	cp	c			; does the sample end in the first bank?
	jr	nz, .len_ok		; if not, branch
	sbc	hl, de			; hl' = end offset - start offset
	set	7, h			; make the number 8000h-based
.len_ok:
	ld	de,BankRegister		; de' = bank register
	jp	LoadBank

; ---------------------------------------------------------------
; Subroutine to switch to the next bank
; ---------------------------------------------------------------

LoadNextBank:
	exx
	inc	b		; increase bank number
	ld	a,b		; load bank number

LoadBank:
	ld	(de), a	; A15
	rrca
	ld	(de), a	; A16
	rrca
	ld	(de), a	; A17
	rrca
	ld	(de), a	; A18
	rrca
	ld	(de), a	; A19
	rrca
	ld	(de), a	; A20
	rrca
	ld	(de), a	; A21
	rrca
	ld	(de), a	; A22
	xor	a	; a = 0
	ld	(de), a	; A23
	exx
	ret
