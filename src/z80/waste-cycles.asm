
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Cycle water for timing purposes
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

CycleWaster:	; This is a part of `WasteCycles` routine, see below

.CYCLES_PER_LOOP: = 32	; should be power of 2!
.CYCLES_OUTSIDE_LOOP: = 128

	; Waste exactly .CYCLES_PER_LOOP-4 cycles
	rept .CYCLES_PER_LOOP/4-1
		nop					; 4
	endr

	; This counts towards .CYCLES_OUTSIDE_LOOP (see `WasteCycles` below)
	pop	de				; 10
	ret					; 10

; --------------------------------------------------------------
; Accurately wastes the given number of cycles
; --------------------------------------------------------------
; WARNING: This routine expects relatively large numbers, more
; than 256 cycles. Smaller waste loops should be done manually.
; Waster works with a step of 4 cycles, meaning it may have up
; to 3 cycle error, which is fine for large numbers.
;
; INPUT:
;	hl	- Number of cycles to waste (min 256)
;
; USES:
;	af, hl
; --------------------------------------------------------------

WasteCycles:	; +17 cycles for `call WasteCycles`, included in .CYCLES_OUTSIDE_LOOP

; Just inherit local labels from "CycleWaster"
.CYCLES_PER_LOOP: = CycleWaster.CYCLES_PER_LOOP
.CYCLES_OUTSIDE_LOOP: = CycleWaster.CYCLES_OUTSIDE_LOOP

	; This counts towards .CYCLES_OUTSIDE_LOOP
	push	de				; 11
	ld	de, .CYCLES_OUTSIDE_LOOP+.CYCLES_PER_LOOP	; 10
	or	a				; 4	Carry=0
	sbc	hl, de				; 15	CYCLES -= .CYCLES_OUTSIDE_LOOP
	ld	de, .CYCLES_PER_LOOP		; 10

	; This wastes exactly .CYCLES_PER_LOOP on each iteration
.wasteCyclesLoop:
	sbc	hl, de				; 15	CYCLES -= .CYCLES_PER_LOOP
	jr	z, .waste98cycles		; 7/12	edge case: we know how many cycles to waste now
	jp	nc, .wasteCyclesLoop		; 10
	; Cycles per loop: 32 (.CYCLES_PER_LOOP)

	; This counts towards .CYCLES_OUTSIDE_LOOP
	ld	a, l				; 4	a = l (-.CYCLES_PER_LOOP+1..-1)
	neg					; 4	a = -l (1..CYCLES_PER_LOOP-1)
	rrca					; 4	a >>= 1
	rrca					; 4	a >>= 1
	and	(.CYCLES_PER_LOOP/4)-1		; 7
	ld	hl, CycleWaster			; 10	DO NOT OPTIMIZE! Aligns .CYCLES_OUTSIDE_LOOP
	ld	l, a				; 4	this only works if CycleWaster is aligned on 256-byte boundary
	jp	(hl)				; 4

	; Assetion to ensure the jump trick above works
	assert	(CycleWaster&0FFh) == 0

; --------------------------------------------------------------
.waste98cycles:
	pop	de				; 10
	push	de				; 11
	inc	de				; 6
	add	hl, hl				; 11
	jr	CycleWaster			; 12	branch will waste 20 + 32-4 cycles
