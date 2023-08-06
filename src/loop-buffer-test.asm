
DriverLoop_BufferTest:
	call	UpdateDAC

	exx
	ld	(Debug_BufferPos), hl
	exx

	jr	DriverLoop_BufferTest
