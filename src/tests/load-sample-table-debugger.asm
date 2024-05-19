
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; `MegaPCM_LoadSampleTable` test suite
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

	lea		@ST_UnsupportedSampleRate(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w   d0                      ; was sample table loaded successfully?
	beq.s   @SampleTableOk          ; if yes, branch
	RaiseError "TEST SUCCESS%<endl>MegaPCM_LoadSampleTable returned %<.b d0>", MPCM_Debugger_LoadSampleTableException

@SampleTableOk:
	RaiseError "TEST FAILED"			; ... why we're here?...

; ------------------------------------------------------------------------------
@ST_UnsupportedSampleRate:
	dcSample	TYPE_PCM, @PCM_Dummy_32000Hz
	dc.w	-1	; end marker

@ST_SupportedTurboRate:
	dcSample	TYPE_PCM_TURBO, @PCM_Dummy_32000Hz
	dc.w	-1	; end marker

@PCM_Dummy_32000Hz:
	dc.l	'RIFF', $30000000, 'WAVE'

	dc.l	'fmt ', $10000000
	dc.w	$0100					; format = PCM
	dc.w	$0100					; numChannels = 1
	dc.l	$007D0000				; sampleRate = 32000
	dc.l	$007D0000				; byteRange = 32000
	dc.w	$0100					; blockAlign
	dc.w	$0800					; bitsPerSample

	dc.l	'data', $08000000
	dc.l	$12345678, $12345678

@PCM_Dummy_32000Hz_End:
