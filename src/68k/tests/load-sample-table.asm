
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; `MegaPCM_LoadSampleTable` test suite
; ------------------------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; ------------------------------------------------------------------------------

	include	'../../lib-68k/mdshell.asm'				; MD Shell bindings

; ------------------------------------------------------------------------------

	include	'macros.asm'							; for `dcSample`/`MPCM_stopZ80`/`MPCM_startZ80`
	include	'equates.asm'							; `MPCM_Z80_RAM`, `MPCM_Z80_BUSREQ` etc
	include	'../../build/z80/megapcm.exports.asm'	; for `Z_MPCM_SampleTable`

	include	'sample-table.defs.asm'					; for `TYPE_PCM` etc

; ------------------------------------------------------------------------------

	section rom

	xdef	Main

; ------------------------------------------------------------------------------
Main:
	jsr		MegaPCM_LoadDriver

@RunTest:	macro	testHandler
	Console.Write "\testHandler\... "
	bsr		\testHandler
	Console.WriteLine "OK"
	endm

	@RunTest	Test_WAVE_InvalidWaveContainers
	@RunTest	Test_SampleRates

	Console.WriteLine "%<pal2>ALL DONE"
	rts

; ------------------------------------------------------------------------------

	include	'load-driver.asm'						; for `MegaPCM_LoadDriver`
	include	'load-sample-table.asm'					; for `MegaPCM_LoadSampleTable`

; ------------------------------------------------------------------------------


; ==============================================================================
; ------------------------------------------------------------------------------
; Test: Mega PCM 2 shouldn't accept AIFF and NIST containers
; ------------------------------------------------------------------------------

Test_WAVE_InvalidWaveContainers:
	lea		@ST_AIFFContainer, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_WAVE_INVALID_HEADER
	assert.l	a0, eq, #@ST_AIFFContainer

	lea		@ST_NISTContainer, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_WAVE_INVALID_HEADER
	assert.l	a0, eq, #@ST_NISTContainer
	rts

; ------------------------------------------------------------------------------
@ST_AIFFContainer:
	dcSample	TYPE_PCM, @AIFFContainer
	dc.w	-1	; end marker

@AIFFContainer:
	dc.l	'AIFF'
	; we won't even bother with container contents, it shouldn't be read ...
@AIFFContainer_End:

; ------------------------------------------------------------------------------
@ST_NISTContainer:
	dcSample	TYPE_PCM, @NISTContainer
	dc.w	-1	; end marker

@NISTContainer:
	dc.l	'NIST'
	; we won't even bother with container contents, it shouldn't be read ...
@NISTContainer_End:
; ------------------------------------------------------------------------------


; ==============================================================================
; ------------------------------------------------------------------------------
; Test: Auto-detecting valid and invalid sample rates from WAVE files
; ------------------------------------------------------------------------------

Test_SampleRates:
	lea		@ST_UndefinedSampleRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_PITCH_NOT_SET
	assert.l	a0, eq, #@ST_UndefinedSampleRate

	lea		@ST_UnsupportedSampleRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_WAVE_BAD_SAMPLE_RATE
	assert.l	a0, eq, #@ST_UnsupportedSampleRate

	lea		@ST_SupportedTurboRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq
	assert.l	a0, eq, #@ST_SupportedTurboRate
	rts

; ------------------------------------------------------------------------------
@ST_UndefinedSampleRate:
	dcSample	TYPE_PCM, @RawPCM	; raw PCMs must specify sample rate
	dc.w	-1	; end marker

@RawPCM:
	dc.l	$12345678
@RawPCM_End:

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

; ------------------------------------------------------------------------------
; Mega PCM Z80 blob
; ------------------------------------------------------------------------------

MegaPCM:
	incbin	"../../build/z80/megapcm.bin"
MegaPCM_End:
	even
