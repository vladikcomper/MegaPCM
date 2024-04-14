
# Mega PCM 2

> [!WARNING]
>
> The development of Mega PCM 2 is 99.9999% complete, but some integrations and cross-platform build system are still pending. For proper support, **please wait until documentation is finalized and release is officially announced.**

**Mega PCM 2** is a DAC sound driver for Sega Mega-Drive / Genesis. It offers the highest quality playback possible on the hardware, high sample rate (up to 32 kHz), pitch/volume effects and supports several sample formats (WAVE, raw PCM, compressed DPCM).

Unlike the majority of DAC drivers on the Mega-Drive with the infamous "scratchy" playback many games are known for, Mega PCM 2 outputs cleanest sounding samples on the hardware thanks to its buffering / DMA protection system.

Mega PCM runs primarily on the Z80 CPU and is DAC only. To take full advantage of Sega's sound chip and also use FM and PSG channels, you need to run it alongside the "main" M68K sound driver. Generally, Mega PCM can be integrated with any M68K sound driver. Currently, only SMPS integration is officially provided.

## Features

- High quality crystal-clear PCM playback with DMA protection;
    - Games usually DMA 6-8 Kb of data at most; Mega PCM 2 can survive up to 24 Kb (!) of DMA transfers;
- Volume control and smooth pitch control;
	- 16 volume levels;
	- 256 pitch levels;
- Complex inside, user-friendly outside:
	- Zero-config DMA protection (no extra flags to set and unset, simply don't stop Z80 on DMA's);
	- Native WAVE file support, native PCM format (no custom converters required!);
	- Auto-detects issues with WAVE formats or sample configuration on startup;
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
	- A special Z80 emulator was created to emulate Mega PCM and carefully test its core and various functions;
	- Tests also verify that all Mega PCM playback loops and branches are cycle-accurate;
- High playback rates:
	- 8-bit PCM playback up to 25.1 kHz with pitch and volume effects;
	- 4-bit DPCM playback up to 20.5 kHz with pitch and volume effects;
	- **Turbo mode!** 8-bit PCM playback at 32 kHz (without pitch and volume effects);

## Installation and Documentation

### Installation guides

- [Sonic 1 Github Disassembly (AS version)](docs/1-installation/Sonic-1-Github-AS.md)


### Documentation

- [API Documentation](docs/API.md)

- For Sonic 1 SMPS integration, see `examples/s1-smps-integration`

## Examples

- [Basic 32 kHz WAVE playback with looping](examples/sample-tester)
- [DMA Protection testing ROM](examples/dma-survival-test)
- [Complete Sonic 1 SMPS integration as a standalone player](examples/s1-smps-integration)

## Building from source code

### Linux

Make sure Wine is installed. Use the following commands to build:

```
make
make examples
```

### Windows

Windows is semi-supported. If you have GNU Make and GCC installed, you should be able to run the same commands as on Linux.

### FreeBSD

Almost the same as Linux, with a few extra steps:

- Install GNU Make; use `gmake` command instead of `make`;
- Make sure `python` is symlinked to `python3`
