
; ==============================================================================
; ------------------------------------------------------------------------------
; Loads Mega PCM driver and waits for its initialization
; ------------------------------------------------------------------------------

MegaPCM_LoadDriver:

	; ----------------------------------------------------------------------
	; USES:
	@var0:		equr	d0	;	generic variable #1
	@var1:		equr	d1	;	generic variable #2
	@src:		equr	a0	;	generic source pointer
	@dest:		equr	a1	;	generic destination pointer
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; INTERNAL REGISTERS:
	move.l	a3, -(sp)
	@z80_busreq:	equr	a3	;	= Z80_BUSREQ (optimization)
	; ----------------------------------------------------------------------

	lea	Z80_BUSREQ, @z80_busreq
	@op_z80_reset:	equs	'Z80_RESET-Z80_BUSREQ(@z80_busreq)'

	move.w	#$100, @var0
	move.w	@var0, (@z80_busreq)		; request Z80 bus (stop Z80)
	move.w	@var0, \@op_z80_reset		; release Z80 reset

	; Loads Mega PCM program into Z80 memory ...
	KDebug.WriteLine "Loading Mega PCM 2.0 driver..."
	lea	MegaPCM(pc), @src
	lea	Z80_RAM, @dest
	move.w	#(MegaPCM_End-MegaPCM)-1, @var1

	@LoadLoop:
		move.b	(@src)+, (@dest)+
		dbf	@var1, @LoadLoop

	; Starts Z80 and prepares for "wait Mega PCM ready" cycle
	moveq	#0, @var1
	move.w	@var1, \@op_z80_reset		; reset Z80
	lea	Z80_RAM+Z_MPCM_DriverReady, @src; @src = Z_MPCM_DriverReady
	nop
	nop
	move.w	@var0, \@op_z80_reset		; release Z80 reset
	move.w	@var1, (@z80_busreq)		; release Z80 bus (start Z80)

	; Waits until Mega PCM reports that it's ready
	KDebug.WriteLine "Waiting for Mega PCM initialization..."
	bra.s	@Wait

	@WaitReadyLoop:
		stopZ80 (@z80_busreq)
		move.b	(@src), @var1		; d1 = Z_MPCM_DriverReady
		startZ80 (@z80_busreq)
		cmp.b	#'R', @var1		; is driver ready?
		beq.s	@Done			; if yes, branch

	@Wait:	; WARNING! Mega PCM performs ROM/RAM benchmarks during boot to
		; calibrate playback for inaccurate emulators.
		; It's highly recommended not to interrupt Z80 too often during
		; this phase, so benchmark is accurate.
		; Calibration takes roughly 3 frames, so don't worry about
		; wasting too many cycles.
		move.w	#$FFF, @var0
		dbf	@var0, *		; waste 40k+ cycles
		bra.s	@WaitReadyLoop

@Done:	; ----------------------------------------------------------------------
	; Release additional registers and quit
	move.l	(sp)+, a3
	rts
