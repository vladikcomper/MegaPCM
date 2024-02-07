
; ---------------------------------------------------------------
SampleTable:
	;			type			pointer		Hz
	dcSample	TYPE_DPCM, 		Kick, 		8000				; $81
	dcSample	TYPE_PCM,		Snare,		24000				; $82
	dcSample	TYPE_DPCM, 		Timpani, 	7250				; $83
	dcSample	TYPE_NONE										; $84
	dcSample	TYPE_NONE										; $85
	dcSample	TYPE_NONE										; $86
	dcSample	TYPE_NONE										; $87
	dcSample	TYPE_DPCM, 		Timpani, 	9750				; $88
	dcSample	TYPE_DPCM, 		Timpani, 	8750				; $89
	dcSample	TYPE_DPCM, 		Timpani, 	7150				; $8A
	dcSample	TYPE_DPCM, 		Timpani, 	7000				; $8B
	dcSample	TYPE_PCM_TURBO,	Voice,		32000, FLAGS_SFX	; $8C
	dc.w	-1	; end marker

; ---------------------------------------------------------------
	incdac	Kick, "s1-smps-integration/dac/kick.dpcm"
	incdac	Snare, "s1-smps-integration/dac/snare.pcm"
	incdac	Timpani, "s1-smps-integration/dac/timpani.dpcm"
	incdac	Voice, "s1-smps-integration/dac/voice.wav"
	even
