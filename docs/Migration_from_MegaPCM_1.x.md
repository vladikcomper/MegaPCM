
# Migration from Mega PCM 1.x

If you are using Mega PCM 1.x, you still can easily replace it with Mega PCM 2 and enjoy higher sample rates, volume control, ultra-clean playback on real hardware and other neat features!

## Table of Contents

- [Migration overview](#migration-overview)
- [Step 1. Following the installation guide](#step-1-following-the-installation-guide)
- [Step 2. Converting the sample table](#step-2-converting-the-sample-table)
  - [Step 2.1. Convert `IncludeDAC` -> `incdac`](#step-21-convert-includedac---incdac)
  - [Step 2.2. Convert `DAC_Entry` -> `dcSample`](#step-22-convert-dac_entry---dcsample)
- [Step 3. Converting sample rates and samples](#step-3-converting-sample-rates-and-samples)
  - [Supported sample rates](#supported-sample-rates)
  - [Converting 1.x pitches to sample rates](#converting-1x-pitches-to-sample-rates)
    - [Pitches to sample rate for PCM (`TYPE_PCM`)](#pitches-to-sample-rate-for-pcm-type_pcm)
    - [Pitches to sample rate for DPCM (`TYPE_DPCM`)](#pitches-to-sample-rate-for-dpcm-type_dpcm)
  - [Converting samples (if needed)](#converting-samples-if-needed)
    - [Converting DPCM to PCM](#converting-dpcm-to-pcm)
    - [Upsampling or donwsampling PCM](#upsampling-or-donwsampling-pcm)

## Migration overview

Mega PCM 2.x was designed with backwards compatibility in mind and supports the same sample formats and flags as Mega PCM 1.x. But since 2.x is a complete rewrite, there are notable changes in how certain features are implemented.

However, if you have a stock installation of Mega PCM 1.x (not something heavily-modified like Mega PCM 1.x on Sonic 2 Clone Driver), the migration should be pretty straight-forward and you only need to worry about 3 things:

1. Following Mega PCM 2 installation guide and making sure your final code changes match what the guide expects after a clean installation.

2. Converting your sample table to Mega PCM 2 format.

3. If you're unlucky to have DPCM and PCM samples with a very specific pitches in 1.x, you need to convert them to PCM/WAV and/or upsample/downsample to the nearest supported sample rate. _But 95% of samples should work without conversion._

Now let's go over those 3 migration steps one-by-one!

## Step 1. Following the installation guide

> [!NOTE]
>
> If you want to just port your sample table from Mega PCM 1.x to a clean Mega PCM 2 source, skip this step and go right to the next one.

Follow the right installation guide for your disassembly, but bear in mind _important notes_ below:

- [Sonic 1 Github Disassembly (AS version)](docs/1-installation/Sonic-1-Github-AS.md)
- [Sonic 1 Hivebrain 2005 Disassembly](docs/1-installation/Sonic-1-Hivebrain-2005.md)

**Important notes:**

- Since you installed Mega PCM 1.x before, you may find out that some of the steps are already complete or done in a different way. ___On each step make sure that your code matches what the guide expects after a clean installation.___

- If you previously followed "HQ playback guide" for 1.x, "Step 2. Remove Z80 stops globally" should already be completed. _But double-check everything, because failing this step will result in broken Mega PCM 2 installation!_

- When it's time to insert a sample table you may realize you're not ready to convert your old one yet. _Don't worry, just go with the one guide provides you with._ Nothing will break, Mega PCM just won't play non-existing samples.


## Step 2. Converting the sample table

Converting sample table format from version 1.x to 2.x should be pretty straight-forward if you precisely follow the instructions below. Mega PCM 2 implements error handling in many places, making it hard to break.

First let's compare and break down a simple sample table:

**Mega PCM 1.x format:**

```m68k
    ;           pitch, pointer, type+flags
    DAC_Entry   $08,   Kick,    dpcm        ; $81
    DAC_Entry   $08,   Snare,   dpcm        ; $82
    DAC_Entry   $1B,   Timpani, dpcm        ; $83
    DAC_Entry   $02,   MySFX,   pcm+pri     ; $84

MegaPCM_End:

; ---------------------------------------------------------------
    IncludeDAC  Kick, dpcm
    IncludeDAC  Snare, dpcm
    IncludeDAC  Timpani, dpcm
    IncludeDAC  MySFX, wav
```

**Mega PCM 2.x format:**

```m68k
SampleTable:
    ;           type            pointer     Hz (0 = auto-detect)
    dcSample    TYPE_DPCM,      Kick,       8000                ; $81
    dcSample    TYPE_PCM,       Snare,      24000               ; $82
    dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
    dcSample    TYPE_PCM,       MySFX,      0,     FLAGS_SFX    ; $84
    dc.w    -1  ; end marker

; ---------------------------------------------------------------
    incdac  Kick, "sound/dac/Kick.dpcm"
    incdac  Snare, "sound/dac/Snare.pcm"
    incdac  Timpani, "sound/dac/Timpani.dpcm"
    incdac  MySFX, "sound/dac/MySFX.wav"
```

Version 2.x uses a different set of macros (`DAC_Entry` -> `dcSample`, `IncludeDAC` -> `incdac`), so let's go over converting their invocations in detail.

### Step 2.1. Convert `IncludeDAC` -> `incdac`

General formula is the following:
```m68k
   IncludeDAC <Name>, <ext> 
```

To:
```m68k
   incdac <Name>, "sound/dac/<Name>.<ext>"
```

Mega PCM 1.x auto-generated `sound/dac/<Name>.<ext>` path under the hood, while Mega PCM 2 is being more explicit and flexible: you're no longer locked to `sound/dac` directory and your sample's filename and its label/pointer can differ!

Given the example above, here's what you should get *before* and *after* conversion:

**Before the conversion (Mega PCM 1.x format):**

```m68k
    IncludeDAC  Kick, dpcm
    IncludeDAC  Snare, dpcm
    IncludeDAC  Timpani, dpcm
    IncludeDAC  MySFX, wav
```

**After the conversion (Mega PCM 2.x format):**

```m68k
    incdac  Kick, "sound/dac/Kick.dpcm"
    incdac  Snare, "sound/dac/Snare.dpcm"
    incdac  Timpani, "sound/dac/Timpani.dpcm"
    incdac  MySFX, "sound/dac/MySFX.wav"
```

> [!NOTE]
>
> Some heavily modified projects may customize paths, so it can differ from the default `sound/dac/<Name>.<ext>`. Just in case, you may find the definition of `IncludeDAC` macro to verify it, or just see where DAC samples are stored in your disassembly.

### Step 2.2. Convert `DAC_Entry` -> `dcSample`

This conversion is a bit more involved as this is where the formats differ the most.

General formula is the following:
```m68k
    DAC_Entry <1.x_Pitch>, <Name>, <1.x_Type_and_Flags>
```
To:
```m68k
    dcSample <2.x_Type>, <Name>[, <2.x_SampleRate>, <2.x_Flags>]
```

Instead of going into the detail of converting every field of every line, we can easily automate it using your editor's search&replace and copy&paste capabilities! Here's a step by step conversion routine:

1. We start with the stock 1.x format, where only the `<Name>` column accidentally matches Mega PCM 2's format (✅), everything else is incompatible (❌):

    ```m68k
    ;   ❌           ❌      ✅       ❌
        DAC_Entry   $08,   Kick,    dpcm        ; $81
        DAC_Entry   $08,   Snare,   dpcm        ; $82
        DAC_Entry   $1B,   Timpani, dpcm        ; $83
        DAC_Entry   $02,   MySFX,   pcm+pri     ; $84
    ```

2. Now, let's replace `DAC_Entry` with `dcSample`, swap **the first** and **the third** columns and add `dc.w -1` (end marker) after the last sample as shown below:

    ```m68k
    ;   ✅          ❌        ✅          ❌   
        dcSample   dpcm,    Kick,       $08    ; $81
        dcSample   dpcm,    Snare,      $08    ; $82
        dcSample   dpcm,    Timpani,    $1B    ; $83
        dcSample   pcm+pri, MySFX,      $02    ; $84
        dc.w    -1  ; ++ end marker
    ```

    Macro name is now compatible (✅), other columns are taking their correct places, but still use wrong formats (❌).

> [!WARNING]
>
> Always remember to add end marker (`dc.w -1`) to your sample table. Otherwise, you may see failures upon boot!

3. Do the following replacements *inside the table only* (not globally!):

    - `pcm` => `TYPE_PCM`
    - `dpcm` => `TYPE_DPCM`
    - `pri` => `FLAGS_SFX` (if exists)
    - `loop` => `FLAGS_LOOP` (if exists)
    - `panLR`, `panL` and `panR` => nothing (remove them, Mega PCM 2 handles panning differently);

   You should get the following:

    ```m68k
    ;   ✅          ⚠️                  ✅           ❌   
        dcSample   TYPE_DPCM,          Kick,       $08    ; $81
        dcSample   TYPE_DPCM,          Snare,      $08    ; $82
        dcSample   TYPE_DPCM,          Timpani,    $1B    ; $83
        dcSample   TYPE_PCM+FLAGS_SFX, MySFX,      $02    ; $84
        dc.w    -1
    ```

    The first column (`<2.x_Type>`) is now almost compatible, but some instances with flags need correction (⚠️), see below.

4. If some records in the first column (`<2.x_Type>`) has leftover flags after previous manipulations (e.g. `TYPE_PCM+FLAGS_SFX`), you need to move everything after the first `+` character to a new dedicated column (`<2.x_Flags>`):

    ```m68k
    ;   ✅          ✅          ✅           ❌      ✅
        dcSample   TYPE_DPCM,  Kick,       $08                 ; $81
        dcSample   TYPE_DPCM,  Snare,      $08                 ; $82
        dcSample   TYPE_DPCM,  Timpani,    $1B                 ; $83
        dcSample   TYPE_PCM,   MySFX,      $02,   FLAGS_SFX    ; $84
        dc.w    -1
    ```

    Now, almost everything is properly converted, except for the `<2.x_SampleRate>` column (❌), which still uses values of `<1.x_Pitch>`. This final conversion is the most nuanced one, hence deserves its own topic, so let's go right into **the next chapter** below.

> [!NOTE]
>
> If you have hard times following column/field names (e.g. `<2.x_Flags>`) and why everything was being swapped and replaced in the steps above, revisit the general conversion formula above and compare 1.x and 2.x syntax.

## Step 3. Converting sample rates and samples

In the previous step, we almost fully converted the sample table from 1.x to 2.x format, except for one part: **pitches**.

With Mega PCM 2 you can specify proper **sample rates** in Hz, while 1.x used an arbitrary **pitch** bytes specific to driver's internal timing which you had to fine-tune manually. Each "pitch" value from 1.x has a corresponding _effective sample rate_, except it's not explicitly specified like with 2.x and it differs between PCM and DPCM playback code.

For example, the pitch value of `$08` for DPCM sample will maintain playback at ~17478 Hz. For your convenience, there are tables for converting "pitches" to actual sample rates below, but first let's discuss supported sample rate differences between Mega PCM 1.x and 2.0.

### Supported sample rates

Unfortunately, some pitches from 1.x are incompatible, especially for DPCM. This means that a few DPCM samples have to be converted to PCM format (most notably, S1/S2/S3K Snare) and, in rare cases, some PCM samples need to be upsampled or downsampled to the nearest supported rate.

**Summary of supported rates:**

|                | **Mega PCM 1.x**      | **Mega PCM 2.0**                                            |
|----------------|:---------------------:|:-----------------------------------------------------------:|
| PCM/WAV        | 1050 .. 28500 Hz      | 0 .. 25100 Hz (normal mode)<br/>32000 Hz fixed (turbo mode) |
| DPCM           | 1050 .. 31450 Hz      | 0 .. 20500 Hz                                               |

As you can see, Mega PCM 2 has a higher maximum playback rate in turbo mode. However, due to addition of volume and pitch control in normal modes, max PCM rate is slightly lower and max DPCM rate is noticeably lower because Mega PCM 2's streaming system wasn't designed for DPCM (it was mostly added for feature-parity).

General takeaways from the above table:

- If your DPCM sample's rate is higher than 20500 Hz, you need to convert it to PCM;
- If your PCM sample's rate is between 25100 and 28500 Hz, you need to either downsample it to 25100 Hz (recommended) or upsample to 32000 Hz.
- In every other case, you can set the correct sample rate without sample data conversion.

Most of the times, you won't need any conversion at all. If you do, it's quite simple using proper tools, which we'll discuss soon. But first, let's finally convert pitches to sample rates!

### Converting 1.x pitches to sample rates

Let's take another look at our "mostly converted" sample table from the previous step:

```m68k
;   ✅          ✅          ✅           ❌      ✅
    dcSample   TYPE_DPCM,  Kick,       $08                 ; $81
    dcSample   TYPE_DPCM,  Snare,      $08                 ; $82
    dcSample   TYPE_DPCM,  Timpani,    $1B                 ; $83
    dcSample   TYPE_PCM,   MySFX,      $02,   FLAGS_SFX    ; $84
    dc.w    -1
```

We need to go over raw values in the third column (marked with ❌, because it requires conversion).

Just take raw "pitch" value from this table (e.g. `$08`, `$1B`, `$02` etc) and replace it with "sample rate" value using the tables below.

Pay attention to sample type! Use different tables for `TYPE_PCM` and `TYPE_DPCM`. Table may instruct to to convert sample due to limitations listed in the previous subsection. Converting samples themselves (only if you need this) will be covered in the next section.

If you complete follow next sections carefully, you should get the following result (use it as a reference to check yourself later if needed):

```m68k
;   ✅          ✅          ✅           ✅      ✅
    dcSample   TYPE_DPCM,  Kick,       17478               ; $81
    dcSample   TYPE_DPCM,  Snare,      17478               ; $82
    dcSample   TYPE_DPCM,  Timpani,    8000                ; $83 (rounded)
    dcSample   TYPE_PCM,   MySFX,      25100,   FLAGS_SFX  ; $84 (rounded)
    dc.w    -1
```

> [!NOTE]
>
> For more information on Mega PCM 2's sample table format, see [Mega PCM 2 Sample table format](Sample_table_format.md).

#### Pitches to sample rate for PCM (`TYPE_PCM`)

Use this table if your target sample's type is `TYPE_PCM`. Note that allowed pitches in 1.x are $01..$FF, but only $01..$3F are covered here, because anything above is so low, it's not practically usable.

| **Mega PCM 1.x Pitch** | **Converted Mega PCM 2.x Sample rate, Hz**                       |
|------------------------|------------------------------------------------------------------|
| $01 (1)                | 28568                                                            |
| $02 (2)                | 25882 (UNSUPPORTED, round to 25100 Hz)                           |
| $03 (3)                | 23659                                                            |
| $04 (4)                | 21787 (can be rounded to 22050 Hz if that was the original rate) |
| $05 (5)                | 20189                                                            |
| $06 (6)                | 18810                                                            |
| $07 (7)                | 17607                                                            |
| $08 (8)                | 16549 (can be rounded to 16000 Hz if that was the original rate) |
| $09 (9)                | 15611 (can be rounded to 16000 Hz if that was the original rate) |
| $0A (10)               | 14773                                                            |
| $0B (11)               | 14021                                                            |
| $0C (12)               | 13342                                                            |
| $0D (13)               | 12725                                                            |
| $0E (14)               | 12163                                                            |
| $0F (15)               | 11648                                                            |
| $10 (16)               | 11176 (can be rounded to 11000 Hz if that was the original rate) |
| $11 (17)               | 10740 (can be rounded to 11000 Hz if that was the original rate) |
| $12 (18)               | 10337                                                            |
| $13 (19)               | 9963                                                             |
| $14 (20)               | 9615                                                             |
| $15 (21)               | 9290                                                             |
| $16 (22)               | 8987                                                             |
| $17 (23)               | 8703                                                             |
| $18 (24)               | 8436                                                             |
| $19 (25)               | 8186 (can be rounded to 8000 Hz if that was the original rate)   |
| $1A (26)               | 7949 (can be rounded to 8000 Hz if that was the original rate)   |
| $1B (27)               | 7726                                                             |
| $1C (28)               | 7515                                                             |
| $1D (29)               | 7316                                                             |
| $1E (30)               | 7126                                                             |
| $1F (31)               | 6947                                                             |
| $20 (32)               | 6776                                                             |
| $21 (33)               | 6613                                                             |
| $22 (34)               | 6458                                                             |
| $23 (35)               | 6310                                                             |
| $24 (36)               | 6168                                                             |
| $25 (37)               | 6033                                                             |
| $26 (38)               | 5904                                                             |
| $27 (39)               | 5780                                                             |
| $28 (40)               | 5661                                                             |
| $29 (41)               | 5547                                                             |
| $2A (42)               | 5438                                                             |
| $2B (43)               | 5332                                                             |
| $2C (44)               | 5231                                                             |
| $2D (45)               | 5133                                                             |
| $2E (46)               | 5039                                                             |
| $2F (47)               | 4949                                                             |
| $30 (48)               | 4862                                                             |
| $31 (49)               | 4777                                                             |
| $32 (50)               | 4696                                                             |
| $33 (51)               | 4617                                                             |
| $34 (52)               | 4541                                                             |
| $35 (53)               | 4467                                                             |
| $36 (54)               | 4396                                                             |
| $37 (55)               | 4327                                                             |
| $38 (56)               | 4260                                                             |
| $39 (57)               | 4195                                                             |
| $3A (58)               | 4132                                                             |
| $3B (59)               | 4071                                                             |
| $3C (60)               | 4012 (can be rounded to 4000 Hz if that was the original rate)   |
| $3D (61)               | 3954 (can be rounded to 4000 Hz if that was the original rate)   |
| $3E (62)               | 3898                                                             |
| $3F (63)               | 3844                                                             |


#### Pitches to sample rate for DPCM (`TYPE_DPCM`)

Use this table if your target sample's type is `TYPE_DPCM`. Note that allowed pitches in 1.x are $01..$FF, but only $01..$3F are covered here, because anything above is so low, it's not practically usable.

| **Mega PCM 1.x Pitch** | **Converted Mega PCM 2.x Sample rate, Hz**                                    |
|------------------------|-------------------------------------------------------------------------------|
| $01 (1)                | 31455 (UNSUPPORTED! Convert to `TYPE_PCM_TURBO` at ~32000 Hz)                 |
| $02 (2)                | 28230 (UNSUPPORTED! Convert to `TYPE_PCM_TURBO` at ~32000 Hz)                 |
| $03 (3)                | 25605 (UNSUPPORTED! Convert to `TYPE_PCM` at ~25100 Hz)                       |
| $04 (4)                | 23426 (UNSUPPORTED! Convert to `TYPE_PCM` at 23426 Hz)                        |
| $05 (5)                | 21590 (UNSUPPORTED! Convert to `TYPE_PCM` at 21590 Hz or 22050 Hz if rounded) |
| $06 (6)                | 20020                                                                         |
| $07 (7)                | 18663                                                                         |
| $08 (8)                | 17478                                                                         |
| $09 (9)                | 16435 (can be rounded to 16000 Hz if that was the original rate)              |
| $0A (10)               | 15509 (can be rounded to 16000 Hz if that was the original rate)              |
| $0B (11)               | 14682                                                                         |
| $0C (12)               | 13939                                                                         |
| $0D (13)               | 13267                                                                         |
| $0E (14)               | 12658                                                                         |
| $0F (15)               | 12101                                                                         |
| $10 (16)               | 11592                                                                         |
| $11 (17)               | 11124 (can be rounded to 11025 Hz if that was the original rate)              |
| $12 (18)               | 10692 (can be rounded to 11025 Hz if that was the original rate)              |
| $13 (19)               | 10292                                                                         |
| $14 (20)               | 9921                                                                          |
| $15 (21)               | 9576                                                                          |
| $16 (22)               | 9254                                                                          |
| $17 (23)               | 8953                                                                          |
| $18 (24)               | 8671                                                                          |
| $19 (25)               | 8407                                                                          |
| $1A (26)               | 8158 (can be rounded to 8000 Hz if that was the original rate)                |
| $1B (27)               | 7923 (can be rounded to 8000 Hz if that was the original rate)                |
| $1C (28)               | 7701                                                                          |
| $1D (29)               | 7492                                                                          |
| $1E (30)               | 7293                                                                          |
| $1F (31)               | 7105                                                                          |
| $20 (32)               | 6926                                                                          |
| $21 (33)               | 6756                                                                          |
| $22 (34)               | 6595                                                                          |
| $23 (35)               | 6440                                                                          |
| $24 (36)               | 6293                                                                          |
| $25 (37)               | 6153                                                                          |
| $26 (38)               | 6018                                                                          |
| $27 (39)               | 5889                                                                          |
| $28 (40)               | 5766                                                                          |
| $29 (41)               | 5648                                                                          |
| $2A (42)               | 5534                                                                          |
| $2B (43)               | 5425                                                                          |
| $2C (44)               | 5320                                                                          |
| $2D (45)               | 5220                                                                          |
| $2E (46)               | 5122                                                                          |
| $2F (47)               | 5029                                                                          |
| $30 (48)               | 4939                                                                          |
| $31 (49)               | 4852                                                                          |
| $32 (50)               | 4768                                                                          |
| $33 (51)               | 4686                                                                          |
| $34 (52)               | 4608                                                                          |
| $35 (53)               | 4532                                                                          |
| $36 (54)               | 4459                                                                          |
| $37 (55)               | 4388                                                                          |
| $38 (56)               | 4319                                                                          |
| $39 (57)               | 4252                                                                          |
| $3A (58)               | 4188                                                                          |
| $3B (59)               | 4125                                                                          |
| $3C (60)               | 4064 (can be rounded to 4000 Hz if that was the original rate)                |
| $3D (61)               | 4005 (can be rounded to 4000 Hz if that was the original rate)                |
| $3E (62)               | 3947 (can be rounded to 4000 Hz if that was the original rate)                |
| $3F (63)               | 3892                                                                          |

### Converting samples (if needed)

Only follow these steps if tables above instruct you to convert samples themselves. *You won't need this for 95% of samples.*

#### Converting DPCM to PCM

If you have DPCM samples and the table above instructed you to convert some of them to PCM, just follow the instructions below:

1. You need to get `dpcm2pcm.exe` utility, which you can download here: https://vladikcomper.scanf.su/public/dpcm2pcm.7z (it's also available in [SMPS Research Pack](https://forums.sonicretro.org/index.php?threads/valley-bells-smps-research.32473/page-5#post-929100), Linux/MacOS may build it from the source code)
2. Extract `dpcm2pcm.exe` to your `sound/dac` directory for convenience.
3. Drag and drop a DPCM sample (e.g. `snare.dpcm`) to convert onto the `dpcm2pcm.exe`, you should see a new file with `.snd` extension next to it (e.g. `snare.dpcm.snd`)
4. Use that new sample instead of an old one. Don't forget to change `TYPE_DPCM` to `TYPE_PCM` in the table!

#### Upsampling or donwsampling PCM

As mentioned before, if your PCM sample's rate was between 25100 and 28500 Hz, you need to either downsample it to 25100 Hz (recommended) or upsample to 32000 Hz, because any rate in-between isn't supported by Mega PCM 2.

If your old rate was close enough to the supported boundary (e.g. 25800 instead of 25100 Hz), you can just "round" it and call it a day; a difference won't be audible anyways.

In other cases, you need to decide between downsampling to 25100 Hz or upsampling to 32000 Hz (or if you still have a higher quality source, converting it again targeting the supported rate). Downsampling is preferred in most of the cases, because 32000 Hz playback mode doesn't support volume control and sample size will be larger.

The following instruction uses [Audacity](https://www.audacityteam.org/) to perform conversion:

1. Open your sample in Audacity:
   - If it's a WAV file, it will be opened automatically;
   - If it's a RAW PCM data, you need to import it via _File > Import > Raw data_ (set type to 8-bit unsigned PCM, Mono, set the original Sample rate you need to convert from)
2. In the bottom section of the screen, find "Project rate (Hz)" field and set it:
   - To 25100 Hz to downsample (recommended);
   - To 32000 Hz to upsample;
3. Export sample as WAV file via _File > Export > Export as WAV_. Make sure to select "WAV (Microsoft)" type and "Unsigned 8-bit PCM" encoding.
4. Use your newly saved .WAV file in Mega PCM 2 with the following settings:
   - Set type to `TYPE_PCM` if it was downsampled;
   - Set type to `TYPE_PCM_TURBO` it was upsampled to 32000 Hz;
   - In both cases, you can set Sample rate in the table to 0, so Mega PCM 2 will detect it automatically.
