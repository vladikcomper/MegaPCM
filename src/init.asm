
InitDriver:
	di				; disable interrupts
	ld	sp, Stack		; initialize stack

	; -------------------
	; Setup YM registers
	; -------------------

	ld	hl, YM_Port0_Ctrl

	; YM: Enable DAC (send 2B 80 to Port 0)
	ld	(hl), 2Bh
	inc	l
	ld	(hl), 80h
	dec	l

	; YM: Set DAC panning to LR (send B6 C0 to Port 0)
	; NOTICE: We may take this out ...
	;ld	(hl), 0B6h
	;inc	l
	;ld	(hl), 0C0h
	;dec	l			; optimized out

	; YM: Initialize DAC playback
	ld	(hl), 2Ah

	; ------------------------------
	; Setup "Update DAC" registers
	; ------------------------------

	exx
	ld	hl, SampleBuffer
	ld	de, YM_Port0_Data
	exx

	jr	DriverLoop_BufferTest
