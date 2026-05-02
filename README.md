
# Mega PCM 2

**Mega PCM 2** is a DAC sound driver for Sega Mega-Drive / Genesis. It offers the highest quality playback possible on the hardware, high sample rate (up to 32 kHz), pitch/volume effects and supports several sample formats (WAVE, raw PCM, DPCM-HQ and DPCM).

Unlike the majority of DAC drivers on the Mega-Drive with the infamous "scratchy" playback many games are known for, Mega PCM 2 outputs cleanest sounding samples on the hardware thanks to its buffering / DMA protection system.

_You may also see this demo of [crystal-clear PCM playback @ 32 kHz](https://www.youtube.com/watch?v=4RZbvuL2m1c) recorded on real hardware._

## Features

- **High quality crystal-clear playback:**
    - Battle-tested on real hardware and emulators alike;
    - DMA protection / buffering system allows for ideal non-interrupted playback;
    - Games usually DMA 6-8 Kb of data at most; Mega PCM 2 can survive up to 24 Kb (!) of DMA transfers;

- **Supports several compressed and uncompressed formats:**
    - **.WAV files** in 8-bit unsigned PCM format;
    - **Raw PCM** - 8-bit unsigned PCM format (headless);
    - **DPCM-HQ (compressed)** - new Mega PCM exclusive format, higher quality version of DPCM;
    - **DPCM (compressed)** - classic 4-bit DPCM format (headless) found in some Sega titles.

- **High playback rates:**
    - **WAVE/PCM:** up to **25.1 kHz** (supporting effects) or **32 kHz** (turbo mode);
    - **DPCM-HQ/DPCM:** up to **20.5 kHz** (supporting effects) or **25.8 kHz** (turbo mode);

- **Support for volume and pitch effects:**
    - 16 volume levels;
    - 256 pitch levels;

- **Playback control, priority levels and SFX support:**
    - Pause, Stop and Loop supported for all sample types;
    - Differentiates between "normal" (usually BGM drums) and SFX samples;
    - 8 total priority levels: 4 for "normal" and 4 for SFX samples (latter always have higher priority);
    - Separate volume and panning settings for "normal" and SFX samples;

- **Complex inside, user-friendly outside:**
    - Zero-config DMA protection (no extra flags to set and unset, simply don't stop Z80 on DMA's);
    - Native .WAV file support, native PCM format (no custom converters required!);
    - Auto-detects issues with sample formats or configuration on startup;

- **Battle-tested to the extremes:**
    - Z80 portion of Mega PCM is unique in that it's extensively auto-tested in a virtual machine;
    - A special Z80 emulator was created to emulate Mega PCM and carefully test its core and various functions;
    - Tests also verify that all Mega PCM playback loops and branches are cycle-accurate;

## Getting Started

> [!NOTE]
>
> Mega PCM is a DAC-only sound driver! It runs primarily on Z80 CPU and was designed to work alongside the "main" M68K sound driver to drive the remaining FM and PSG channels.
> 
> Generally speaking, Mega PCM can be integrated with any M68K sound driver. Currently, only SMPS 68K integration is officially provided.


### Installation guides

- [Sonic 1 Github Disassembly (AS version)](docs/1-installation/Sonic-1-Github-AS.md)
- [Sonic 1 Hivebrain 2005 Disassembly](docs/1-installation/Sonic-1-Hivebrain-2005.md)

### Documentation

- [API Documentation](docs/API.md)
- [Sample table format](docs/Sample_table_format.md)
- [Migrating from MegaPCM 1.x](docs/Migration_from_MegaPCM_1.x.md)
- [Troubleshooting](docs/Troubleshooting.md)

### How-to guides

- [How to play SFX samples](docs/3-how-tos/Playing_DAC_SFX.md)
- [How to play DAC BGM](docs/3-how-tos/Playing_DAC_BGM_with_SMPS.md)

## Examples

- [Small Demo ROMs](examples/demo-roms)
- [DMA Protection testing ROM](examples/dma-survival-test)
- [Sonic 1 SMPS integration as a standalone player](examples/s1-smps-integration)

## Existing implementations

- Sonic 1 Github AS disassembly with Mega PCM 2 pre-installed: https://github.com/vladikcomper/s1disasm-megapcm2
- Unofficial Sonic 2 Clone Driver v2 with Mega PCM 2 integration in Sonic Clean Engine (S.C.E.) by TheBlad768: https://github.com/TheBlad768/Sonic-Clean-Engine-S.C.E.-


## Building from source code

### Linux

You need to have Wine, Python 3, GCC/Clang installed on your system.

The following commands build the bare minimum toolset:

```
make                # builds Mega PCM bundles
make dpcm-hq-conv   # builds `dpcm-hq-conv` tool
make examples       # builds demo ROMs using all Mega PCM bundles (AS, ASM68K, ASM68K-linkable)
```

Or run `make all` to build everything, including development artifacts (e.g. Mega PCM Viz tool, which requires SDL3).

### Windows

Just use WLS2 with Ubuntu, then follow Linux instructions.

### FreeBSD

Almost the same as Linux, however you need to make sure to use GNU version of Make. Install GNU Make and always use `gmake` command instead of `make`.

## Licensing

**Mega PCM 2's main source code and its dependencies (`src/` and `lib-68k/` directories) are fully free and open source and are provided under MIT license. See `LICENSE` file.**

DPCM HQ Converter for Mega PCM 2 (`tools/dpcm-hq-conv`) is provided under MIT license.

Source code for Mega PCM 2 implementation examples (`examples/` directory) is also MIT-licensed, however, some included assets and disassembled "SMPS" sound driver may be proprietary and provided for educational purposes only.

Also included in this repo, but not distributed with Mega PCM 2 releases:

- Mega PCM 2 Vizualizer tool (`tools/megapacm-viz` directory) - MIT-licensed;

- Mega PCM 2's testing suite (`test/` directory) - MIT-licensed;

- Mega PCM Emu Library (`lib/megapcm-emu`) - MIT-licensed;

- Z80VM Library (`lib/z80vm`) - based on extended and modified z80emu v.1.3.0 (c) by Lin Ke-Fong; comes with permissive free license.

- For developer's convenience this repo also includes a few binary tools (see `toolchain/` directory):

   - `asm68k` and `psylink` are (c) by S.N. Systems Software Limited and come with propriatary license, but are considered [abandonware](https://en.wikipedia.org/wiki/Abandonware);

   - `sjasmplus` is a free and open source Z80 assembler available under BSD-3-Clause license;

   - `convsym`, `cbundle` and others are written by me and are availabe under permissive MIT License.
