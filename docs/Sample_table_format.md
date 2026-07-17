
# Mega PCM 2 Sample Table Format

Mega PCM 2's sample table consists of sample record definitions (`dcSample`) and **must** be terminated by the ___end marker___ (`dc.w -1`). Actual samples are usually included after the table in the same file (via `incdac`), though they can be located anywhere in the ROM.

## Sample Table Overview

> [!NOTE]
>
> If you wish to convert your old Mega PCM 1.x sample tables to the new format, check out [Migrating from MegaPCM 1.x](./3-how-tos/Migration_from_MegaPCM_1.x.md) guide.

Table is loaded by calling `MegaPCM_LoadSampleTable`. With Mega PCM 2, you can use more than one sample table and swap them on the fly.

You can also _name_ samples in the table by assigning labels to them (see `hikick` label below), which allows you to reference their properties for coding convenience (e.g. `MPCM_play #hikick.id` instead of `MPCM_play #$86`). See [Named samples](#named-samples) section below for more information.

**Example:**

```m68k
SampleTable:
;name?              type            pointer     Hz?     flags?      ; sample id (for reference)
        dcSample    TYPE_DPCM,      Kick,       8000                ; $81
        dcSample    TYPE_PCM,       Snare,      0                   ; $82
        dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
        dcSample    TYPE_NONE                                       ; $84
sfx:    dcSample    TYPE_PCM_TURBO, MySFX,      0,      FLAGS_SFX   ; $85 or `sfx.id` (see Named samples section)
hikick: dcSample    TYPE_DPCM,      Kick,       16000               ; $86 or `hickick.id`
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
            dcSample TYPE_NONE                  ; "null" sample
            dcSample TYPE_PCM, MySampleName     ; .WAV file, sample rate auto-detected
mySample:   dcSample TYPE_PCM, MySampleName, 22050, FLAGS_LOOP|FLAGS_SFX|PRIO_HIGH
```

**Syntax:**

```m68k
[<Label>:]  dcSample <Type>, <Name>[, <SampleRateHz>, <Flags>]
```

**Arguments:**

- `<Label>` (optional) - allows to reference sample record and its properties in the code _(since Mega PCM 2.1)_:
    - `<Label>.id` - returns ID of the sample in the table (e.g. `$85`);
    - `<Label>.desc` - returns sample's description field
    - `<Label>.pitch` - returns sample's internal pitch values (converted from Sample Rate to 0..$FF scale);
    - See [Named Samples](#named-samples) section below for more information.
- `<Type>` - sample type:
    - `TYPE_NONE` - marks empty/null slot (can still be "played" to interrupt other samples, depending on priority);
    - `TYPE_PCM` - .WAV/.RAW files;
    - `TYPE_PCM_TURBO` - .WAV/.RAW files at 32000 Hz;
    - `TYPE_DPCM` - DPCM-HQ or raw DPCM files;
    - `TYPE_DPCM_TURBO` - DPCM-HQ or raw DPCM files at 25800 Hz _(since Mega PCM 2.1)_;
- `<Name>` - sample pointer/name, the one you specify for the `indac` macro, so sample table can reference it;
- `<SampleRateHz>` (optional for .WAV and .DPCMQ files) - sample rate in Hz, supported rates are:
    - For `TYPE_PCM`: 100 .. 25100 Hz;
    - For `TYPE_PCM_TURBO`: 32000 Hz fixed;
    - For `TYPE_DPCM`: 100 ... 20500 Hz;
    - For `TYPE_DPCM_TURBO`: 25800 Hz fixed _(since Mega PCM 2.1)_;
    - If set to `0` or not specified, Mega PCM attempts to auto-detect sample rate from file header (**WARNING!** This only works for .WAV and .DPCMQ files);
- `<Flags>` (optional) - can specify playback/priority flags or their combinations:
    - Playback flags:
        - `FLAGS_LOOP` - loops sample indefinitely;
        - `FLAGS_SFX` - sample is considered an SFX sample and has priority over "normal" samples (without this flag). Normal samples cannot interrupt it. It also uses separate volume and pan settings (see `MegaPCM_SetSFXVolume` and `MegaPCM_SetSFXPan` in [API docs](API.md))
    - Priority flag can be one of _(since Mega PCM 2.1)_:
        - `PRIO_LOW` - sets sample priority to *Low*;
        - `PRIO_NORMAL` - sets sample priority to *Normal* (that's the default);
        - `PRIO_HIGH` - sets sample priority to *High*;
        - `PRIO_HIGHEST` - sets sample priority to *Highest*;
        - Please see [Sample Priority System](./Sample_priorities.md) document for more information.
    - To combine flags, use `|` or `+` operator, e.g.: `FLAGS_SFX|FLAGS_LOOP|PRIO_HIGHEST`

## `incdac` format

`incdac` is a convenience macro to include sample itself. Under the hood, it aligns included data on even address and generates start and end labels, which `dcSample` can reference internally.

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

## Named samples

***Since Mega PCM 2.1***

You optionally can add labels to any records in the sample table, which allows you to reference some of their properties, for example:

```m68k
SampleTable:
;name?              type            pointer     Hz?     flags?         ; sample id (for reference)
kick:   dcSample    TYPE_DPCM,      Kick,       8000                   ; $81 or kick.id
voice:  dcSample    TYPE_PCM_TURBO, VoiceSFX,   0,      FLAGS_SFX      ; $81 or voice.id
        dc.w    -1  ; end marker
```

> [!WARNING]
>
> Label **must** appear on the same line as `dcSample`! Otherwise it won't be captured and properties won't be generated.

On top of sample's label (e.g. `mysample`), Mega PCM also generates the following properties for the sample (all are byte-sized):

- `mysample.id` - returns ID of the sample in the table (e.g. `$85`)
- `mysample.desc` - returns sample's description field, which has the following format:
    - `%0PppTTTL` bits, where:
        - `P` - high bit of priority, also SFX flag (`FLAGS_SFX`);
        - `pp` - lower bits of priority (set by `PRIO_LOW`, `PRIO_NORMAL`, `PRIO_HIGH` or `PRIO_HIGHEST`);
        - `TTT` - sample type (set by `TYPE_NONE`, `TYPE_PCM`, `TYPE_PCM_TURBO`, `TYPE_DPCM` or `TYPE_DPCM_TURBO`);
        - `L` - loop sample flag (`FLAGS_LOOP`).
- `mysample.pitch` - returns sample's internal pitch values (converted from Sample Rate to 0..$FF scale);
    - **NOTE:** Due to technical limitations this setting only works if Sample Rate was specified in the sample table. When you ask Mega PCM to auto-detect rate for you, `.pitch` property isn't available.

These properties can be used to conveniently replace manually-tracked values:

```m68k
    ; Without named samples:
    MPCM_play #$85
    Console.Sleep #60       ; sleep for 1 second of playback
    MPCM_setPitch #$DA/2    ; cut playback speed in half! (you must manually get the pitch)

    ; ✅ With named samples:
    MPCM_play #mysample.id
    Console.Sleep #60               ; sleep for 1 second of playback
    MPCM_setPitch #mysample.pitch/2 ; cut playback speed in half!
```
