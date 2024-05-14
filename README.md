
# Mega PCM 2

> [!WARNING]
>
> The development of Mega PCM 2 is 99.999999% complete, but some integrations and cross-platform build system are still pending. For proper support, **please wait until documentation is finalized and release is officially announced.**

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
- [Sonic 1 Hivebrain 2005 Disassembly](docs/1-installation/Sonic-1-Hivebrain-2005.md)


### Documentation

- [API Documentation](docs/API.md)
- [Migrating from MegaPCM 1.x](docs/Migration_from_MegaPCM_1.x.md)

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

You need to have GCC, Make and Python3 installed and availabe via PATH. The easiest way to get everything with one command is to use Chocolatey, but you may choose any other option that works for you:

```
choco install mingw python3 make
```

Once dependencies are installed, build process is the same as on Unix-like systems:

```
make
make examples
```

If you need to invoke `make` from individual directories however (not root), be sure to use `make -f Makefile.win` instead (the root Makefile does it automatically).

### FreeBSD

Almost the same as Linux, however you need to make sure to use GNU version of Make.

- Install GNU Make; use `gmake` command instead of `make`;

## Licensing

**Mega PCM 2's main source code and its dependencies (`src/`, `lib-68k/`, `examples/` directories) are fully free and open source and are provided under MIT license. See `LICENSE` file.**

Also included in this repo, but not distributed with Mega PCM 2 releases:

- Mega PCM 2's testing suite (see `test/` directory):

    - All tests source code and "MegaPCM-Emu" library retain the same MIT license;

    - "Z80VM" library (`tests/z80vm`) is a custom solution based on a modified z80emu v.1.3.0 (c) by Lin Ke-Fong; the original software comes without a set license.

- For developer's convenience this repo also includes a few binary tools (see `toolchain/` directory):

   - `asm68k` and `psylink` are (c) by S.N. Systems Software Limited and come with propriatary license, but are considered [abandonware](https://en.wikipedia.org/wiki/Abandonware);

   - `sjasmplus` is a free and open source Z80 assembler available under BSD-3-Clause license;

   - `convsym`, `cbundle` and others are written by me and are availabe under permissive MIT License.
