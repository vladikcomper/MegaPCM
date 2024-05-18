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

dcSample: macro	SAMPLETYPE, SAMPLEPTR, SAMPLERATE, SAMPLEFLAGS
	if ARGCOUNT>4
		fatal "Too many arguments. USAGE: dcSample type, samplePtr, sampleRateHz, flags"
	endif

	dc.b	SAMPLETYPE					; $00	- type

	if SAMPLETYPE=TYPE_PCM
		if (SAMPLERATE+0)>TYPE_PCM_MAX_RATE
			fatal "Invalid sample rate: SAMPLERATE. TYPE_PCM only supports sample rates <= 25100 Hz"
		endif
		dc.b	SAMPLEFLAGS+0							; $01	- flags (optional)
		dc.b	(SAMPLERATE+0)*256/TYPE_PCM_BASE_RATE	; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	SAMPLEPTR								; $04	- start offset
		dc.l	SAMPLEPTR_End							; $08	- end offset

	elseif SAMPLETYPE=TYPE_PCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_PCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			fatal "Invalid sample rate: SAMPLERATE. TYPE_PCM_TURBO only supports sample rate of 32000 Hz"
		endif
		dc.b	SAMPLEFLAGS+0							; $01	- flags (optional)
		dc.b	$FF										; $02	- pitch (optional for .WAV files)
		dc.b	0										; $03	- <RESERVED>
		dc.l	SAMPLEPTR								; $04	- start offset
		dc.l	SAMPLEPTR_End							; $08	- end offset

	elseif SAMPLETYPE=TYPE_DPCM
		if SAMPLERATE>TYPE_DPCM_MAX_RATE
			fatal "Invalid sample rate: SAMPLERATE. TYPE_DPCM only supports sample rates <= 20600 Hz"
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
