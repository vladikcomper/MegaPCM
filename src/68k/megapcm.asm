
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

	if def(__DEBUG__)
		include	'../../lib-68k/debugger.asm'		; MD Debugger external library
	else
		include '../../lib-68k/debugger-stub.asm'	; dummy debug macros
	endif

; ------------------------------------------------------------------------------

	; Import Z80 symbols
	include	'../../build/z80/megapcm.exports.asm'

; ------------------------------------------------------------------------------

	include	'equates.asm'
	include	'macros.asm'
	include	'sample-table.defs.asm'

; ------------------------------------------------------------------------------
; External Mega PCM API
; ------------------------------------------------------------------------------

	public	on
	include	'load-driver.asm'
	include	'load-sample-table.asm'
	if def(__DEBUG__)
		include	'load-sample-table.debugger.asm'
	endif
	if def(__LINKABLE__)
		; Only include command routines (e.g. MegaPCM_PlaySample) in linkable
		; builds, because for other builds they are included in the bundle.
		include	'commands.asm'
	endif
	public	off

; ------------------------------------------------------------------------------
; Mega PCM Z80 blob
; ------------------------------------------------------------------------------

MegaPCM:
	incbin	"../../build/z80/megapcm.bin"
MegaPCM_End:
	even
