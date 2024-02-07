
	include	'../lib-68k/mdshell.asm'
	include	'../build/bundle/asm68k-linkable/MegaPCM.asm'

; ------------------------------------------------------------------------------

	section rom

	xdef	Main

; ------------------------------------------------------------------------------
	rsset	$FFFF8000

v_snddriver_ram:	rs.b	$600

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	Console.WriteLine "Sonic 1 SMPS + Mega PCM 2 Example"
	Console.WriteLine "(c) 2024, Vladikcomper%<endl>"

	jsr		MegaPCM_LoadDriver

	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w	d0
	bne		@SampleTableError

	moveq	#$FFFFFFE4, d0
	jsr		PlaySound
	jsr		UpdateMusic
	moveq	#$FFFFFF8C, d0
	jsr		PlaySound
	jsr		UpdateMusic

	@MainLoop:
		move.w	d6, -(sp)
		jsr		MDDBG__VSync
		jsr		UpdateMusic
		move.w	(sp)+, d6

		addq.w	#1, d6
		move.w	d6, d0
		and.w	#$FF, d0
		bne.s	@no
		moveq	#$FFFFFF8C, d0
		jsr		MegaPCM_PlaySample
	@no:

		bra.s	@MainLoop

; ------------------------------------------------------------------------------
@SampleTableError:
	Console.WriteLine "ERROR: MegaPCM_LoadSampleTable returned %<.b d0>"
	rts

; ------------------------------------------------------------------------------

	include	's1-smps-integration/sample-table.asm'

; ------------------------------------------------------------------------------

	pusho			; save previous options
	opt		L.		; use "." for local labels (AS compatibility)

FixBugs:	equ	1	; want to fix bugs

	include	's1-smps-integration/s1.sounddriver.defs.asm'
	include	's1-smps-integration/s1.sounddriver.asm'

PlaySound:
	move.b	d0,(v_snddriver_ram+v_soundqueue0).w
	rts

	popo			; restore previous options
