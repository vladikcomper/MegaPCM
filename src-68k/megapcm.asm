
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; M68K bindings for Mega PCM
; ------------------------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; ------------------------------------------------------------------------------

	section	rom

; ------------------------------------------------------------------------------

	xdef	MegaPCM_LoadDriver
	xdef	MegaPCM_LoadSampleTable
	xdef	MegaPCM_PlaySample
	xdef	MegaPCM_PausePlayback
	xdef	MegaPCM_UnpausePlayback
	xdef	MegaPCM_StopPlayback

; ------------------------------------------------------------------------------

	include	'../lib-68k/debugger.asm'	; MD Debugger external library

; ------------------------------------------------------------------------------

	; Import Z80 symbols
	include	'../build/megapcm.exports.asm'

; ------------------------------------------------------------------------------

	include	'vars.asm'
	include	'macros.asm'
	include	'sample-table.defs.asm'

; ------------------------------------------------------------------------------

	include	'load-driver.asm'
	include	'load-sample-table.asm'
	include	'play-sample.asm'

; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM driver blob
; ------------------------------------------------------------------------------

MegaPCM:
	incbin	"../build/megapcm.bin"
MegaPCM_End:
	even
