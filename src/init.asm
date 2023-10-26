
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

	; Mark driver as ready for operation
	ld	a, 'R'
	ld	(DriverReady), a

	jr	IdleLoop_Init
