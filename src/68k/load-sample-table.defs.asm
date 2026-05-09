
; ------------------------------------------------------------------------------
; Return error codes for `MegaPCM_LoadSampleTable`
; ------------------------------------------------------------------------------

MPCM_ST_TOO_MANY_SAMPLES:			equ $01		; Too many samples in table
MPCM_ST_UNKNOWN_SAMPLE_TYPE:		equ $02		; Unknown sample type or missing end marker. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE

MPCM_ST_PITCH_NOT_SET:				equ $10		; Sample rate can't be auto-detected (only works for .WAV files). Please set it manually

MPCM_ST_WAVE_INVALID_HEADER:		equ $20		; WAVE error: Invalid WAVE header
MPCM_ST_WAVE_BAD_AUDIO_FORMAT:		equ $21		; WAVE error: Unsupported audio format. Only PCM is supported
MPCM_ST_WAVE_NOT_MONO:				equ $22		; WAVE error: Audio must be mono
MPCM_ST_WAVE_NOT_8BIT:				equ $23		; WAVE error: Audio must be 8-bit unsigned PCM
MPCM_ST_WAVE_BAD_SAMPLE_RATE:		equ $24		; WAVE error: Unsupported sample rate. Use <=25100 Hz for TYPE_PCM or 32000 Hz for TYPE_PCM_TURBO.
MPCM_ST_WAVE_MISSING_DATA_CHUNK:	equ $25		; WAVE error: Failed to locate 'data' chunk

MPCM_ST_DPCM_HQ_UNSUPPORTED_VERSION:equ $30		; DPCM-HQ error: Unsupported version specified in header
MPCM_ST_DPCM_HQ_BAD_SAMPLE_RATE:	equ $31		; DPCM-HQ error: Unsupported sample rate. Use <=20600 Hz for TYPE_DPCM or 25800 Hz for TYPE_DPCM_TURBO.
