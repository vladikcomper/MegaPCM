
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

	; Enter calibration loop, which lasts 3-4 frames
	call	CalibrationLoop

	; Initialize panning
	assert SFXPanInput == PanInput+1		; `PanInput` and `SFXPanInput` should follow each other in memory
	assert (SFXPanInput>>8) == (PanInput>>8)	; both should be in the same 256-byte block for the code below to work

	ld	hl, PanInput
	ld	a, 0C0h
	ld	(hl), a
	inc	l
	ld	(hl), a

	; Mark driver as ready for operation
	ld	a, 'R'
	ld	(DriverReady), a

	TraceMsg	"Mega PCM init finish"

	jr	IdleLoop
