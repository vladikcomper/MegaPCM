
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; Generic macros for M68K bindings
; ------------------------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Stops Z80 and takes over its bus
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

stopZ80: macro opBusReq
	if narg=1
		move.w	#$100, \opBusReq
		@wait\@:bset	#0, \opBusReq
			bne.s	@wait\@
	else
		move.w	#$100, Z80_BUSREQ
		@wait\@:bset	#0, Z80_BUSREQ
			bne.s	@wait\@
	endc
	endm

; ------------------------------------------------------------------------------
; Starts Z80, releases its bus
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

startZ80: macro opBusReq
	if narg=1
		move.w	#0, \opBusReq
	else
		move.w	#0, Z80_BUSREQ
	endc
	endm

; ------------------------------------------------------------------------------
; Checks that Mega PCM is ready for operation
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

waitMegaPCMReady: macro opBusReq
@chk_ready\@:
	stopZ80	\opBusReq
	tst.b	Z80_RAM+Z_MPCM_DriverReady	; is Mega PCM ready?
	bne.s	@ready\@			; if yes, branch
	startZ80 \opBusReq
	move.w	d0, -(sp)
	moveq	#10, d0
	dbf	d0, *				; waste 100+ cycles
	move.w	(sp)+, d0
	bra.s	@chk_ready\@
@ready\@:
	startZ80 \opBusReq
	endm
