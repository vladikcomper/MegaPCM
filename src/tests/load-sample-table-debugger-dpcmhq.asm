
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.1
;
; `MegaPCM_LoadSampleTable` test suite
; ------------------------------------------------------------------------------
; (c) 2023-2026, Vladikcomper
; ------------------------------------------------------------------------------

	include	'../../lib-68k/mdshell.asm'							; MD Shell library
	include '../../build/bundle/asm68k-linkable/MegaPCM.asm'	; Mega PCM library

; ------------------------------------------------------------------------------

	section rom
	xdef	Main

; ------------------------------------------------------------------------------
Main:
	jsr		MegaPCM_LoadDriver

	lea		@ST_SupportedTurboRate(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w   d0						; was sample table loaded successfully?
	bne.s	@TestFailed				; if not, branch

	lea		@ST_UnsupportedSampleRate(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w   d0						; was sample table loaded successfully?
	beq.s   @TestFailed				; if yes, branch

	RaiseError "TEST SUCCESS%<endl>MegaPCM_LoadSampleTable returned %<.b d0>", MPCM_Debugger_LoadSampleTableException

@TestFailed:
	RaiseError "TEST FAILED"			; ... why we're here?...

; ------------------------------------------------------------------------------
@ST_UnsupportedSampleRate:
	dcSample	TYPE_DPCM, @DPCMHQ_Dummy_25800Hz
	dc.w	-1	; end marker

@ST_SupportedTurboRate:
	dcSample	TYPE_DPCM_TURBO, @DPCMHQ_Dummy_25800Hz
	dc.w	-1	; end marker

@DPCMHQ_Dummy_25800Hz:
	dc.b	"DQ1"
	dc.b	0,0,2			; stream size (bytes)
	dc.w	25800			; sample rate
	dc.b	$00				; delta table type

	dc.b	0, 0			; stream data
@DPCMHQ_Dummy_25800Hz_End:
	even
