
	include	"common/demo-bootloader.asm"

; ------------------------------------------------------------------------------
Demo:
	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable

	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.1 Sample Panning Demo%<endl>%<endl>%<pal0>"
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "Normal: Snare (RIGHT)"
	MPCM_setPan #$40
	MPCM_play #snare.id
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "Normal: Snare (LEFT)"
	MPCM_setPan #$80
	MPCM_play #snare.id
	Console.Sleep #60							; sleep 1 second

	Console.WriteLine "SFX: Voice (default=CENTER)"
	MPCM_play #sfx_voice.id
	Console.Sleep #120							; sleep 2 seconds

	Console.WriteLine "SFX: Voice (RIGHT)"
	MPCM_setSfxPan #$40
	MPCM_play #sfx_voice.id
	Console.Sleep #120							; sleep 2 seconds

	Console.WriteLine "Normal: Timpani (previous=LEFT)"
	MPCM_play #timpani.id
	Console.Sleep #60							; sleep 1 second
	rts

; ------------------------------------------------------------------------------
SampleTable:
			;			type			pointer		Hz
snare:		dcSample	TYPE_PCM,		Snare,		24000				; $82
timpani:	dcSample	TYPE_DPCM, 		Timpani, 	7250				; $83
sfx_voice:	dcSample	TYPE_PCM_TURBO,	Voice,		32000, FLAGS_SFX	; $84
			dc.w	-1	; end marker

; ------------------------------------------------------------------------------
	incdac	Snare, "s1-smps-integration/dac/snare.pcm"
	incdac	Timpani, "s1-smps-integration/dac/timpani.dpcm"
	incdac	Voice, "common/voice.wav"
