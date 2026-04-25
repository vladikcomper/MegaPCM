
	include	"common/demo-bootloader.asm"

; ------------------------------------------------------------------------------

SampleTable:
				;			type			pointer		Hz		flags
kick:			dcSample	TYPE_DPCM, 		Kick, 		8000
kick_low:		dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_LOW
kick_normal:	dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_NORMAL
kick_high:		dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_HIGH
kick_highest:	dcSample	TYPE_DPCM, 		Kick, 		8000,	PRIO_HIGHEST

null_sfx:		dcSample	TYPE_NONE,		,			,		FLAGS_SFX	| PRIO_HIGHEST

null_bgm:		dcSample	TYPE_NONE,		,			,		PRIO_HIGHEST

voice:			dcSample	TYPE_PCM_TURBO,	Voice,		32000, 	FLAGS_SFX	| PRIO_NORMAL
				
				dc.w	-1	; end marker

; ------------------------------------------------------------------------------
Demo:
	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.1 Sample Priority Demo%<endl>%<endl>%<pal0>"

	jsr		MegaPCM_LoadDriver
	lea		SampleTable, a0					; load Sonic 1's sample table
	jsr		MegaPCM_LoadSampleTable				; ''

	; FIXME: AS cannot assemble `cmp (an)+,(an)+`
	if __AS__=0
		; Run-time assert for the sample table:
		; Setting priority to `PRIO_NORMAL` should generate
		; the same records as not setting it (because it's the default)
		lea		kick, a0
		lea		kick_normal, a1
		assert.l (a0)+, eq, (a1)+				; table record is 10 bytes
		assert.l (a0)+, eq, (a1)+				; ''
		assert.w (a0)+, eq, (a1)+				; ''
	endif

	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "Non-interrupted playback (kick):%<pal2>"
	.sample_id:	set kick_low.id
	rept 4
		Console.Write "%<.b #.sample_id>... "
		moveq	#$FFFFFF00|.sample_id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #30
		.sample_id: set .sample_id+1
	endr
	Console.BreakLine
	rept 4
		.sample_id: set .sample_id-1
		Console.Write "%<.b #.sample_id>... "
		moveq	#$FFFFFF00|.sample_id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #30
	endr


	Console.WriteLine "%<endl>%<endl>%<pal1>Interrupted playback (kick):%<pal2>"
	.sample_id:	set kick_low.id
	rept 4
		Console.Write "%<.b #.sample_id>... "
		moveq	#$FFFFFF00|.sample_id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #8
		.sample_id: set .sample_id+1
	endr
	Console.BreakLine
	rept 4
		.sample_id: set .sample_id-1
		if .sample_id&1
			Console.Write "%<pal2>%<.b #.sample_id>... "
		else
			Console.Write "%<pal3>%<.b #.sample_id>... "
		endif
		moveq	#$FFFFFF00|.sample_id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #8
	endr

	Console.WriteLine "%<endl>%<endl>%<pal1>SFX can interupt same SFX:%<pal2>"
	rept 4
		Console.Write "%<.b #voice.id>... "
		moveq	#$FFFFFF00|voice.id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #30
	endr
	Console.Sleep #60

	Console.WriteLine "%<endl>%<endl>%<pal1>SFX shouldn't be interrupted:%<pal2>"
	moveq	#$FFFFFF00|voice.id, d0
	jsr		MegaPCM_PlaySample
	Console.WriteLine "%<.b #voice.id>...%<pal3>"
	Console.Sleep #1
	.sample_id:	set kick_low.id
	rept 4
		Console.Write "%<.b #.sample_id>... "
		moveq	#$FFFFFF00|.sample_id, d0
		jsr		MegaPCM_PlaySample
		Console.Sleep #12
		.sample_id: set .sample_id+1
	endr

	Console.Sleep #30

	Console.WriteLine "%<endl>%<endl>%<pal1>SFX interrupted by null SFX:%<pal2>"
	moveq	#$FFFFFF00|voice.id, d0
	jsr		MegaPCM_PlaySample
	Console.Write "%<.b #voice.id>... "
	Console.Sleep #30
	moveq	#$FFFFFF00|null_sfx.id, d0
	jsr		MegaPCM_PlaySample
	Console.Write "%<.b #null_sfx.id>... "
	Console.Sleep #30

	Console.WriteLine "%<endl>%<endl>%<pal1>SFX not interrupted by null non-SFX:%<pal2>"
	moveq	#$FFFFFF00|voice.id, d0
	jsr		MegaPCM_PlaySample
	Console.Write "%<.b #voice.id>... "
	Console.Sleep #30
	moveq	#$FFFFFF00|null_bgm.id, d0
	jsr		MegaPCM_PlaySample
	Console.WriteLine "%<pal3>%<.b #null_bgm.id>... "
	Console.Sleep #60

	rts

; ------------------------------------------------------------------------------

	incdac	Kick, "s1-smps-integration/dac/kick.dpcm"
	incdac	Voice, "common/voice.wav"
