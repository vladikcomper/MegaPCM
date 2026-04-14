DPCM-HQ Encoder and Decoder v.1.0
(c) 2026, Vladikcomper

USAGE:
	dpcm-hq-conv [OPTIONS]... INPUT_FILE [OUTPUT_FILE]

EXAMPLES:

	Encode mysample.wav to mysample.dpcmq (if input is .wav, output is .dpcmq by default):
		dpcm-hq-conv mysample.wav

	Same command, but displays most of default encode options (optional):
		dpcm-hq-conv --mode auto --table best --log info mysample.wav mysample.dpcmq

	Decode mysample.dpcmq to mysample.wav (if input is .dpcmq, output is .wav by default):
		dpcm-hq-conv mysample.dpcmq

	Decode mysample.dpcm (classic DPCM) to mysample-decoded.wav:
		dpcm-hq-conv mysample.dpcm mysample-decoded.wav

	Encode rawsample.pcm (headless) to sample.dpcmq with 16 kHz rate:
		dpcm-hq-conv --rate 16000 rawsample.pcm sample.dpcmq

OPTIONS:
	-m|--mode [MODE]
		Sets operation MODE. Possible values:
			a|auto (default) - auto-detect based on input file extension (.dpcmq or .dpcmq implies decode, evrything else implies encode)
			e|encode - encode WAV or raw PCM file to DPCM-HQ file
			d|decode - decode DPCM or DPCM-HQ file to WAV file

	-t|--table [DELTA_INDEX_TABLE]
		When in 'encode' MODE, selects the preferred delta table for the encoder. Possible values:
			b|best (default) - try all tables, try to pick the best one based on certain stats
			0, 1, 2 - specify table number manually (higher numbers results in more muffled sounds, but less noise)

	-r|--rate [FORCED_RATE_HZ]
		Forces the given sample rate on the output file (WAV or DPMC-HQ). This DOES NOT re-sample audio, just overwrites the original rate.

	-l|--log [LOG_LEVEL]
		Sets the logging level, useful for debugging or silencing the output.
		Possible values: d|debug, i|info, w|warn, e|error. Default is i|info.

