
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; Sample volume test
; ------------------------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; ------------------------------------------------------------------------------

	include	'../lib-68k/mdshell.asm'						; MD Shell library
	include '../build/bundle/asm68k-linkable/MegaPCM.asm'	; Mega PCM library

; ------------------------------------------------------------------------------

	section rom
	xdef	Main

; ------------------------------------------------------------------------------
Main:
	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable

@RunTest:	macro	testHandler
	Console.Write "\testHandler\... "
	bsr		\testHandler
	Console.WriteLine "DONE"
	endm

	@RunTest		Test_SnareSeq
	@RunTest		Test_BGM_FadeInOut

	Console.WriteLine "ALL DONE"
	rts

; ------------------------------------------------------------------------------

Test_BGM_FadeInOut:
	moveq	#$F, d6
	move.b	d6, d0	
	jsr		MegaPCM_SetSFXVolume
	moveq	#$FFFFFF82, d0
	jsr		MegaPCM_PlaySample				; play BGM

	moveq	#3-1, d7

	@fade_in_out_sequence:
		moveq	#$F, d6						; volume = min

		@fade_in_loop:
			Console.Sleep #8						; sleep 8 frames
			move.b	d6, d0
			jsr		MegaPCM_SetSFXVolume
			subq.w	#1, d6
			bpl.s	@fade_in_loop

		moveq	#0, d6						; volume = max
		Console.Sleep #120

		@fade_out_loop:
			Console.Sleep #8						; sleep 8 frames
			move.b	d6, d0
			jsr		MegaPCM_SetSFXVolume
			addq.w	#1, d6
			cmp.w	#$F, d6
			bls.s	@fade_out_loop

		Console.Sleep #120

		dbf		d7, @fade_in_out_sequence

	rts

; ------------------------------------------------------------------------------
Test_SnareSeq:
	moveq	#$F, d6

	@snare_seq:
		Console.Sleep #10
		move.b	d6, d0	
		jsr		MegaPCM_SetVolume
		moveq	#$FFFFFF81, d0
		jsr		MegaPCM_PlaySample
		subq.b	#1, d6
		bpl.s	@snare_seq

	rts

; ------------------------------------------------------------------------------

SampleTable:
	;			type			pointer			Hz
	dcSample	TYPE_PCM,		Snare,			24000							; $81
	dcSample	TYPE_DPCM,		TestBGM,		20500, FLAGS_LOOP|FLAGS_SFX		; $82
	dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	Snare, "../examples/s1-smps-integration/dac/snare.pcm"
	incdac	TestBGM, "tests/test-bgm.dpcm"
	even
