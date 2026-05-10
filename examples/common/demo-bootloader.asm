
	include	"common/demo-bootstrap.asm"

; ------------------------------------------------------------------------------
Main:
	jsr		Demo

	Console.WriteLine "%<endl>%<pal1>END OF DEMO%<endl>PRESS START TO RESTART..."
	Console.Pause
	MPCM_stopZ80
	Console.Clear
	MPCM_startZ80
	bra		Main
