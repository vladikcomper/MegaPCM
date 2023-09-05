
InitDriver:
	di				; disable interrupts
	im	1			; interrupt mode 1

	; Clear work RAM (uses Blast processing(tm))
	ld	sp, WorkRAM_End
	ld	bc, 0000h
	rept	(WorkRAM_End-WorkRAM)/2
		push	bc
	endr

	; Initialize stack
	ld	sp, Stack

	; Set YM for DAC playback
	ld	hl, YM_Port0_Reg
	ld	(hl), 2Bh		; YM => Send 2B 80 (enable DAC)
	inc	l			; ''
	ld	(hl), 80h		; ''
	inc	l			; ''
	ld	(hl), 0B6h		; YM => Send B6 C0 (set DAC panning to LR)
	inc	l			; ''
	ld	(hl), 0C0h		; ''

	; Mark driver as ready for operation
	ld	a, 'R'
	ld	(DriverReady), a

	jr	IdleLoop_Init
