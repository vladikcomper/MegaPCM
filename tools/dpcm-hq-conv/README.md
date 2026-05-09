
# DPCM-HQ-Converter

**DPCM-HQ-Converter** is a small command line tool to convert .WAV or raw PCM to DPCM-HQ format and vice-versa. It also supports decoding of classic DPCM.

.WAV files must be in **8-bit mono unsigned PCM** format. Make sure to convert them ahead of time.

## Usage

```sh
dpcm-hq-conv [OPTIONS]... INPUT_FILE [OUTPUT_FILE]
```

### Options

- `-m|--mode [MODE]`
    - Sets operation MODE. Possible values:
        - `a|auto` (default) - auto-detect based on input file extension (.dpcmq or .dpcmq implies decode, everything else implies encode)
        - `e|encode` - encode WAV or raw PCM file to DPCM-HQ file
        - `d|decode` - decode DPCM or DPCM-HQ file to WAV file

- `-t|--table [DELTA_INDEX_TABLE]`
    - When in 'encode' MODE, selects the preferred delta table for the encoder. Possible values:
        - `b|best` (default) - try all tables, try to pick the best one based on certain heuristics
        - `0`, `1` or `2` - specify table number manually (higher numbers results in more muffled sounds, but less noise)

- `-r|--rate [FORCED_RATE_HZ]`
    - Forces the given sample rate on the output file (WAV or DPCM-HQ). This DOES NOT re-sample audio, just overwrites the original rate.
    - By default, sample rate from input file's header is used. If file is headless, rate defaults to 16000 Hz.

- `-l|--log [LOG_LEVEL]`
    - Sets the logging level, useful for debugging or silencing the output. Possible values:
        - `d|debug`
        - `i|info` (default)
        - `w|warn`
        - `e|error`

### Examples

Encode `mysample.wav` to `mysample.dpcmq` (if input is `.wav`, output is `.dpcmq` by default):

```sh
dpcm-hq-conv mysample.wav
```

Same command, but shows most of default program options (optional):

```sh
dpcm-hq-conv --mode auto --table best --log info mysample.wav mysample.dpcmq
```

Decode `mysample.dpcmq` to `mysample.dpcmq.wav` (if input is `.dpcmq`, output is `dpcmq.wav` by default):

```sh
dpcm-hq-conv mysample.dpcmq
```

Decode `mysample.dpcm` (classic DPCM) to `mysample-decoded.dpcm.wav`:

```sh
dpcm-hq-conv mysample.dpcm mysample-decoded.dpcm.wav
```

Encode `rawsample.pcm` (headless) to `sample.dpcmq` with 16 kHz rate:

```sh
dpcm-hq-conv --rate 16000 rawsample.pcm sample.dpcmq
```

## Manual Encode Options

DPCM-HQ Converter aims to select the best encoding table based on certain heuristics, but the perceived "sound quality" is very subjective. Sometimes you may want to go over each encoding choice manually to see what result you like the most.

DPCM-HQ currently only has 3 delta tables for encoding (indexed `0`, `1` and `2`, see `--table` option). Different tables may produce better results depending on nature of sound and sample rate:

- `--table 0`
    - It's he same delta table as classic DPCM (based on powers of 2)
    - Good for lower-rate and sharp sounds, but introduces more quantization noise;
- `--table 1`
    - Delta table with smaller steps (based on fibonacci numbers);
    - Reduces quantization noise, but may result in a bit "muffled" sections where sounds is loud/sharp;
- `--table 2`
    - Delta table with even smaller steps
    - Better for quiet sounds, absolute minimal quantization noise, but even more "muffled" sounds compared to table `1`.

**Which table does encoder pick by default?**

Encoder tries to pick the best table based on encoding RMSE. However, since lower RMSE doesn't always mean lower quantization noise (unless we get RMSE=0, meaning lossless encoding), a small bias is introduced towards tables `1` and `2`, which reduce quantization noise. The algorithm isn't ideal since it's hard to put human bias ("sound quality" perception) into math, which is why this section exists to explain how to test all tables manually.

Upon doing conversion, you can see encoder's decision-making process if you enable debug-level logs (using `--log debug` or `-l d` for short). You may see something like this:

```sh
$ ./dpcm-hq-conv bgm2.wav --log debug

DPCM-HQ Encoder and Decoder v.1.0
(c) 2026, Vladikcomper

Initiating encoding from WAV/PCM to DPCM-HQ...
Reading input file: bgm2.wav...
Detected WAVE header
[DEBUG] RIFFHeader = { .fileTypeBlockId = 'RIFF', fileSize = 181032, fileFormatId = 'WAVE' }
[DEBUG] RIFFFmtChunk = { .chunkId = 'fmt ', chunkSize = 16, audioFormat = 1, numChannels = 1, sampleRate = 32000, bytesPerSec = 32000, bytesPerBlock = 1, bitsPerSample = 8 }
[DEBUG] RIFFDataChunk = { .chunkId = 'data', chunkSize = 180663 }
[DEBUG] decodedStream = { .sampleRate = 32000, .data.size = 180663 }
Padding decoded stream to even number of samples
Invoking encoder...
[DEBUG] candidateResult[0] = { .deltaTableIndex = 0, .RMSE = 0.5687082979043067, .data.size = 90332 }
[DEBUG] candidateResult[1] = { .deltaTableIndex = 1, .RMSE = 0.3652049593812225, .data.size = 90332 }
[DEBUG] candidateResult[2] = { .deltaTableIndex = 2, .RMSE = 0.3745947935494802, .data.size = 90332 }
[DEBUG] encodingResult = { .deltaTableIndex = 2, .RMSE = 0.3745947935494802, .data.size = 90332 }
[DEBUG] encodedStream = { .sampleRate = 32000, .deltaTableIndex = 2, .data.size = 90332 }
Writing to output file: bgm2.dpcmq...
Operation complete
```

In this example, encoder picked table `2` as seen on this line: `[DEBUG] encodedStream = { ... .deltaTableIndex = 2 , ... }`. Despite it having ever so slightly higher RMSE (0.37 compared to 0.36 for table `1`), it was biased towards this table due to lower quantization noise.


**How to test tables manually?**

The recipe is simple:

1. Invoke `dpcm-hq-conv` 3 times with different options: `--table 0`, `--table 1` and `--table 2` (you can use `-t` instead of `--table`), preferably setting different output file names.
2. Convert each resulting DPCM-HQ file back to .WAV so you can easily play them back.
3. Listen to all 3 files and pick the best one.

Here's an example:

```sh
# Try all 3 tables on `bgm2.wav`:
./dpcm-hq-conv --table 0 bgm2.wav bgm2.table0.dpcmq
./dpcm-hq-conv --table 1 bgm2.wav bgm2.table1.dpcmq
./dpcm-hq-conv --table 2 bgm2.wav bgm2.table1.dpcmq

# Convert each resulting file back to wav and listen:
./dpcm-hq-conv bgm2.table0.dpcmq
./dpcm-hq-conv bgm2.table1.dpcmq
./dpcm-hq-conv bgm2.table1.dpcmq
```

## DPCM-HQ format specification

DPCM-HQ V1 has a 9-byte header, followed by DPCM-HQ stream. All bytes are Big-Endian.

| Offset       | Size      | Description
|--------------|-----------|--------------------------------------------------
| `0x0000`     | 2         | "DQ" magic string
| `0x0002`     | 1         | DPCM-HQ version string (should be "1")
| `0x0003`     | 3         | DPCM-HQ stream size (in bytes)
| `0x0006`     | 2         | Sample rate (in HZ)
| `0x0008`     | 1         | DPCM-HQ table number (`0x00`, `0x10` or `0x20`)
