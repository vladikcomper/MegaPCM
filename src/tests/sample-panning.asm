
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; Sample panning test
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
	lea		SampleTable(pc), a0					; load Sonic 1's sample table
	jsr		MegaPCM_LoadSampleTable				; ''

	Console.WriteLine "Initiating panning test..."
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "Normal: Snare (RIGHT)"
	moveq	#$40, d0
	jsr		MegaPCM_SetPan
	moveq	#$FFFFFF82, d0
	jsr		MegaPCM_PlaySample
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "Normal: Snare (LEFT)"
	moveq	#$FFFFFF80, d0
	jsr		MegaPCM_SetPan
	moveq	#$FFFFFF82, d0
	jsr		MegaPCM_PlaySample
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "SFX: Voice (default=CENTER)"
	moveq	#$FFFFFF84, d0
	jsr		MegaPCM_PlaySample
	Console.Sleep #120							; sleep 2 seconds

	Console.WriteLine "SFX: Voice (RIGHT)"
	moveq	#$40, d0
	jsr		MegaPCM_SetSFXPan
	moveq	#$FFFFFF84, d0
	jsr		MegaPCM_PlaySample
	Console.Sleep #120							; sleep 2 seconds

	Console.WriteLine "Normal: Timpani (previous=LEFT)"
	moveq	#$FFFFFF83, d0
	jsr		MegaPCM_PlaySample
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "ALL DONE"
	rts

; ------------------------------------------------------------------------------

SampleTable:
	;			type			pointer		Hz
	dcSample	TYPE_DPCM, 		Kick, 		8000				; $81
	dcSample	TYPE_PCM,		Snare,		24000				; $82
	dcSample	TYPE_DPCM, 		Timpani, 	7250				; $83
	dcSample	TYPE_PCM_TURBO,	Voice,		32000, FLAGS_SFX	; $84
	dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	Kick, "../examples/s1-smps-integration/dac/kick.dpcm"
	incdac	Snare, "../examples/s1-smps-integration/dac/snare.pcm"
	incdac	Timpani, "../examples/s1-smps-integration/dac/timpani.dpcm"
	incdac	Voice, "../examples/s1-smps-integration/dac/voice.wav"
	even
