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

dcSample: macro	*, type, samplePtr, sampleRateHz, flags
	; Make sure macro is invoked correctly
	if (narg>4)|((narg=1)&(\type<>TYPE_NONE))
		inform 2, "Incorrect number of arguments. USAGE: dcSample type, samplePtr, sampleRateHz?, flags?"
	endif

	; Setup default sample description field (based on flags and type)
	if narg<4 ; if "flags" parameter is not specified
		@desc\@: equ \type|PRIO_NORMAL
	elseif instr("\flags", "PRIO_")
		@desc\@: equ \type|\flags
	else	; if "priority" flag isn't present, default to PRIO_NORMAL
		@desc\@: equ \type|\flags|PRIO_NORMAL
	endif

	; Track sample ID since start of the sample table (supports multiple tables)
	; This trick works for both linkable and non-linkable builds
	@macroInvokeId: substr 2,,"\@"
	@macroPrevInvokeId: = @macroInvokeId-1
	if ~def(__ST_SampleID)
		__ST_SampleID: = $80
	elseif def(__ST_SamplePtr_\#@macroPrevInvokeId)
		if (*-__ST_SamplePtr_\#@macroPrevInvokeId>10)
			__ST_SampleID: = $80
		endif
	endif

	__ST_SamplePtr\@:	equ	*	; offset of the current sample for back-reference
	__ST_SampleID: = __ST_SampleID+1

	; Define additional properties if the label is given
	if ~strcmp("\*","")
\*:		equ	*
\*.id: 	equ	__ST_SampleID
	endif

	@pitch\@: = 0
	if \type=TYPE_PCM
		if \sampleRateHz+0>TYPE_PCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM only supports sample rates <= \#TYPE_PCM_MAX_RATE Hz"
		endif
		@pitch\@: = (\sampleRateHz+0)*256/TYPE_PCM_BASE_RATE
		dc.b	@desc\@									; $00	- type, flags
		dc.b	@pitch\@								; $01	- pitch (based on sample rate)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_PCM_TURBO
		if (\sampleRateHz+0<>TYPE_PCM_TURBO_MAX_RATE)&(\sampleRateHz+0<>0)
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_PCM_TURBO only supports sample rate of \#TYPE_PCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_DPCM
		if \sampleRateHz+0>TYPE_DPCM_MAX_RATE
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_DPCM only supports sample rates <= \#TYPE_DPCM_MAX_RATE Hz"
		endif
		@pitch\@: = (\sampleRateHz+0)*256/TYPE_DPCM_BASE_RATE
		dc.b	@desc\@									; $00	- type, flags
		dc.b	@pitch\@								; $01	- pitch (based on sample rate)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_DPCM_TURBO
		if (\sampleRateHz+0<>TYPE_DPCM_TURBO_MAX_RATE)&(\sampleRateHz+0<>0)
			inform 2, "Invalid sample rate: \sampleRateHz\. TYPE_DPCM_TURBO only supports sample rate of \#TYPE_DPCM_TURBO_MAX_RATE Hz"
		endif
		dc.b	@desc\@									; $00	- type, flags
		dc.b	$FF										; $01	- pitch (ignored in Turbo mode)
		dc.l	\samplePtr								; $02	- start offset
		dc.l	\samplePtr\_End							; $06	- end offset

	elseif \type=TYPE_NONE
		dc.b	@desc\@									; $00	- type, flags (ignored)
		dc.b	0										; $01	- pitch (ignored for empty samples)
		dc.l	0										; $02	- start offset (ignored for empty samples)
		dc.l	0										; $06	- end offset (ignored for empty samples)

	else
		inform 2, "Unknown sample type. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_DPCM_TURBO, TYPE_NONE"
	endif

	if ~strcmp("\*","")
	if (@pitch\@<>0)
\*.pitch: 	equ	@pitch\@
	endif
\*.desc:	equ	@desc\@
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

MPCM_play:	macro sampleIdOp
	MPCM_stopZ80
	move.b	\sampleIdOp, MPCM_Z80_RAM+Z_MPCM_CommandInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to pause current sample playback
; Fast alternative to `jsr MegaPCM_PausePlayback`
; ------------------------------------------------------------------------------

MPCM_pause:	macro
	MPCM_stopZ80
	move.b	#Z_MPCM_COMMAND_PAUSE, MPCM_Z80_RAM+Z_MPCM_CommandInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to unpause playback
; Fast alternative to `jsr MegaPCM_UnpausePlayback`
; ------------------------------------------------------------------------------

MPCM_unpause:	macro
	MPCM_stopZ80
	move.b	#0, MPCM_Z80_RAM+Z_MPCM_CommandInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to stop all playback
; Fast alternative to `jsr MegaPCM_StopPlayback`
; ------------------------------------------------------------------------------

MPCM_stop:	macro
	MPCM_stopZ80
	move.b	#Z_MPCM_COMMAND_STOP, MPCM_Z80_RAM+Z_MPCM_CommandInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set panning for normal (non-SFX) samples
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	panOp - pan operand (e.g. #$40, #$80, #$C0 or d0)
; ------------------------------------------------------------------------------

MPCM_setPan:	macro	panOp
	if strcmp("\panOp","$40")|strcmp("\panOp","$80")|strcmp("\panOp","$C0")
		inform 1, "MPCM_setPan: Possibly erroneous operand: \panOp\. Did you mean #\panOp\?"
	endif
	MPCM_stopZ80
	move.b	\panOp, MPCM_Z80_RAM+Z_MPCM_PanInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to sets panning for SFX samples (added with FLAGS_SFX)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	panOp - pan operand (e.g. #$40, #$80, #$C0 or d0)
; ------------------------------------------------------------------------------

MPCM_setSfxPan:	macro	panOp
	if strcmp("\panOp","$40")|strcmp("\panOp","$80")|strcmp("\panOp","$C0")
		inform 1, "MPCM_setSfxPan: Possibly erroneous operand: \panOp\. Did you mean #\panOp\?"
	endif
	MPCM_stopZ80
	move.b	\panOp, MPCM_Z80_RAM+Z_MPCM_SFXPanInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set volume for normal (non-SFX) samples
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	volumeOp - volume operand (e.g. #0 (max), #$F (min) or d0)
; ------------------------------------------------------------------------------

MPCM_setVol:	macro	volumeOp
	MPCM_stopZ80
	move.b	\volumeOp, MPCM_Z80_RAM+Z_MPCM_VolumeInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set volume for SFX samples (added with FLAGS_SFX)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	volumeOp - volume operand (e.g. #0 (max), #$F (min) or d0)
; ------------------------------------------------------------------------------

MPCM_setSfxVol:	macro	volumeOp
	MPCM_stopZ80
	move.b	\volumeOp, MPCM_Z80_RAM+Z_MPCM_SFXVolumeInput
	MPCM_startZ80
	endm

; ------------------------------------------------------------------------------
; Macro to set pitch (alternative to `jsr MegaPCM_SetActiveSamplePitch`)
; ------------------------------------------------------------------------------
; ARGUMENTS:
;	pitchOp	- pitch operand (e.g. #mypcm.pitch, #0 = 0%, #$FF = 100% base rate)
; ------------------------------------------------------------------------------

MPCM_setPitch:	macro pitchOp
	MPCM_stopZ80
	move.b	\pitchOp, MPCM_Z80_RAM+Z_MPCM_ActiveSamplePitch
	MPCM_startZ80
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
