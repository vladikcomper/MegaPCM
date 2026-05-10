
	include	"common/demo-bootloader.asm"

; ------------------------------------------------------------------------------
Demo:
	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.1 Sample Volume Demo%<endl>%<endl>%<pal0>"

	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable

	Console.WriteLine "Snare intro demo...%<endl>"
	moveq	#$F, d6
	.snare_seq:
		Console.Sleep #10
		MPCM_setVol d6
		MPCM_play #snare.id
		subq.b	#1, d6
		bpl.s	.snare_seq

	Console.WriteLine "BGM Fade In/Out Demo...%<endl>"
	MPCM_setSfxVol #$F
	MPCM_play #sfx_bgm.id

	moveq	#3-1, d7
	.fade_in_out_sequence:
		moveq	#$F, d6						; volume = min
		.fade_in_loop:
			Console.Sleep #8						; sleep 8 frames
			MPCM_setSfxVol d6
			subq.w	#1, d6
			bpl.s	.fade_in_loop

		moveq	#0, d6						; volume = max
		Console.Sleep #120
		.fade_out_loop:
			Console.Sleep #8						; sleep 8 frames
			MPCM_setSfxVol d6
			addq.w	#1, d6
			cmp.w	#$F, d6
			bls.s	.fade_out_loop

		Console.Sleep #120
		dbf		d7, .fade_in_out_sequence

	rts

; ------------------------------------------------------------------------------
SampleTable:
			;			type			pointer			Hz
snare:		dcSample	TYPE_PCM,		Snare,			24000							; $81
sfx_bgm:	dcSample	TYPE_DPCM,		TestBGM,		0,	 FLAGS_LOOP|FLAGS_SFX		; $82
			dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	Snare, "s1-smps-integration/dac/snare.pcm"
	incdac	TestBGM, "common/bgm3.dpcmq"
