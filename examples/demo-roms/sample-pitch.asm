
	include	"common/demo-bootloader.asm"

; ------------------------------------------------------------------------------
Demo:
	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0					; load Sonic 1's sample table
	jsr		MegaPCM_LoadSampleTable				; ''

	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.1 Sample Pitch Demo%<endl>%<endl>%<pal0>"
	Console.Sleep #30

	MPCM_play #bgm.id

	Console.Sleep #60
	Console.WriteLine "Lowering the pitch..."

	move.b	#bgm.pitch, d0
	move.w	#2*60, d1
	.lower_pitch:
		MPCM_setPitch d0
		subq.b	#1, d0
		Console.Sleep #2
		dbf		d1,	.lower_pitch

	Console.Sleep #60

	Console.WriteLine "Restoring the pitch..."
	move.w	#2*60, d1
	.restore_pitch:
		MPCM_setPitch d0
		addq.b	#1, d0
		Console.Sleep #2
		dbf		d1,	.restore_pitch

	Console.Sleep #60
	rts

; ------------------------------------------------------------------------------

SampleTable:
		;			type			pointer		Hz		flags
voice:	dcSample	TYPE_PCM_TURBO,	Voice,		32000, 	FLAGS_SFX
bgm:	dcSample	TYPE_DPCM,		TestBGM,	20600,	FLAGS_LOOP
		dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	Voice, "common/voice.wav"
	incdac	TestBGM, "common/bgm3.dpcmq"
