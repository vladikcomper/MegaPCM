
; ------------------------------------------------------------------------------
; Definitions for sample table
; ------------------------------------------------------------------------------

FLAGS_SFX:		equ	$01		; sample is SFX, normal drums cannot interrupt it
FLAGS_LOOP:		equ	$02		; loop sample indefinitely

TYPE_NONE:		equ	$00
TYPE_PCM:		equ	'P'
TYPE_PCM_TURBO:	equ	'T'
TYPE_DPCM:		equ	'D'

; ------------------------------------------------------------------------------
; Maximum playback rates:
TYPE_PCM_TURBO_MAX_RATE:	equ	32000 ; Hz
TYPE_PCM_MAX_RATE:			equ	25100 ; Hz
TYPE_DPCM_MAX_RATE:			equ	18550 ; Hz

; Internal driver's base rates for pitched playback.
; NOTICE: They are slightly lower than max rates,
; because the highest pitch is 256/256, not 256/256.
TYPE_PCM_BASE_RATE:			equ	25208 ; Hz
TYPE_DPCM_BASE_RATE:		equ	18643 ; Hz
