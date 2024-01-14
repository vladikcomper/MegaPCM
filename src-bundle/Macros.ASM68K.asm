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
			inform 0, "Invalid sample rate. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	(\sampleRate+0)*256/TYPE_PCM_BASE_RATE	; $02	- pitch (optional)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_PCM_TURBO
		if \sampleRate<>TYPE_PCM_TURBO_MAX_RATE
			inform 0, "Invalid sample rate. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	$FF										; $02	- pitch (optional)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRate>TYPE_DPCM_BASE_RATE
			inform 0, "Invalid sample rate. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_BASE_RATE Hz"
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
		inform 0, "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE"
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
