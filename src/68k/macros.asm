; ==============================================================================
; ------------------------------------------------------------------------------
; Macros
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Macro to generate sample record in a sample table
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	type - Sample type (e.g. TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE)
;	samplePtr - Sample pointer/name (assigned via `incdac` macro)
;	sampleRateHz? - (Optional) Sample rate in Hz, auto-detected for .WAV, .DPCMQ
;	flags? - (Optional) Additional flags (e.g. FLAGS_SFX or FLAGS_LOOP)
;	priority? - (Optional) Sample priority (PRIO_NORMAL is the default)
; ------------------------------------------------------------------------------

dcSample: macro	type, samplePtr, sampleRateHz, flags, priority
	if (narg>5)|((narg=1)&(\type<>TYPE_NONE))
		inform 2, "Incorrect number of arguments. USAGE: dcSample type, samplePtr, sampleRateHz?, flags?, priority?"
	endif

	if narg<5	; if "priority" is not set, default to PRIO_NORMAL
		@desc\@: equ \flags+\type+PRIO_NORMAL
	else
		@desc\@: equ \flags+\type+((\priority)&3)
	endif

	if \type=TYPE_PCM
		if \sampleRateHz+0>TYPE_PCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags, priority
		dc.b	(\sampleRateHz+0)*256/TYPE_PCM_BASE_RATE; $01	- pitch (based on sample rate)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_PCM_TURBO
		if (\sampleRateHz+0<>TYPE_PCM_TURBO_MAX_RATE)&(\sampleRateHz+0<>0)
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRateHz+0>TYPE_DPCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags, priority
		dc.b	(\sampleRateHz+0)*256/TYPE_DPCM_BASE_RATE; $01	- pitch (based on sample rate)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_DPCM_TURBO
		if (\sampleRateHz+0<>TYPE_DPCM_TURBO_MAX_RATE)&(\sampleRateHz+0<>0)
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_DPCM_TURBO only supports sample rate of \#TYPE_DPCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_NONE
		dc.b	@desc\@									; $00	- type, flags (ignored), priority
		dc.b	0										; $01	- pitch (ignored for empty samples)
		dc.l	0										; $02	- start offset (ignored for empty samples)
		dc.l	0										; $06	- end offset (ignored for empty samples)

	else
		inform 2, "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_DPCM_TURBO, TYPE_NONE"
	endif
	endm

; ------------------------------------------------------------------------------
; Macro to include a sample file
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	name - Name assigned to the sample (label)
;	path - Sample's include path (string)
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
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

MPCM_stopZ80:	macro opBusReq
	pusho
	opt		l-		; make sure "@" marks local labels

	if narg=1
		move.w	#$100, \opBusReq
		@wait\@:
			btst	#0, \opBusReq
			bne.s	@wait\@
	else
		move.w	#$100, MPCM_Z80_BUSREQ
		@wait\@:
			btst	#0, MPCM_Z80_BUSREQ
			bne.s	@wait\@
	endif

	popo
	endm

; ------------------------------------------------------------------------------
; Macro to start Z80 and release its bus
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

MPCM_startZ80:	macro opBusReq
	if narg=1
		move.w	#0, \opBusReq
	else
		move.w	#0, MPCM_Z80_BUSREQ
	endif
	endm

; ------------------------------------------------------------------------------
; Ensures Mega PCM 2 isn't busy writing to YM (other than DAC output obviously)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	opBusReq? - (Optional) Custom operand for Z80_BUSREQ
; ------------------------------------------------------------------------------

MPCM_ensureYMWriteReady:	macro opBusReq
	pusho
	opt		l-		; make sure "@" marks local labels

	@chk_ready\@:
		tst.b	(MPCM_Z80_RAM+Z_MPCM_DriverReady).l
		bne.s	@ready\@
		MPCM_startZ80 \opBusReq
		move.w	d0, -(sp)
		moveq	#10, d0
		dbf		d0, *						; waste 100+ cycles
		move.w	(sp)+, d0
		MPCM_stopZ80 \opBusReq
		bra.s	@chk_ready\@
	@ready\@:

	popo
	endm
