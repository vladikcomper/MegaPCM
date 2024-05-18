
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
	lea		@ErrorCodeToDescription-4(pc), a1
	lea		@Str_UnknownError(pc), a2			; fallback in case error description isn't found

	@findErrorDescriptionLoop:
		addq.w	#4, a1							; skip string pointer
		cmp.b	(a1), d0
		bhi.s	@findErrorDescriptionLoop
		blo.s	@errorDescriptionLoopDone		; search failure
		move.l	(a1), a2						; a2 = error description string
	@errorDescriptionLoopDone:

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
@ErrorCodeToDescription:
	;		Raw error code							  String pointer
	dc.l	(MPCM_ST_TOO_MANY_SAMPLES<<24) 			| @Str_TooManySamples
	dc.l	(MPCM_ST_UNKNOWN_SAMPLE_TYPE<<24)		| @Str_UnknownSampleType
	dc.l	(MPCM_ST_PITCH_NOT_SET<<24)				| @Str_PitchNotSet
	dc.l	(MPCM_ST_WAVE_INVALID_HEADER<<24)		| @Str_WaveInvalidHeader
	dc.l	(MPCM_ST_WAVE_BAD_AUDIO_FORMAT<<24)		| @Str_WaveBadAudioFormat
	dc.l	(MPCM_ST_WAVE_NOT_MONO<<24)				| @Str_WaveNotMono
	dc.l	(MPCM_ST_WAVE_NOT_8BIT<<24)				| @Str_WaveNot8bit
	dc.l	(MPCM_ST_WAVE_BAD_SAMPLE_RATE<<24)		| @Str_BadSampleRate
	dc.l	(MPCM_ST_WAVE_MISSING_DATA_CHUNK<<24)	| @Str_MissingDataChunk
	dc.b	$FF, 0		; end marker

; ------------------------------------------------------------------------------
@Str_TooManySamples:
	dc.b	"Too many samples in table", 0
@Str_UnknownSampleType:
	dc.b	"Unknown sample type or missing end marker. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE", 0
@Str_PitchNotSet:
	dc.b	"Sample rate can't be auto-detected (only works for .WAV files). Please set it manually", 0
@Str_WaveInvalidHeader:
	dc.b	"WAVE error: Invalid WAVE header", 0
@Str_WaveBadAudioFormat:
	dc.b	"WAVE error: Unsupported audio format. Only PCM is supported", 0
@Str_WaveNotMono:
	dc.b	"WAVE error: Audio must be mono", 0
@Str_WaveNot8bit:
	dc.b	"WAVE error: Audio must be 8-bit PCM", 0
@Str_BadSampleRate:
	dc.b	"WAVE error: Unsupported sample rate. Use <=\#TYPE_PCM_MAX_RATE\ Hz for TYPE_PCM or \#TYPE_PCM_TURBO_MAX_RATE\ Hz for TYPE_PCM_TURBO.", 0
@Str_MissingDataChunk:
	dc.b	"WAVE error: Failed to locate 'data' chunk", 0
@Str_UnknownError:
	dc.b	"Uknown error code", 0
	even
