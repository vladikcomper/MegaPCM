
# Mega PCM 2 Changelog

## Version 2.1 (2026-05-10)

- New DPCM-HQ format is now supported, a higher quality version of DPCM retaining the same size.
- New [DPCM-HQ Converter](tools/dpcm-hq-conv/README.md) tool is included in releases to convert samples to DPCM-HQ.
- Turbo playback is now supported for DPCM and DPCM-HQ samples.
    - Maximum DPCM rate is now 25800 Hz instead of 20600 Hz in version 2.0.
- New [Sample Priority](docs/Sample_priorities.md) system with 8 priority levels.
    - A welcome **breaking change:** Since version 2.1 SFX samples can interrupt other SFX or themselves when played repeatedly. Set different priority levels if you want legacy behavior.
- New & fast [convenience macros](docs/API.md#macros-reference) added as alternatives to routines found in version 2.0:
    - `MPCM_play` - alternative to `jsr MegaPCM_PlaySample`
    - `MPCM_pause` - alternative to `jsr MegaPCM_PausePlayback`
    - `MPCM_unpause` - alternative to `jsr MegaPCM_UnpausePlayback`
    - `MPCM_stop` - alternative to `jsr MegaPCM_StopPlayback`
    - `MPCM_setPan` - alternative to `jsr MegaPCM_SetPan`
    - `MPCM_setSfxPan` - alternative to `jsr MegaPCM_SetSFXPan`
    - `MPCM_setVol` - alternative to `jsr MegaPCM_SetVolume`
    - `MPCM_setSfxVol` - alternative to `jsr MegaPCM_SetSFXVolume`
- New API method added to support pitch effects at runtime:
    - [`MPCM_setPitch`](docs/API.md#mpcm_setpitch) (macro form) or `jsr MegaPCM_SetActiveSamplePitch` (routine form)
- Sample tables now support [Named samples](docs/Sample_table_format.md#named-samples). Add a label before the sample (e.g. `mySample:`) to access its properties anywhere in the code:
    - `mySample.id` - ID of the sample (can be used with `MPCM_play`);
    - `mySample.desc` - description field;
    - `mySample.pitch` - sample's pitch value (can be used with `MPCM_setPitch`).
- **AS and ASM68K bundles:** All command routines (e.g. `MegaPCM_PlaySample` etc) are now included as editable source code in `MegaPCM.asm` instead of baked into a blob;
- **AS and ASM68K bundles:** Various macros now generate user-friendly error messages when invoked incorrectly.
- **AS and ASM68K bundles:** Macro and constant definitions are now split into a separate `MegaPCM.Macros.asm`; this allows to use macros anywhere and reduces number of passes on AS.
- **AS bundle:** Fixed an oversight in `MPCM_stop` macro, which used `bset` instead of `btst` in Z80 wait loop, which made it slightly slower than ASM68K version.
- **AS bundle:** Explicitly specify `(xxx).l` addressing modes in macros and routines to avoid weird assembly bugs where incorrect addressing mode is used.
- **Bugfix:** Fixed a rare bug, where samples with extremely low rates (e.g. 4000 Hz) may occasionally skip samples when crossing M68K bank boundary.
- Major documentation improvements: Updated installation guides for upstream Sonic 1 Github disassembly, added [Converting samples](docs/3-how-tos/Converting_samples.md) tutorial and more.
- Added more Mega PCM 2 [Demo ROMs](examples/demo-roms) to quickly showcase usage of its API;
- [Mega PCM 2 Vizualizer](tools/megapcm-viz/README.md) program was made, which is a custom-made Z80 and YM DAC emulator to test driver even more thoroughly and vizualize its internal state;
- More improvements to test suites, demo ROMs are now compiled for all target assembler bundles (AS, ASM68K, ASM68-Linkable), making Mega PCM 2 probably the most over-tested DAC driver on the planet;
- Major code restructuring and optimization of internal records. M68K-side sample record is reduced from 12 to 10 bytes; Z80-side sample record is reduced from 9 to 8 bytes, a lot of Z80 code restructuring for space and performance.
- Other changes and improvements.


## Version 2.0 (2024-05-31)

Initial 2.x release.
