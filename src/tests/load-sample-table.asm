
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

@RunTest:	macro	testHandler
	Console.Write "\testHandler\... "
	bsr		\testHandler
	Console.WriteLine "OK"
	endm

	@RunTest	Test_WAVE_InvalidWaveContainers
	@RunTest	Test_WAVE_SampleRates
	@RunTest	Test_DPCMHQ_Headers
	@RunTest	Test_DPCMHQ_SampleRates

	Console.WriteLine "%<pal2>ALL DONE"
	rts

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

Test_WAVE_SampleRates:
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


; ==============================================================================
; ------------------------------------------------------------------------------
; Test: DPCM-HQ header parsing
; ------------------------------------------------------------------------------

Test_DPCMHQ_Headers:
	lea		@ST_ValidDPCMHQ, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq
	assert.l	a0, eq, #@ST_ValidDPCMHQ

	lea		@ST_UnsupportedDPCMHQ, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_DPCM_HQ_UNSUPPORTED_VERSION
	assert.l	a0, eq, #@ST_UnsupportedDPCMHQ
	rts

; ------------------------------------------------------------------------------
@ST_ValidDPCMHQ:
	dcSample	TYPE_DPCM, @DPCMHQ_Valid, 16000
	dc.w	-1	; end marker
	
@DPCMHQ_Valid:
	dc.b	"DQ1"
	dc.b	0,0,2			; stream size (bytes)
	dc.w	32000			; sample rate (must be ignored if specified in table)
	dc.b	$00				; delta table type

	dc.b	0, 0			; stream data
@DPCMHQ_Valid_End:
	even

; ------------------------------------------------------------------------------
@ST_UnsupportedDPCMHQ:
	dcSample	TYPE_DPCM, @DPCMHQ_Unsupported, 16000
	dc.w	-1	; end marker
	
@DPCMHQ_Unsupported:
	dc.b	"DQ2"			; unknown version
	dc.l	-1				; this data shouldn't be read
	dc.b	-1				; ''
@DPCMHQ_Unsupported_End:
	even
; ------------------------------------------------------------------------------


; ==============================================================================
; ------------------------------------------------------------------------------
; Test: Auto-detecting valid and invalid sample rates from DPCM-HQ files
; ------------------------------------------------------------------------------

Test_DPCMHQ_SampleRates:
	lea		@ST_UndefinedSampleRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_PITCH_NOT_SET
	assert.l	a0, eq, #@ST_UndefinedSampleRate

	lea		@ST_UnsupportedSampleRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq, #MPCM_ST_DPCM_HQ_BAD_SAMPLE_RATE
	assert.l	a0, eq, #@ST_UnsupportedSampleRate

	lea		@ST_SupportedTurboRate, a0
	jsr		MegaPCM_LoadSampleTable
	assert.w	d0, eq
	assert.l	a0, eq, #@ST_SupportedTurboRate
	rts

	rts

; ------------------------------------------------------------------------------
@ST_UndefinedSampleRate:
	dcSample	TYPE_DPCM, @DPCM_Dummy
	dc.w	-1	; end marker

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

@DPCM_Dummy:
	dc.b	0, 0
@DPCM_Dummy_End:
	even
