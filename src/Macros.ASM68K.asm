; ==============================================================================
; ------------------------------------------------------------------------------
; Macros
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Macro to generate sample record in a sample table
; ------------------------------------------------------------------------------

dcSample: macro	type, samplePtr, sampleRate, flags
	dc.b	\type					; $00	- type

	if \type=TYPE_PCM
		if \sampleRate+0>TYPE_PCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRate\. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	(\sampleRate+0)*256/TYPE_PCM_BASE_RATE	; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_PCM_TURBO
		if (\sampleRate+0<>TYPE_PCM_TURBO_MAX_RATE)&(\sampleRate+0<>0)
			inform 2, "Invalid sample rate: \sampleRate\. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	$FF										; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRate>TYPE_DPCM_BASE_RATE
			inform 2, "Invalid sample rate: \sampleRate\. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_BASE_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	(\sampleRate)*256/TYPE_DPCM_BASE_RATE	; $02	- pitch
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_NONE
		dc.b	0, 0, 0
		dc.l	0, 0

	else
		inform 2, "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE"
	endif
	endm

; ------------------------------------------------------------------------------
; Macro to include a sample file
; ------------------------------------------------------------------------------

incdac:	macro name, path
		even
	\name:
		incbin	\path
	\name\_End:
	endm

; ------------------------------------------------------------------------------
; Macro to stop Z80 and take over its bus
; ------------------------------------------------------------------------------

MPCM_stopZ80:	macro
	move.w	#$100, ($A11100).l
	bset	#0, ($A11100).l
	bne.s	*-8
	endm

; ------------------------------------------------------------------------------
; Macro to start Z80 and release its bus
; ------------------------------------------------------------------------------

MPCM_startZ80:	macro
	move.w	#0, ($A11100).l
	endm
