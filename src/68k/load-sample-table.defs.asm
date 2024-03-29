
; ------------------------------------------------------------------------------
; Return error codes for `MegaPCM_LoadSampleTable`
; ------------------------------------------------------------------------------

MPCM_ST_TOO_MANY_SAMPLES:			equ	$01
MPCM_ST_UNKNOWN_SAMPLE_TYPE:		equ	$02

MPCM_ST_PITCH_NOT_SET:				equ	$10

MPCM_ST_WAVE_INVALID_HEADER:		equ	$20
MPCM_ST_WAVE_BAD_AUDIO_FORMAT:		equ	$21
MPCM_ST_WAVE_NOT_MONO:				equ	$22
MPCM_ST_WAVE_NOT_8BIT:				equ	$23
MPCM_ST_WAVE_BAD_SAMPLE_RATE:		equ	$24
MPCM_ST_WAVE_MISSING_DATA_CHUNK:	equ	$25
