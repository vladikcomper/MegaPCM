; ==============================================================================
; ------------------------------------------------------------------------------
; Macros
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Macro to generate sample record in a sample table
; ------------------------------------------------------------------------------

dcSample: macro	type, samplePtr, sampleRateHz, flags
	if narg>4
		inform 2, "Too many arguments. USAGE: dcSample type, samplePtr, sampleRateHz, flags"
	endif

	dc.b	\type					; $00	- type

	if \type=TYPE_PCM
		if \sampleRateHz+0>TYPE_PCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	(\sampleRateHz+0)*256/TYPE_PCM_BASE_RATE; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_PCM_TURBO
		if (\sampleRateHz+0<>TYPE_PCM_TURBO_MAX_RATE)&(\sampleRateHz+0<>0)
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	$FF										; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	\samplePtr								; $04	- start offset
		dc.l	\samplePtr\_End							; $08	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRateHz>TYPE_DPCM_BASE_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_BASE_RATE Hz"
		endif
		dc.b	\flags+0								; $01	- flags (optional)
		dc.b	(\sampleRateHz)*256/TYPE_DPCM_BASE_RATE	; $02	- pitch
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
	pusho
	opt		l-		; make sure "@" marks local labels

	move.w	#$100, ($A11100).l
	@wait\@:
		bset	#0, ($A11100).l
		bne.s	@wait\@

	popo
	endm

; ------------------------------------------------------------------------------
; Macro to start Z80 and release its bus
; ------------------------------------------------------------------------------

MPCM_startZ80:	macro
	move.w	#0, ($A11100).l
	endm

; ------------------------------------------------------------------------------
; Ensures Mega PCM 2 isn't busy writing to YM (other than DAC output obviously)
; ------------------------------------------------------------------------------

MPCM_ensureYMWriteReady:	macro
	pusho
	opt		l-		; make sure "@" marks local labels

	@chk_ready\@:
		tst.b	($A00000+Z_MPCM_DriverReady).l
		bne.s	@ready\@
		MPCM_startZ80
		move.w	d0, -(sp)
		moveq	#10, d0
		dbf		d0, *						; waste 100+ cycles
		move.w	(sp)+, d0
		MPCM_stopZ80
		bra.s	@chk_ready\@
	@ready\@:

	popo
	endm
