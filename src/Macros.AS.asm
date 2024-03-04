; ==============================================================================
; ------------------------------------------------------------------------------
; Macros
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Macro to generate sample record in a sample table
; ------------------------------------------------------------------------------

dcSample: macro	SAMPLETYPE, SAMPLEPTR, SAMPLERATE, SAMPLEFLAGS
	dc.b	SAMPLETYPE					; $00	- type

	if SAMPLETYPE=TYPE_PCM
		if (SAMPLERATE+0)>TYPE_PCM_MAX_RATE
			fatal "Invalid sample rate: \sampleRate\. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		dc.b	SAMPLEFLAGS+0							; $01	- flags (optional)
		dc.b	(SAMPLERATE+0)*256/TYPE_PCM_BASE_RATE	; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	SAMPLEPTR								; $04	- start offset
		dc.l	SAMPLEPTR_End							; $08	- end offset

	elseif SAMPLETYPE=TYPE_PCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_PCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			fatal "Invalid sample rate: SAMPLERATE. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	SAMPLEFLAGS+0							; $01	- flags (optional)
		dc.b	$FF										; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	SAMPLEPTR								; $04	- start offset
		dc.l	SAMPLEPTR_End							; $08	- end offset

	elseif SAMPLETYPE=TYPE_DPCM
		if SAMPLERATE>TYPE_DPCM_BASE_RATE
			fatal "Invalid sample rate: SAMPLERATE. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_BASE_RATE Hz"
		endif
		dc.b	SAMPLEFLAGS+0							; $01	- flags (optional)
		dc.b	(SAMPLERATE)*256/TYPE_DPCM_BASE_RATE	; $02	- pitch
		dc.b	0										; $03	- <RESERVED>
		dc.l	SAMPLEPTR								; $04	- start offset
		dc.l	SAMPLEPTR_End							; $08	- end offset

	elseif SAMPLETYPE=TYPE_NONE
		dc.b	0, 0, 0
		dc.l	0, 0

	else
		fatal "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE"
	endif
	endm

; ------------------------------------------------------------------------------
; Macro to include a sample file
; ------------------------------------------------------------------------------

incdac:	macro NAME, PATH
		even
	NAME:	label *
		binclude	PATH
	NAME_End:	label *
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
