
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.1
;
; "All macros" test suite
; ------------------------------------------------------------------------------
; (c) 2023-2026, Vladikcomper
; ------------------------------------------------------------------------------

	if __AS__
		include	"../../lib-68k/mdshell.as.asm"					; MD Shell blob
		include "../../build/bundle/as/MegaPCM.Macros.asm"		; Mega PCM macros
		include "../../build/bundle/as/MegaPCM.asm"				; Mega PCM blob

	elseif ~def(__LINKABLE__)
		include	"../../lib-68k/mdshell.asm68k.asm"				; MD Shell blob
		include "../../build/bundle/asm68k/MegaPCM.Macros.asm"	; Mega PCM macros
		include "../../build/bundle/asm68k/MegaPCM.asm"			; Mega PCM blob
		opt l+

	else
		include	"../../lib-68k/mdshell.asm"						; MD Shell library
		include "../../build/bundle/asm68k-linkable/MegaPCM.asm"	; Mega PCM library

		section rom
		xdef	Main
		opt l+
	endif

; ------------------------------------------------------------------------------
SampleTable1:
					dcSample	TYPE_DPCM, 		Kick, 		8000								; $81
tbl1_kick_low:		dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_LOW					; $82
					dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_NORMAL					; $83
tbl1_kick_high:		dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_HIGH					; $84
tbl1_kick_highest:	dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_HIGHEST				; $85
					dcSample	TYPE_NONE,		,			,		FLAGS_SFX	| PRIO_HIGHEST	; $86
tbl1_null_bgm:		dcSample	TYPE_NONE,		,			,		PRIO_HIGHEST				; $87
tbl1_voice:			dcSample	TYPE_PCM_TURBO,	Voice,		32000, 	FLAGS_SFX	| PRIO_NORMAL	; $88
					dcSample	TYPE_PCM_TURBO,	Voice,		32000, 	FLAGS_SFX	| PRIO_HIGHEST	; $89
					dc.w	-1

; ------------------------------------------------------------------------------
SampleTable2_a:
					dcSample	TYPE_DPCM,		Kick,		 8000	; $81
					dcSample	TYPE_DPCM, 		Kick,		 8000	; $82
					dcSample	TYPE_DPCM, 		Kick,		 8000	; $83
					dcSample	TYPE_DPCM, 		Kick,		 8000	; $84
					dc.w	-1

					dc.l	0, 0, 0, 0
					dc.l	0, 0, 0, 0

; ------------------------------------------------------------------------------
SampleTable2_b:
tbl2b_sample_81:	dcSample	TYPE_DPCM,		Kick,		 8000	; $81
tbl2b_sample_82:	dcSample	TYPE_DPCM, 		Kick,		 8000	; $82
tbl2b_sample_83:	dcSample	TYPE_DPCM, 		Kick,		 8000	; $83
tbl2b_sample_84:	dcSample	TYPE_DPCM, 		Kick,		 8000	; $84
					dc.w	-1

; ------------------------------------------------------------------------------
Main:
	Console.WriteLine "This ROM has no runtime logic"
	rts

; ------------------------------------------------------------------------------
	if __AS__=0
		; Validate Sample Table 1 properties
		static_assert tbl1_kick_low.id=$82
		static_assert tbl1_kick_high.id=$84
		static_assert tbl1_kick_highest.id=$85
		static_assert tbl1_null_bgm.id=$87
		static_assert tbl1_voice.id=$88

		; Validate Sample Table 2b properties
		static_assert tbl2b_sample_81.id=$81
		static_assert tbl2b_sample_82.id=$82
		static_assert tbl2b_sample_83.id=$83
		static_assert tbl2b_sample_84.id=$84
	else
		; Validate Sample Table 1 properties
		static_assert 'tbl1_kick_low.id=$82'
		static_assert 'tbl1_kick_high.id=$84'
		static_assert 'tbl1_kick_highest.id=$85'
		static_assert 'tbl1_null_bgm.id=$87'
		static_assert 'tbl1_voice.id=$88'

		; Validate Sample Table 2b properties
		static_assert 'tbl2b_sample_81.id=$81'
		static_assert 'tbl2b_sample_82.id=$82'
		static_assert 'tbl2b_sample_83.id=$83'
		static_assert 'tbl2b_sample_84.id=$84'
	endif

; ------------------------------------------------------------------------------
MacroExpansions:
	; WARNING! This is not how you send commands to Mega PCM!
	; This just checks if macro code generation is sane
	MPCM_play #tbl1_kick_low.id
	MPCM_play #tbl1_kick_high.id
	MPCM_play #tbl1_kick_highest.id
	MPCM_play #tbl1_null_bgm.id
	MPCM_play #tbl1_voice.id

	MPCM_play #tbl2b_sample_81.id
	MPCM_play #tbl2b_sample_82.id
	MPCM_play #tbl2b_sample_83.id
	MPCM_play #tbl2b_sample_84.id

	MPCM_pause
	MPCM_unpause
	MPCM_stop

	MPCM_setPan #$40
	MPCM_setPan #$80
	MPCM_setPan #$C0
	MPCM_setSfxPan #$40
	MPCM_setSfxPan #$80
	MPCM_setSfxPan #$C0

	MPCM_setVol #0
	MPCM_setVol #$F
	MPCM_setSfxVol #0
	MPCM_setSfxVol #$F

	MPCM_setPitch #tbl1_kick_low.pitch

	MPCM_startZ80
	MPCM_stopZ80
	MPCM_ensureYMWriteReady
MacroExpansions_End:
	rts
; ------------------------------------------------------------------------------

	incdac	Kick, "../../examples/s1-smps-integration/dac/snare.pcm"
	incdac	Voice, "../../examples/common/voice.wav"
