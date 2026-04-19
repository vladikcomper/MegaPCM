##
## This is a direct source code port of `68k/macros.asm` targeting AS.
##
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

dcSample: macro	SAMPLETYPE, SAMPLEPTR, SAMPLERATE, SAMPLEFLAGS, SAMPLEPRIO
	if (ARGCOUNT>5)|((ARGCOUNT=1)&(SAMPLETYPE<>TYPE_NONE))
		fatal "Incorrect number of arguments. USAGE: dcSample type, samplePtr, sampleRateHz?, flags?, priority?"
	endif

	if ARGCOUNT<5
		.desc: set SAMPLEFLAGS+SAMPLETYPE+PRIO_NORMAL
	else
		.desc: set SAMPLEFLAGS+SAMPLETYPE+(SAMPLEPRIO&3)
	endif

	if SAMPLETYPE=TYPE_PCM
		if (SAMPLERATE+0)>TYPE_PCM_MAX_RATE
			fatal "Invalid sample rate: SAMPLERATE. TYPE_PCM only supports sample rates <= 25100 Hz"
		endif
		dc.b	.desc									; $00	- type, flags, priority
		dc.b	(SAMPLERATE+0)*256/TYPE_PCM_BASE_RATE	; $01	- pitch (based on sample rate)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_PCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_PCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			fatal "Invalid sample rate: SAMPLERATE. TYPE_PCM_TURBO only supports sample rate of 32000 Hz"
		endif
		dc.b	.desc									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_DPCM
		if (SAMPLERATE+0)>TYPE_DPCM_MAX_RATE
			fatal "Invalid sample rate: SAMPLERATE. TYPE_DPCM only supports sample rates <= 20600 Hz"
		endif
		dc.b	.desc									; $00	- type, flags, priority
		dc.b	(SAMPLERATE+0)*256/TYPE_DPCM_BASE_RATE	; $01	- pitch (based on sample rate)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_DPCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_DPCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			fatal "Invalid sample rate: SAMPLERATE. TYPE_DPCM_TURBO only supports sample rate of 25800 Hz"
		endif
		dc.b	.desc									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_NONE
		dc.b	.desc									; $00	- type, flags (ignored), priority
		dc.b	0										; $01	- pitch (ignored for empty samples)
		dc.l	0										; $02	- start offset (ignored for empty samples)
		dc.l	0										; $06	- end offset (ignored for empty samples)

	else
		fatal "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_DPCM_TURBO, TYPE_NONE"
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

MPCM_stopZ80:	macro OPBUSREQ
	if ARGCOUNT==1
		move.w	#$100, OPBUSREQ
		.wait:
			bset	#0, OPBUSREQ
			bne.s	.wait
	else
		move.w	#$100, MPCM_Z80_BUSREQ
		.wait:
			bset	#0, MPCM_Z80_BUSREQ
			bne.s	.wait
	endif
	endm

; ------------------------------------------------------------------------------
; Macro to start Z80 and release its bus
; ------------------------------------------------------------------------------

MPCM_startZ80:	macro OPBUSREQ
	if ARGCOUNT==1
		move.w	#0, OPBUSREQ
	else
		move.w	#0, MPCM_Z80_BUSREQ
	endif
	endm

; ------------------------------------------------------------------------------
; Ensures Mega PCM 2 isn't busy writing to YM (other than DAC output obviously)
; ------------------------------------------------------------------------------

MPCM_ensureYMWriteReady:	macro OPBUSREQ
	.chk_ready:
		tst.b	(MPCM_Z80_RAM+Z_MPCM_DriverReady).l
		bne.s	.ready
		MPCM_startZ80	OPBUSREQ
		move.w	d0, -(sp)
		moveq	#10, d0
		dbf		d0, *						; waste 100+ cycles
		move.w	(sp)+, d0
		MPCM_stopZ80	OPBUSREQ
		bra.s	.chk_ready
	.ready:
	endm
