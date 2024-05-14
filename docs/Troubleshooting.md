
# Mega PCM 2 Troubleshooting guide

## Problem: I get black screen on boot

Possible reasons:

1. `MegaPCM_LoadSampleTable` returns an error, but Sonic 1's stock error handler fails to render it.

    **How to diagnose:** It's highly recommended to install [MD Debugger and Error handler](https://github.com/vladikcomper/md-modules/releases) for proper error reporting, because Mega PCM 2 integrates natively with it. With MD Debugger you should be able to see detailed error description, if it's `MegaPCM_LoadSampleTable`.

    **How to fix:** Some samples likely have invalid formats. Follow error description provided by the debugger to fix this.

2. `MegaPCM_LoadDriver` or the main sound driver is getting stuck in an inifite loop waiting for Z80 to release bus.

    **How to diagnose:** If you have MD Debugger and there aren't any displayed exceptions, your CPU is most likely stuck in an infinite loop. If your emulator has a built-in M68K debugger, you should be able to verify it.

    **How to fix:** Revisit "Step 2. Remove Z80 stops globally" of the installation guide. Make sure you don't have any orphaned "stopZ80" commands. Make sure you modified the main sound driver properly.

## Problem: I have MD Debugger and get sample table error

Some samples likely have invalid formats. Follow error description provided by the debugger to fix this.

## Problem: Everything seems to work, but sample $XX refuses to play!

Possible reasons:

1. Make sure the expected sample table is loaded (`MegaPCM_LoadSampleTable` is called upon boot);
2. Make sure sample number is correct. It should be $81 or above ($81 = first sample, $82 = second etc);
3. A high priority SFX sample is being played at the same time. As of version 2.0 you cannot play any samples while a sample with `FLAGS_SFX` is being played. The only workaround is to call `MegaPCM_StopPlayback`, wait 1 frame and play the desired sample.
4. Mega PCM 2 doesn't recognize sample type; if sample type isn't `TYPE_PCM`, `TYPE_PCM_TURBO` or `TYPE_DPCM`, Mega PCM 2 will ignore it (make sure it's not `TYPE_NONE`, make sure sample table is loaded correctly);
5. If you modified volume (`MegaPCM_SetVolume`, `MegaPCM_SetSFXVolume`), make sure it's loud enough;
6. Make sure you didn't call `MegaPCM_SetPan` or `MegaPCM_SetSFXPan` with the value of `$00`, this effectively disables playback.
7. Make sure you don't call `MegaPCM_PausePlayback`, `MegaPCM_UnpausePlayback`, `MegaPCM_StopPlayback` in the same frame; these calls override last requested sample ID, which Mega PCM fetches only once per frame.
8. If you handle YM writes manually, make sure to always invoke `MPCM_ensureYMWriteReady` after `MPCM_stopZ80`.

## Problem: FM sounds are completely broken!

Your installation of Mega PCM 2 is likely incorrect. Revisit installation guide and pay attention to all sound driver modifications. You must always restore YM's DAC register (`$2A`) after any write to YM.

## Problem: DAC playback is still scratchy!

Mega PCM 2 guarantees that DAC playback is ultra-clean thanks to its "DMA protection" system, but you should guarantee that you eleminate all Z80 stops on DMA (graphic transfers). See "Step 2. Remove Z80 stops globally" of the installation guide.

Another reason why playback may get slightly worse at times is when the main sound driver writes to YM too frequently (this is the only time where Z80 must be stopped shortly). These shouldn't be too noticeable unless you play a new SFX every frame. Unfortunately, there isn't a proper solution to this, as because there are limits to everything.
