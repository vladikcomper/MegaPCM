
MegaPCM_SetVolume:
	stopZ80
	move.b	d0, Z80_RAM+Z_MPCM_VolumeInput
	startZ80
	rts

MegaPCM_SetSFXVolume:
	stopZ80
	move.b	d0, Z80_RAM+Z_MPCM_SFXVolumeInput
	startZ80
	rts
