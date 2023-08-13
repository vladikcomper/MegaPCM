
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

	; Initialize index registers
	ld	iy, DriverIO_RAM

	; Mark driver as ready for operation
	ld	(iy+sDriverIO.OUT_ready), 01h	

	jr	IdleLoop_Init
