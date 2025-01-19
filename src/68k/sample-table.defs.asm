
; ------------------------------------------------------------------------------
; Definitions for sample table
; ------------------------------------------------------------------------------

FLAGS_LOOP:		equ	$01		; loop sample indefinitely
FLAGS_SFX:		equ	$40		; sample is SFX, normal drums cannot interrupt it
FLAGS_SAMPLE:	equ	$80		; marks slot as a playable sample

TYPE_NONE:		equ	$00
TYPE_PCM:		equ	$02
TYPE_PCM_TURBO:	equ	$04
TYPE_DPCM:		equ	$06

; ------------------------------------------------------------------------------
; Maximum playback rates:
TYPE_PCM_TURBO_MAX_RATE:	equ	32000 ; Hz
TYPE_PCM_MAX_RATE:			equ	25100 ; Hz
TYPE_DPCM_MAX_RATE:			equ	20600 ; Hz

; Internal driver's base rates for pitched playback.
; NOTICE: Actual max rates are slightly lower,
; because the highest pitch is 255/256, not 256/256.
TYPE_PCM_BASE_RATE:			equ	25208 ; Hz
TYPE_DPCM_BASE_RATE:		equ	20691 ; Hz
