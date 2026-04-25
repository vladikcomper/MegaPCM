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
;	flags? - (Optional) Additional flags (FLAGS_SFX, FLAGS_LOOP, PRIO_NORMAL...)
; ------------------------------------------------------------------------------

__ST_SampleID := $80
__ST_PrevInvokeLoc := 0

dcSample: macro	{INTLABEL}, SAMPLETYPE, SAMPLEPTR, SAMPLERATE, SAMPLEFLAGS
	if (ARGCOUNT>4)|((ARGCOUNT=1)&(SAMPLETYPE<>TYPE_NONE))
		!error "Incorrect number of arguments. USAGE: dcSample type, samplePtr, sampleRateHz?, flags?, priority?"
	endif

	; Track sample ID since start of the sample table (supports multiple tables)
	if (*-__ST_PrevInvokeLoc>10)|(*<__ST_PrevInvokeLoc)
		__ST_SampleID:		set $80
		__ST_PrevInvokeLoc:	set *
	endif

	__ST_PrevInvokeLoc:	set	__ST_PrevInvokeLoc+10
	__ST_SampleID:		set __ST_SampleID+1

__LABEL__
	; Setup default sample description field (based on flags and type)
	if ARGCOUNT<4 ; if "flags" parameter is not specified
		._desc: set SAMPLETYPE|PRIO_NORMAL
	elseif strstr("SAMPLEFLAGS","PRIO_")<>-1
		._desc: set SAMPLETYPE|SAMPLEFLAGS
	else	; if "priority" flag isn't present, default to PRIO_NORMAL
		._desc: set SAMPLETYPE|SAMPLEFLAGS|PRIO_NORMAL
	endif

	._pitch: set 0
	if SAMPLETYPE=TYPE_PCM
		if (SAMPLERATE+0)>TYPE_PCM_MAX_RATE
			!error "Invalid sample rate: SAMPLERATE. TYPE_PCM only supports sample rates <= 25100 Hz"
		endif
		._pitch: set (SAMPLERATE+0)*256/TYPE_PCM_BASE_RATE
		dc.b	._desc									; $00	- type, flags, priority
		dc.b	._pitch									; $01	- pitch (based on sample rate)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_PCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_PCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			!error "Invalid sample rate: SAMPLERATE. TYPE_PCM_TURBO only supports sample rate of 32000 Hz"
		endif
		dc.b	._desc									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_DPCM
		if (SAMPLERATE+0)>TYPE_DPCM_MAX_RATE
			!error "Invalid sample rate: SAMPLERATE. TYPE_DPCM only supports sample rates <= 20600 Hz"
		endif
		._pitch: set (SAMPLERATE+0)*256/TYPE_DPCM_BASE_RATE
		dc.b	._desc									; $00	- type, flags, priority
		dc.b	._pitch									; $01	- pitch (based on sample rate)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_DPCM_TURBO
		if ((SAMPLERATE+0)<>TYPE_DPCM_TURBO_MAX_RATE)&((SAMPLERATE+0)<>0)
			!error "Invalid sample rate: SAMPLERATE. TYPE_DPCM_TURBO only supports sample rate of 25800 Hz"
		endif
		dc.b	._desc									; $00	- type, flags, priority
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	SAMPLEPTR								; $02	- start offset
		dc.l	SAMPLEPTR_End							; $06	- end offset

	elseif SAMPLETYPE=TYPE_NONE
		dc.b	._desc									; $00	- type, flags (ignored), priority
		dc.b	0										; $01	- pitch (ignored for empty samples)
		dc.l	0										; $02	- start offset (ignored for empty samples)
		dc.l	0										; $06	- end offset (ignored for empty samples)

	else
		!error "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_DPCM_TURBO, TYPE_NONE"
	endif

	if "__LABEL__"<>""
		.id:	label __ST_SampleID
		if ._pitch<>0
		.pitch: label ._pitch
		endif
		.desc:	label ._desc
	endif

	endm

; ------------------------------------------------------------------------------
; Macro to include a sample file
; ------------------------------------------------------------------------------

incdac:	macro NAME, PATH
		align 2
	NAME:	label *
		binclude	PATH
	NAME_End:	label *
	endm

; ------------------------------------------------------------------------------
; Macro to play sample
; Fast alternative to `jsr MegaPCM_PlaySample`
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	sampleIdOp - Sample operand (e.g. #$81, #mysample.id, d0)
;
; EXAMPLES:
;	MPCM_play #$81
;	MPCM_play #mysample.id	; if sample has a label in sample table
;	MPCM_play d1			; value stored in d1
; ------------------------------------------------------------------------------

MPCM_play:	macro SAMPLEIDOP
	MPCM_stopZ80
	move.b	SAMPLEIDOP, (MPCM_Z80_RAM+Z_MPCM_CommandInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to pause current sample playback
; Fast alternative to `jsr MegaPCM_PausePlayback`
; ------------------------------------------------------------------------------

MPCM_pause:	macro
	MPCM_stopZ80
	move.b	#Z_MPCM_COMMAND_PAUSE, (MPCM_Z80_RAM+Z_MPCM_CommandInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to unpause playback
; Fast alternative to `jsr MegaPCM_UnpausePlayback`
; ------------------------------------------------------------------------------

MPCM_unpause:	macro
	MPCM_stopZ80
	move.b	#0, (MPCM_Z80_RAM+Z_MPCM_CommandInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to stop all playback
; Fast alternative to `jsr MegaPCM_StopPlayback`
; ------------------------------------------------------------------------------

MPCM_stop:	macro
	MPCM_stopZ80
	move.b	#Z_MPCM_COMMAND_STOP, (MPCM_Z80_RAM+Z_MPCM_CommandInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set panning for normal (non-SFX) samples
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	panOp - pan operand (e.g. #$40, #$80, #$C0 or d0)
; ------------------------------------------------------------------------------

MPCM_setPan:	macro	PANOP
	if ("PANOP"="$40")|("PANOP"="$80")|("PANOP"="$C0")
		!warning "MPCM_setPan: Possibly erroneous operand: PANOP. Did you mean #PANOP?"
	endif
	MPCM_stopZ80
	move.b	PANOP, (MPCM_Z80_RAM+Z_MPCM_PanInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to sets panning for SFX samples (added with FLAGS_SFX)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	panOp - pan operand (e.g. #$40, #$80, #$C0 or d0)
; ------------------------------------------------------------------------------

MPCM_setSfxPan:	macro	PANOP
	if ("PANOP"="$40")|("PANOP"="$80")|("PANOP"="$C0")
		!warning "MPCM_setPan: Possibly erroneous operand: PANOP. Did you mean #PANOP?"
	endif
	MPCM_stopZ80
	move.b	PANOP, (MPCM_Z80_RAM+Z_MPCM_SFXPanInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set volume for normal (non-SFX) samples
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	volumeOp - volume operand (e.g. #0 (max), #$F (min) or d0)
; ------------------------------------------------------------------------------

MPCM_setVol:	macro	VOLUMEOP
	MPCM_stopZ80
	move.b	VOLUMEOP, (MPCM_Z80_RAM+Z_MPCM_VolumeInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set volume for SFX samples (added with FLAGS_SFX)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	volumeOp - volume operand (e.g. #0 (max), #$F (min) or d0)
; ------------------------------------------------------------------------------

MPCM_setSfxVol:	macro	VOLUMEOP
	MPCM_stopZ80
	move.b	VOLUMEOP, (MPCM_Z80_RAM+Z_MPCM_SFXVolumeInput).l
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set pitch (alternative to `jsr MegaPCM_SetActiveSamplePitch`)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	pitchOp	- pitch operand (e.g. #mypcm.pitch, #0 = 0%, #$FF = 100% base rate)
; ------------------------------------------------------------------------------

MPCM_setPitch:	macro PITCHOP
	MPCM_stopZ80
	move.b	PITCHOP, (MPCM_Z80_RAM+Z_MPCM_ActiveSamplePitch).l
	MPCM_startZ80
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
		move.w	#$100, (MPCM_Z80_BUSREQ).l
		.wait:
			bset	#0, (MPCM_Z80_BUSREQ).l
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
		move.w	#0, (MPCM_Z80_BUSREQ).l
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
