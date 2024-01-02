
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Callibration loop module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Loop initialization
; --------------------------------------------------------------

CalibrationLoop_Init:
	di

	ld	a, LOOP_CALIBRATION
	ld	(LoopId), a

	; Setup VInt ...
	ld	hl, CalibrationLoop_VBlank
	ld	(VBlankRoutine), hl

	; Initialize VBlank registers
	exx
	ld	c, 0				; c' = VBlank calibration routine
	exx

	; Wait for VBlank now (vertical synchronization) for perfect frame timing
	ei

.waitVBlank:
	; TODO: Break out of loop in case if VBlank is disabled for good
	nop
	nop
	jr	.waitVBlank

; --------------------------------------------------------------
; Calibration: VBlank phase
; --------------------------------------------------------------
; Registers:
;	c'	= Current routine/frame
;	bc	= ROM read counter
;	de	= ROM pointer for dummy reads
;	hl	= `CalibrationLoop_BenchmarkROMAccess` (for jp)
; --------------------------------------------------------------

CalibrationLoop_VBlank:
	; We need to spend total of 20008 cycles in VBlank
	; Jump code below takes 89 cycles and each routine takes 62 cycles
	; Thus, we need to waste: 20008 - 89 - 62 = 19857
	exx						; 4
	push	bc					; 11
	ld	b, 254					; 7

.loop:
	push	af					; 11
	pop	af					; 10
	push	af					; 11
	pop	af					; 10
	add	hl, bc					; 15
	nop						; 4
	nop						; 4
	djnz	.loop					; 8/13
	; Cycles: (65 + 8) + ((65 + 13) * (b - 1)) = 19807

	inc	bc					; 6
	inc	bc					; 6
	inc	bc					; 6
	pop	bc					; 10

	; Jump to the appropriate routine
	ld	hl, .Calibration_Routines		; 10	hl' = .Calibration_Routines
	ld	a, c					; 4	a = calibration routine
	inc	c					; 4	use next calibration routine
	pop	de					; 10	de' = return address (discarded)
	and	3					; 7	a = calibration routine & 3
	add	a					; 4	a = (calibration routine & 3) * 2
	ld	d, 0					; 7	de' = (calibration routine & 3) * 2
	ld	e, a					; 4	''
	add	hl, de					; 11	hl' += .Calibration_Routines
	ld	e, (hl)					; 7	de' = (hl')
	inc	hl					; 6	''
	ld	d, (hl)					; 7	''
	ex	de, hl					; 4	hl' = routine
	jp	(hl)					; 4	jump to routine
	; Cycles: 89

; --------------------------------------------------------------
.Calibration_Routines:
	dw	.Frame00_Benchmark_68K_ROM_EXX		; c' = 0, 62 cycles
	dw	.Frame01_Benchmark_Z80_RAM_EXX		; c' = 1, 62 cycles
	dw	.Frame02_FinalizeBenchmark		; c' = 2

; --------------------------------------------------------------
.Frame00_Benchmark_68K_ROM_EXX:
	exx						; 4
	ld	bc, 0					; 10	reset read counter
	ld	(CalibrationScore_ROM), bc		; 20	''
	ld	de, ROMWindow				; 10	read from M68K ROM
	ld	hl, CalibrationLoop_BenchmarkReads	; 10
	ei						; 4
	jp	(hl)					; 4	finish VBlank, enter benchmark routine
	; Cycles: 62

; --------------------------------------------------------------
.Frame01_Benchmark_Z80_RAM_EXX:
	exx						; 4
	ld	(CalibrationScore_ROM), bc		; 20	log score after running 68K ROM benchmark
	ld	bc, 0					; 10	reset read counter
	ld	de, 0					; 10	read from Z80 RAM
	ld	hl, CalibrationLoop_BenchmarkReads	; 10
	ei						; 4
	jp	(hl)					; 4	finish VBlank, enter benchmark routine
	; Cycles: 62

; --------------------------------------------------------------
.Frame02_FinalizeBenchmark:
	exx
	ld	(CalibrationScore_RAM), bc		; 20	log score after running Z80 RAM benchmark
	ld	h, b					; 4	hl = RAM score
	ld 	l, c					; 4	''
	ld	de, (CalibrationScore_ROM)		; 20	de = ROM score
	xor	a					; 4	reset Carry flag
	sbc	hl, de					; 15	hl = RAM score - ROM score
	jp	m, .calibrate				; 10	if ROM score > RAM score, 

	; Implements ROM score >>= 3
	ld	a, e					; 4	
	rept	3
		sra	d					; 8	da >>= 1
		rra						; 4	''
	endr						; 12*3 = 36
	ld	e, a					; 4

	xor	a					; 4	reset Carry flag
	sbc	hl, de					; 15
	jr	nc, .done				; 7/12

.calibrate:
	; For deltas smaller than 256 we likely detected an inaccurate emulator, callibrate
	call	PCMLoop_ApplyCalibration
	call	PCMTurboLoop_ApplyCalibration
	call	DPCMLoop_ApplyCalibration

	ld	a, 1
	ld	(CalibrationApplied), a

.done:
	ret						; quit calibration loop

; --------------------------------------------------------------
; Calibration: Benchmark ROM or RAM reads
; --------------------------------------------------------------
; INPUT:
;	bc	= calibration score / read counter
;	de	= ROM or RAM pointer for dummy reads
;	hl	= `CalibrationLoop_BenchmarkReads` (for jp)
; --------------------------------------------------------------

CalibrationLoop_BenchmarkReads:
	rept	8
		ld	a, (de)				; 7+3.3* dummy read (ROM reads add +3.3* cycles)
		inc	bc				; 6	increment read counter
	endr
	jp	(hl)				; 4	jump to the beginning

	; Estimated cycles per `bc` increment:
	; - With bus delay: ((7 + 3.3 + 6) * 8 + 4) / 8 ~= 16.8 cyles
	; - Without bus delay: ((7 + 6) * 8 + 4) / 8 ~= 13.5 cycles
	;
	; Expected scores (without Z80 stops):
	; - **NTSC**: 59659 - 20008 = 39651 cycles outside of VBlank
	;   - With bus delay: 39651 / 16.8 ~= 2360
	;   - Without bus delay: 39651 / 13.5 ~= 2937
	; - **PAL**: 70938 - 20008 = 50930 cycles outside of VBlankv
	;   - With bus delay: 50930 / 16.8 ~= 3032
	;   - Without bus delay: 50930 / 13.5 ~= 3772
	;
	; Actual scores (without Z80 stops):
	; - 2435 ROM / 3016 RAM (NTSC, real hardware, by Mask of Destiny)
	; - 2468 ROM / 3016 RAM (NTSC, Blastem)
	; - 3116 ROM / 3878 RAM (PAL, real hardware, by smds)
