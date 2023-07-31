
; --------------------------------------------------------------
; Fast-call routine to keep DAC playing
; --------------------------------------------------------------

UpdateDAC:		; = 11 bytes
	exx			; 4
	ex	af,af'		; 4	save accumulator
	ld	a,(hl)		; 7	load sample
	or	a		; 4	check it
	jr	z,.done		; 7	end of buffer is indicated with sample 0
	ld	(de),a		; 7	send it to YM
	inc	l		; 4	roll through 256-byte buffer
.done:	ex	af,af'		; 4	load saved accumulator
	exx			; 4
	ret			; 10

	; Total execution time:
	; Normal:		51+11 = 63 cycles
	; Buffer overflow:	49+11 = 60 cycles

	; We must play every 162 cycles to support 22 kHz
	; We can spare: 99 cycles
