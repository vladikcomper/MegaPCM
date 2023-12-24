
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Callibration loop module
;
; (c) 2023, Vladikcomper
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

	ei

; --------------------------------------------------------------
; Calibration: Wait for the initial VBlank
; --------------------------------------------------------------
; NOTICE: We'd want to start benchmarking outside of VBlank
; right away, but we cannot risk starting it mid-frame.
; So we pull off "VSync" for perfect synchronization.
; --------------------------------------------------------------

CalibrationLoop_WaitVBlank:
	nop
	nop
	jr	CalibrationLoop_WaitVBlank

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
		ld	a, (de)				; 7+3.3	dummy ROM read
		inc	bc				; 6	increment read counter
	endr
	jp	(hl)				; 4	jump to the beginning
	; Estimated cycles per `bc` increment:
	; - With bus delay: ((7 + 3.3 + 6) * 8 + 4) / 8 ~= 16.8 cyles
	; - Without bus delay: ((7 + 6) * 8 + 4) / 8 ~= 13.5 cycles

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
	sbc	hl, de					; 15	hl = RAM score - ROM score
	ld	a, h
	or	a
	jp	p, .delta_positive

	; Implements: hl = -hl
	xor	a					; 	a = 0
	sub	l					;	a = 0 - l
	ld	l, a					;	l = 0 - l
	sbc	h					;	a = 0 - h - l - carry
	sub	l					;	a = 0 - h - l - (0 - l) - carry = 0 - h - carry
	ld	h, a					;	h = 0 - h - carry
	or	a

.delta_positive:
	jr	nz, .done				;	if delta is larger than 256, jump
	ld	a, l					;
	cp	180					;	if delta is larger than 180, jump
	jr	nc, .done				;	''

	; For deltas smaller than 256 we likely detected an inaccurate emulator, callibrate
	call	PCMLoop_ApplyCalibration
	call	PCMTurboLoop_ApplyCalibration
	call	DPCMLoop_ApplyCalibration

	ld	a, 1
	ld	(CalibrationApplied), a

.done:
	; TODO: Implement
	ret						; quit calibration loop
