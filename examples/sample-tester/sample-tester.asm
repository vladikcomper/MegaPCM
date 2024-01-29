
	include	'../lib-68k/mdshell.asm'
	include	'../build/bundle/asm68k-linkable/MegaPCM.asm'

; ------------------------------------------------------------------------------

	section rom

	xdef	Main

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	Console.WriteLine "Mega PCM 2.0 Simple tester"
	Console.WriteLine "(c) 2024, Vladikcomper%<endl>"

	Console.Write "Loading Mega PCM driver... "
	jsr		MegaPCM_LoadDriver
	Console.WriteLine "OK"

	Console.Write "Loading Sample table... "
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w	d0
	bne		@SampleTableError
	Console.WriteLine "OK"

	Console.WriteLine "Initiating sample playback...%<endl>"
	move.b	#$81, d0
	jsr		MegaPCM_PlaySample

	Console.Write "PLAYING"
	pea		0.w

	@MainLoop:
		jsr		MDDBG__VSync
		subq.w	#8, (sp)
		moveq	#3, d1
		and.b	(sp), d1
		lea		@Str_Dots(pc,d1.w), a0
		Console.Write "%<setx,8>%<.l a0 str>"
		bra.s	@MainLoop

; ------------------------------------------------------------------------------
@Str_Dots:
	dc.b	"....    ", 0
	even

; ------------------------------------------------------------------------------
@SampleTableError:
	Console.WriteLine "FAILED"
	Console.WriteLine "MegaPCM_LoadSampleTable returned %<.b d0>"
	rts

; ------------------------------------------------------------------------------
; Default sample table
; ------------------------------------------------------------------------------

SampleTable:
	;			type			pointer		Hz		flags			  id
	dcSample	TYPE_PCM_TURBO, SampleLoop, ,	FLAGS_LOOP		; $81
	dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	SampleLoop, 'sample-tester/sample-loop.wav'
