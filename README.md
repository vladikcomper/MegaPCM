
# Mega PCM 2

**Mega PCM 2** is a DAC sound driver for Sega Mega-Drive / Genesis. It offers the highest quality playback possible on the hardware, high sample rate (up to 32 kHz), pitch/volume effects and supports several sample formats (WAVE, raw PCM, compressed DPCM).

Unlike the majority of DAC drivers on the Mega-Drive with the infamous "scratchy" playback many games are known for, Mega PCM 2 outputs cleanest sounding samples on the hardware thanks to its buffering / DMA protection system.

Mega PCM runs primarily on the Z80 CPU and is DAC only. To take full advantage of Sega's sound chip and also use FM and PSG channels, you need to run it alongside the "main" M68K sound driver. Generally, Mega PCM can be integrated with any M68K sound driver. Currently, only SMPS integration is officially provided.

## Features

- High quality crystal-clear PCM playback with DMA protection;
- Volume control and smooth pitch control;
	- 16 volume levels;
	- 256 pitch levels;
- Complex inside, user-friendly outside:
	- Zero-config DMA protection (no extra flags to set and unset, simply don't stop Z80 on DMA's);
	- Native WAVE file support, native PCM format (no custom converters required!);
	- Auto-detects issues with WAVE formats or sample configuration upon startup;
- Several supported sample formats:
	- WAVE file with 8-bit unsigned PCM (playback rate can be detected from header);
	- Raw 8-bit unsigned PCM (headless);
	- Raw 4-bit DPCM (headless);
- Playback control, priority settings and SFX support:
	- Pause, Stop and Loop supported for all sample types;
	- Differentiates between "normal" samples (usually BGM drums) and SFX samples;
	- SFX samples aren't interrupted by BGM drums, they have separate volume and pan settings;
- Tested to the extreme:
	- Z80 portion of Mega PCM is unique in that it's extensively auto-tested in a virtual machine;
	- A special Z80 emulator was created to emulate Mega PCM and carefully test its core and various function;
	- Tests also verify that all Mega PCM playback loops and branches are cycle-accurate;
- High playback rate:
	- 8-bit PCM playback up to 25.1 kHz with pitch and volume effects;
	- 4-bit DPCM playback up to 20.5 kHz with pitch and volume effects;
	- **Turbo mode!** 8-bit PCM playback at 32 kHz (without pitch and volume effects);
