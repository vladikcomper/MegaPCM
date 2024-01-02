
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Driver initialization routine
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

InitDriver:
	TraceMsg	"Mega PCM init start"

	; Clear work RAM (uses Blast processing(tm))
	ld	sp, WorkRAM_End
	ld	hl, 0000h
	ld	b, (WorkRAM_End-WorkRAM)/2
.clearWorkRAM:
	push	hl
	djnz	.clearWorkRAM

	; Initialize stack
	ld	sp, Stack

	; Enter calibration loop for 3-4 frames
	call	CalibrationLoop_Init

	; Mark driver as ready for operation
	ld	a, 'R'
	ld	(DriverReady), a

	TraceMsg	"Mega PCM init finish"

	jr	IdleLoop_Init
