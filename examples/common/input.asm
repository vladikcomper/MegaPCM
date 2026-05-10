; -----------------------------------------------------------------------------
; Reads 3-button joypad
; -----------------------------------------------------------------------------

ReadJoypads:
	lea		Joypad, a0			; address where joypad states are written
	lea		$A10003, a1			; first	joypad port

ReadJoypad:
	move.b	#0, (a1)			; command to poll for A/Start
	nop							; wait for port (0/1)
	moveq	#$FFFFFFC0, d1		; wait for port (1/1) ... and do useful work (0/1)
	move.b	(a1), d0			; get data for A/Start
	lsl.b	#2, d0
	move.b	#$40, (a1)			; command to poll for B/C/UDLR
	nop							; wait for port (0/1)
	and.b	d1, d0				; wait for port (1/1) ... and do useful work (1/1)
	move.b	(a1), d1			; get data for B/C/UDLR
	andi.b	#$3F, d1
	or.b	d1, d0				; d0 = held buttons bitfield (negated)
	not.b	d0					; d0 = held buttons bitfield (normal)
	move.b	(a0), d1			; d1 = previously held buttons
	eor.b	d0, d1				; toggle off buttons that are being pressed
	move.b	d0, (a0)+			; put raw controller input (for held buttons)
	and.b	d0, d1
	move.b	d1, (a0)+			; put pressed controller input
	rts

; -----------------------------------------------------------------------------
; Processes joypad input using a LUT of handlers
; -----------------------------------------------------------------------------
; INPUT:
;		a0		- a look-up table of button handlers (press, then hold)
; -----------------------------------------------------------------------------

ProcessJoypadInput:

	; Process "on press" handlers
	lea		(a0), a1
	move.b	Joypad+1, d0			; d0 = pressed buttons
	lea		JoypadHeldTimers, a1
	lea		@ProcessPressHandler(pc), a2
	bsr.s	@ProcessHandlers

	; Process "on hold" handlers
	move.b	Joypad, d0				; d0 = held buttons
	lea		JoypadHeldTimers, a1
	lea		@ProcessHoldHandler(pc), a2

	@ProcessHandlers:
		@__it:	= 0
		rept 8
			add.b	d0, d0
			bcc.s	@next_\#@__it
			jsr		(a2)
		@next_\#@__it:
			addq.w	#1, a1				; next delay slot
			addq.w	#4, a0				; next handler
		@__it:	= @__it+1
		endr
		rts

; -----------------------------------------------------------------------------
@ProcessHoldHandler:
	subq.b	#1, (a1)
	bne.s	@ret
	move.b	#3, (a1)
	bra.s	@ProcessHandler

; -----------------------------------------------------------------------------
@ProcessPressHandler:
	move.b	#30, (a1)				; set initial "on press" delay
	; fallthrough

@ProcessHandler:
	movem.l	d0/a0-a2, -(sp)
	move.l	(a0), d0
	beq.s	@skip
	move.l	d0, a0
	jsr		(a0)
@skip:
	movem.l	(sp)+, d0/a0-a2
@ret:
	rts
