
; ------------------------------------------------------------------------------
; Definitions for sample table (`dcSample` macro)
; ------------------------------------------------------------------------------

; "Type" field constants
TYPE_NONE:		equ $00		; marks empty slot
TYPE_PCM:		equ	$02		; PCM/WAV samples
TYPE_PCM_TURBO:	equ	$04		; PCM/WAV samples (32 kHz Turbo playback mode)
TYPE_DPCM:		equ	$06		; DPCM/DPCM-HQ samples
TYPE_DPCM_TURBO:equ	$08		; DPCM/DPCM-HQ samples (25.8 kHz Turbo playback mode)

; "Flags" field constants
FLAGS_LOOP:		equ	$01		; loop sample indefinitely
FLAGS_SFX:		equ	$40		; sample is SFX, normal BGM drums cannot interrupt it

; "Priority" field constants
; Note that SFX and normal samples have their own level of priorities
PRIO_LOW:		equ	$00		; priority level 0 (low)
PRIO_NORMAL:	equ	$10		; priority level 1 (normal) - that's the default
PRIO_HIGH:		equ	$20		; priority level 2 (high)
PRIO_HIGHEST:	equ	$30		; priority level 3 (higest)

; ------------------------------------------------------------------------------
; Maximum playback rates:
TYPE_PCM_TURBO_MAX_RATE:	equ	32000 ; Hz
TYPE_PCM_MAX_RATE:			equ	25100 ; Hz
TYPE_DPCM_TURBO_MAX_RATE:	equ	25800 ; Hz
TYPE_DPCM_MAX_RATE:			equ	20600 ; Hz

; Internal driver's base rates for pitched playback.
; NOTICE: Actual max rates are slightly lower,
; because the highest pitch is 255/256, not 256/256.
TYPE_PCM_BASE_RATE:			equ	25208 ; Hz
TYPE_DPCM_BASE_RATE:		equ	20691 ; Hz
