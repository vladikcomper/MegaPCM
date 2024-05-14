
# Mega PCM 2 Sample table format

Mega PCM 2's sample table consists of sample record definitions (`dcSample`) and must be terminated by _the end marker_ (`dc.w -1`). Actual samples are usually included after the table in the same file (via `incdac`), though they can be located anywhere in the ROM.

> [!NOTE]
>
> If you wish to convert your old Mega PCM 1.x sample tables to the new format, check out [Migrating from MegaPCM 1.x](docs/Migration_from_MegaPCM_1.x.md) guide.

Table is loaded by calling `MegaPCM_LoadSampleTable`. With Mega PCM 2, you can use more than one sample table and swap them on the fly.

**Example:**

```m68k
SampleTable:
    ;           type            pointer     Hz      flags?      ; sample id
    dcSample    TYPE_DPCM,      Kick,       8000                ; $81
    dcSample    TYPE_PCM,       Snare,      0                   ; $82
    dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
    dcSample    TYPE_PCM_TURBO, MySFX,      0,      FLAGS_SFX   ; $84
    dc.w    -1  ; end marker

; ---------------------------------------------------------------
    incdac  Kick, "dac/kick.dpcm"
    incdac  Snare, "dac/snare.wav"
    incdac  Timpani, "dac/timpani.dpcm"
    incdac  MySFX, "dac/sfx/mysfx.wav"
    even
```

## `dcSample` format

`dcSample` is a macro to represent a sample record in the table (think of it as a header describing sample's type, location, flags etc).

**Usage:**

```m68k
    dcSample TYPE_PCM, MySampleName, 22050, FLAGS_LOOP+FLAGS_SFX
```

**Syntax:**

```m68k
    dcSample <Type>, <Name>[, <SampleRateHz>, <Flags>]
```

**Arguments:**

- `<Type>` - sample type:
    - `PCM_PCM` (for raw PCM and WAV files);
    - `PCM_DPCM` (for raw DPCM files);
    - `PCM_PCM_TURBO` (for raw PCM and WAV files at 32000 Hz);
- `<Name>` - sample pointer/name, the one you specify for the `indac` macro, so sample table can reference it;
- `<SampleRateHz>` (optional) - sample rate in Hz, supported rates are:
    - For `TYPE_PCM_TURBO`: Only 32000 Hz;
    - For `TYPE_PCM`: Anything between 0 and 25100 Hz;
    - For `TYPE_DPCM`: Anything between 0 and 20500 Hz;
    - If set to `0` or not specified, Mega PCM will try to detect sample rate automatically (**WARNING!** This only works for .WAV files);
- `<Flags>` (optional) - special playback flags or combination thereof:
    - `FLAGS_LOOP` - loops sample indefinitely;
    - `FLAGS_SFX` - sample is considered an SFX sample and has priority over "normal" samples (without this flag). No other samples can interrupt its playback (even other SFX). It also uses separate volume and pan settings (see `MegaPCM_SetSFXVolume` and `MegaPCM_SetSFXPan` in [API docs](API.md))

## `incdac` format

`incdac` is a convenience macro to include sample itself.

**Usage:**

```m68k
    incdac  MySampleName, "path/to/sample/mycoolsample.wav"
```

**Syntax:**

```m68k
    incdac  <Name>, <Path>
```

**Arguments:**

- `<Name>` - sample pointer name, so it can be referenced in `dcSample`;
- `<Path>` - string representing path to the sample.
