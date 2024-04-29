##
## This is a direct source code port of `68k/load-sample-table.debugger.asm` targeting AS.
##
; ------------------------------------------------------------------------------
; DEBUGGER: Displays details for `MegaPCM_LoadSampleTable` error code
; ------------------------------------------------------------------------------
; INPUT:
;		d0	.w	Error code returned by `MegaPCM_LoadSampleTable`
;		a0		Pointer to faulty sample
; ------------------------------------------------------------------------------

MPCM_Debugger_LoadSampleTableException:

	; Print raw error code
	Console.Write "%<pal1>Error code: %<pal0>%<.b d0>%<endl>"

	; Print error description
	lea		.ErrorCodeToDescription-1(pc), a1
	lea		.Str_UnknownError(pc), a2			; fallback in case error description isn't found

	.findErrorDescriptionLoop:
		addq.w	#1, a1							; skip string pointer
		cmp.b	(a1)+, d0
		bhi.s	.findErrorDescriptionLoop
		blo.s	.errorDescriptionLoopDone		; search failure
		moveq	#0, d1
		move.b	(a1), d1
		add.w	d1, d1
		lea		-1(a1, d1), a2					; a2 = error description string
		KDebug.WriteLine "%<.l a2 sym>"

	.errorDescriptionLoopDone:

	Console.Write "%<pal1>Error description:%<endl>%<pal0>%<.l a2 str>%<endl>%<endl>"

	; Print sample data
	Console.WriteLine "%<pal1>RAW SAMPLE RECORD:"
	Console.WriteLine "%<pal2>Type: %<pal0>%<.b (a0)>"
	Console.WriteLine "%<pal2>Flags: %<pal0>%<.b 1(a0)>"
	Console.WriteLine "%<pal2>Pitch: %<pal0>%<.b 2(a0)>"
	Console.WriteLine "%<pal2>Start: %<pal0>%<.l 4(a0) sym>"
	Console.WriteLine "%<pal2>End: %<pal0>%<.l 8(a0) sym>"

	rts

; ------------------------------------------------------------------------------
.ErrorCodeToDescription:
	;		Raw error code						String pointer / 2 (to fit in 8 bits)
	dc.b	MPCM_ST_TOO_MANY_SAMPLES, 			(.Str_TooManySamples-*)>>1
	dc.b	MPCM_ST_UNKNOWN_SAMPLE_TYPE,		(.Str_UnknownSampleType-*)>>1
	dc.b	MPCM_ST_PITCH_NOT_SET,				(.Str_PitchNotSet-*)>>1
	dc.b	MPCM_ST_WAVE_INVALID_HEADER,		(.Str_WaveInvalidHeader-*)>>1
	dc.b	MPCM_ST_WAVE_BAD_AUDIO_FORMAT,		(.Str_WaveBadAudioFormat-*)>>1
	dc.b	MPCM_ST_WAVE_NOT_MONO,				(.Str_WaveNotMono-*)>>1
	dc.b	MPCM_ST_WAVE_NOT_8BIT,				(.Str_WaveNot8bit-*)>>1
	dc.b	MPCM_ST_WAVE_BAD_SAMPLE_RATE,		(.Str_BadSampleRate-*)>>1
	dc.b	MPCM_ST_WAVE_MISSING_DATA_CHUNK,	(.Str_MissingDataChunk-*)>>1
	dc.b	$FF, 0		; end marker

; ------------------------------------------------------------------------------
.Str_TooManySamples:
	dc.b	"Too many samples in table", 0
	even
.Str_UnknownSampleType:
	dc.b	"Unknown sample type or missing end marker. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE", 0
	even
.Str_PitchNotSet:
	dc.b	"Sample rate can't be auto-detected (only works for .WAV files). Please set it manually", 0
	even
.Str_WaveInvalidHeader:
	dc.b	"WAVE error: Invalid WAVE header", 0
	even
.Str_WaveBadAudioFormat:
	dc.b	"WAVE error: Unsupported audio format. Only PCM is supported", 0
	even
.Str_WaveNotMono:
	dc.b	"WAVE error: Audio must be mono", 0
	even
.Str_WaveNot8bit:
	dc.b	"WAVE error: Audio must be 8-bit PCM", 0
	even
.Str_BadSampleRate:
	dc.b	"WAVE error: Unsupported sample rate. Use <={TYPE_PCM_MAX_RATE} Hz for TYPE_PCM or {TYPE_PCM_TURBO_MAX_RATE} Hz for TYPE_PCM_TURBO.", 0
	even
.Str_MissingDataChunk:
	dc.b	"WAVE error: Failed to locate 'data' chunk", 0
	even
.Str_UnknownError:
	dc.b	"Uknown error code", 0
	even
