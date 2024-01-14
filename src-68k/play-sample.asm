
; ==============================================================================
; ------------------------------------------------------------------------------
; Plays a given sample
; ------------------------------------------------------------------------------

MegaPCM_PlaySample:
	stopZ80
	move.b	d0, Z80_RAM+Z_MPCM_CommandInput
	startZ80
	rts

; ------------------------------------------------------------------------------
MegaPCM_PausePlayback:
	stopZ80
	move.b	#Z_MPCM_COMMAND_PAUSE, Z80_RAM+Z_MPCM_CommandInput
	startZ80
	rts

; ------------------------------------------------------------------------------
MegaPCM_UnpausePlayback:
	stopZ80
	move.b	#0, Z80_RAM+Z_MPCM_CommandInput
	startZ80
	rts

; ------------------------------------------------------------------------------
MegaPCM_StopPlayback:
	stopZ80
	move.b	#Z_MPCM_COMMAND_STOP, Z80_RAM+Z_MPCM_CommandInput
	startZ80
	rts
