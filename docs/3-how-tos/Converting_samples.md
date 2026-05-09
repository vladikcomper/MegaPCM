
# Converting Samples for Mega PCM 2

This quick tutorial explains how to get the most of sample quality and/or size when adding samples to your ROM.

## The Basics

When converting samples for Mega PCM 2, you should pay attention to 3 factors:

- **Sound format**
    - PCM (uncompressed .WAV) or DPCM-HQ (compressed);
    - Uncompressed means better quality, but *double* the file size;

- **Sample rate**
    - Lower sample rates limit the dynamic range (cut high frequencies), but save a lot of space;
    - Higher sample rates better preserve dynamic range at the cost of space;
    - 16 kHz is half the size of 32 kHz. 20-22 kHz is usually the "sweet spot" for most of the sounds, 16 kHz and is acceptable for voices and basses.

- **File size**
    - Sega Mega-Drive ROMs usually can't go beyond 4 MB, so you should be careful with total length of your samples (in seconds), here's how much you can fit in 4 MB depending on the format:
        - **32 kHz PCM** = 130 seconds;
        - **22.05 kHz PCM** = 190 seconds;
        - **16 kHz PCM** = 262 seconds;
        - **16 kHz DPCM-HQ** = 524 seconds.

## The Formats & Nuances

To better understand technical nuances and hardware limitations, let's go over some fundamentals in detail. If you want to become better at dealing with sample formats and conversion, I highly recommend you read this.

Mega PCM 2 supports 3 major sound formats:

- **8-bit mono unsigned PCM**
    - .WAV files (with header) or raw .PCM/.RAW/.BIN files (headless, bytes only);
    - Uncompressed native format Sega Mega-Drive's DAC can output directly;
- **4-bit mono DPCM (compressed)**
    - Raw .DPCM/.BIN files (headless);
    - Simple classic compression used by various Mega-Drive games; slightly worse quality than PCM, but half the size;
- **4-bit mono DPCM-HQ (compressed)**
    - .DPCMQ files (with header);
    - New Mega PCM-exclusive format; higher quality version of DPCM, same low file size;

Regardless of source sound format, Mega PCM outputs **8-bit mono unsigned PCM**, because that's the only hardware's native format. "8-bit mono" means samples only have 1 channel and reduced 8-bit *bit depth*. Since most of sounds files nowadays are provided as "16-bit stereo" at least (2 channels, larger bit depth), conversion is required to play them on the console.

The perceived "sound quality" usually depends on several factors:

- **Bit depth**
    - As described above, hardware only supports 8-bit PCM, while modern standards start at 16 bit.
    - Reduced bit depth requires quantization and introduces small quantization errors. This somewhat reduces dynamic range, but modern conversion tools combat this by dithering - usually by adding white noise. That's why you may hear a bit of "hissing" in converted samples, but it helps to mask quantization errors!

- **Sample rate**
    - Basically number of samples per second. Our hearing range is typically 20 Hz .. 20 kHz. That's why modern sampling rate is 44.1 kHz or 48 kHz (roughly double of that to fit into 20 kHz dynamic range).
    - Unfortunately, just like with *bit depth*, older hardware puts a toll on sample rate as well. Older games typically sampled at 8 kHz .. 16 kHz, but Mega PCM 2 supports up to 32 kHz in turbo mode.
    - However, high sample rates result in large files, and you may run out of ROM space quickly. To combat this, lower the sample rate and use compressed formats like DPCM. 22.05 kHz is optimal in many situations as it has good dynamic range and moderate size.

- **Conversion tools & settings**
    - Surprisingly, that's often overlooked but insanely important. Conversion tools matter, especially with hardware limitations, where mistakes become audible!
    - Modern tools like Audacity and FFMpeg come with good defaults and should do good out of the box. Some older/outdated tools, like Sox, may give inferior results, especially for 8-bit quantization on lower sample rates, because they use aggressive dithering, which becomes audible below 32 kHz;
    - If you want absolute control and perfection, you need to play with different sample rates, dithering and downsampling options for best results.

## Conversion Best Practices

Here's some tips and rules of thumb for converting samples for old hardware in general. Most of it summarizes what's been discussed above.

- **Sample Size: Consider compression**
    - Don't hesitate to try compressed DPCM-HQ format, which cuts sample size in half at cost of quality reduction.
    - ROM space is limited, if you want to store more, think in alternatives: 20 kHz DPCM-HQ will be the same size as 10 kHz PCM of the same length! That's a definite win, as despite any compression, sound will definitely be richer at 20 kHz.

- **Sample Rate: Do you really need high rates?**
    - Remember that sample rate isn't a direct "quality" measure, it merely limits frequency range. Our hearing range goes up to 20-22 kHz, which fits into 44.1 kHz sampling rate. But a lot of sounds have lower frequencies!
    - Human speech, for instance, fits nicely into 2 .. 4 kHz range, which is why older phone lines had sampling rate of mere 8 kHz.
    - When dealing with voices, basses and other low-frequency sounds, high sample rates stop adding gains at some point. 8 .. 16 kHz sample rate is acceptable for these use cases.

- **Sample Rate: Some rates are a bit better than others**
    - This is specific to Mega PCM 2. Playback loops always output at a certain base sampling rate and discrete pitching algorithm is used to downsample to the desired sample rate (this affects all other DAC drivers that use similar approach);
    - Mega PCM 2 cannot perform smooth downsampling, it's too computationally complex. So discrete downsampling results in slight sampling distortions at certain rates (generally speaking, rates not multiple of `base rate / 2^N`);
    - This means that certain sample rates result in pitch-perfect playback, while other may have small downsampling errors.
    - "Pitch perfect" rates are (first is "turbo mode" rate, others are "normal mode" rates):
        - **WAV/PCM**: 32000 Hz, 25100 Hz, 12550 Hz, 6275 Hz
        - **DPCM/DPCM-HQ**: 25800 Hz, 20600 Hz, 10300 Hz, 5150 Hz

- **Sample Conversion: There will be dithering**
    - All sound converters utilize dithering by default when converting to 8-bit PCM.
    - Think of it like image dithering: have you seen old GIFs with checkerboard pixels? Just like images may emulate more colors with dithering, sounds may emulate higher dynamic range.
    - However, dithering may introduce a noticable noise ("hissing"), especially at lower sample rates.
    - Some tools like Audacity and SOX allow you to disable dithering. It's generally discouraged, **do it at your own risk!** Samples without dither will sound "clear" (without hissing), but there may be really noticable distortions. Only robotic and chip-tune samples may sound good with this.

## Converting to 8-bit PCM

The following instruction uses [Audacity](https://www.audacityteam.org/) to perform conversion:

1. Open your sound in Audacity (you can simply drag & drop it into the main area);
2. In the bottom section of the screen, find "Project rate (Hz)" field and set it to the desired sample rate;
3. Export sample as WAV file via _File > Export > Export as WAV_. Make sure to select "WAV (Microsoft)" type and "Unsigned 8-bit PCM" encoding.
4. Use your newly saved .WAV file in Mega PCM 2 with the following settings:
   - Set type to `TYPE_PCM` if sample rate is below 25100 Hz;
   - Set type to `TYPE_PCM_TURBO` it sample rate is 32000 Hz;
   - In both cases, you can set Sample rate in the table to 0 (or not specify it), so Mega PCM 2 will detect it automatically.

## Converting to DPCM-HQ

You can further compress your 8-bit PCM samples (.WAV or raw) to DPCM-HQ format using `dpcm-hq-conv` tool. Download the tool from [Mega PCM Releases](https://github.com/vladikcomper/MegaPCM/releases) page.

Basic usage looks as follows:

**On Windows:**

- Just drag & drop your file (e.g. `my-sample.wav`) onto `dpcm-hq-conv.exe` to convert it.
- .WAV files are converted to .DPCMQ files (e.g. `my-sample.wav` -> `my-sample.dpcmq`);
- If you want to listen to compressed sample, you can decode it back to .WAV: drag & drop your .DPCMQ file to get .DPCMQ.WAV for preview (e.g. `my-sample.dpcmq` -> `my-sample.dpcmq.wav`);

> [!NOTE]
>
> If conversion didn't happen, your .WAV file is likely in the wrong format (e.g. stereo instead of mono or 16-bit PCM instead of 8-bit). The tool will display an error in command prompt, but it may be too quick to see. You'd need to run `dpcm-hq-conv` through inside `CMD.EXE` to see its output.

**On Linux/Mac:**

Unpack `dpcm-hq-conv` executable in the same directory as samples you convert, ensure it has `+x` (executable) flag and invoke it from the command line.

To convert .WAV file to .DPCMQ:

```sh
# This will produce `my-sample.wav` -> `my-sample.dpcmq`
./dpcm-hq-conv my-sample.wav
```

If you want to listen to compressed sample, you can decode it back to .WAV:
```sh
# This will produce `my-sample.dpcmq` -> `my-sample.dpcmq.wav`
./dpcm-hq-conv my-sample.dpcmq
```

> [!NOTE]
>
> `dpcm-hq-conv` tools comes with a lot of command-line options, some of which influence conversion quality. These are not covered here. To get the best out of conversion, check tool's [documentation](../../tools/dpcm-hq-conv/README.md).
