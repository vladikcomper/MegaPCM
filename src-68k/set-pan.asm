
MegaPCM_SetPan:
	stopZ80
	move.b	d0, Z80_RAM+Z_MPCM_PanInput
	startZ80
	rts

MegaPCM_SetSFXPan:
	stopZ80
	move.b	d0, Z80_RAM+Z_MPCM_SFXPanInput
	startZ80
	rts
