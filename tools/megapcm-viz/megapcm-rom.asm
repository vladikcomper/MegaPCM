
	include	'../../src/68k/macros.asm'
	include	'../../src/68k/sample-table.defs.asm'

SampleTable:
	dcSample 	TYPE_PCM_TURBO, 	BGM2, 		0,	FLAGS_LOOP
	dcSample 	TYPE_DPCM,		 	BGM3, 		0,	FLAGS_LOOP
	dcSample 	TYPE_PCM_TURBO, 	Voice, 		0,	FLAGS_SFX
	dcSample 	TYPE_DPCM, 			Kick,		8000
	dcSample 	TYPE_PCM, 			Snare,		24000
	dcSample 	TYPE_DPCM, 			Timpani,	7250
	dc.w	-1

	incdac	BGM2, "../../examples/common/bgm2.wav"
	incdac	BGM3, "../../examples/common/bgm3.dpcmq"
	incdac	Voice, "../../examples/common/voice.wav"
	incdac	Kick, "../../examples/s1-smps-integration/dac/kick.dpcm"
	incdac	Snare, "../../examples/s1-smps-integration/dac/snare.pcm"
	incdac	Timpani, "../../examples/s1-smps-integration/dac/timpani.dpcm"
