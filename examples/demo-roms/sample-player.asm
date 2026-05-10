
	include	"common/demo-bootstrap.asm"

; ------------------------------------------------------------------------------
SampleTable:
	;			type			pointer		 Hz	(0=detect)	flags		   id
	dcSample	TYPE_DPCM,		BGM3,		 0,				FLAGS_LOOP	; $81
	dcSample	TYPE_PCM_TURBO, BGM2,		 0,				FLAGS_LOOP	; $82
	dcSample	TYPE_PCM_TURBO, BGM1,		 0,				FLAGS_LOOP	; $83
	dcSample	TYPE_PCM_TURBO, Voice,		 0							; $84
SampleTable_End:	; this label exists solely to track number of samples
	dc.w	-1	; end marker

Num_Samples:	equ	(SampleTable_End-SampleTable)/10

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.1 Sample player"
	Console.WriteLine "(c) 2024-2026, Vladikcomper%<endl>%<pal0>"

	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable	; returns d0 = 0 on success
	assert.w d0, eq, , MPCM_Debugger_LoadSampleTableException

	Console.WriteLine "Press START to cycle through samples:"
	.MainLoop:
		.sample_id:	set $81

		rept Num_Samples
			MPCM_play #.sample_id
			Console.Write "%<setx>%<1>Now playing: %<.b #.sample_id>..."
			Console.Pause

			.sample_id: set .sample_id+1
		endr
		bra		.MainLoop

; ------------------------------------------------------------------------------
	incdac	BGM1, "common/bgm1.wav"
	incdac	BGM2, "common/bgm2.wav"
	incdac	BGM3, "common/bgm3.dpcmq"
	incdac	Voice, "common/voice.wav"
