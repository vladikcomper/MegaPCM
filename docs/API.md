
# Mega PCM 2 API

This document describes macros and routines exposed by Mega PCM 2 you can use after installation. While this API is meant for M68K assembly projects, routines are also optimized for possible C/C++ integrations (only uses scratch registers and one argument at most).

The bare minimum you need is `MegaPCM_LoadDriver` and `MegaPCM_LoadSampleTable` routines for setup and `MPCM_play` macro for playback.


## Table of contents

- [API Cheat Sheet](#api-cheat-sheet)
- [Macros](#macros-reference)
    - [`MPCM_play`](#mpcm_play)
    - [`MPCM_pause`](#mpcm_pause)
    - [`MPCM_unpause`](#mpcm_unpause)
    - [`MPCM_stop`](#mpcm_stop)
    - [`MPCM_setPan`](#mpcm_setpan)
    - [`MPCM_setSfxPan`](#mpcm_setsfxpan)
    - [`MPCM_setVol`](#mpcm_setvol)
    - [`MPCM_setSfxVol`](#mpcm_setsfxvol)
    - [`MPCM_setPitch`](#mpcm_setpitch)
- [Routines](#routines-reference)
    - [`MegaPCM_LoadDriver`](#megapcm_loaddriver)
    - [`MegaPCM_LoadSampleTable`](#megapcm_loadsampletable)
    - [`MegaPCM_PlaySample`](#megapcm_playsample)
    - [`MegaPCM_PausePlayback`](#megapcm_pauseplayback)
    - [`MegaPCM_UnpausePlayback`](#megapcm_unpauseplayback)
    - [`MegaPCM_StopPlayback`](#megapcm_stopplayback)
    - [`MegaPCM_SetPan`](#megapcm_setpan)
    - [`MegaPCM_SetSFXPan`](#megapcm_setsfxpan)
    - [`MegaPCM_SetVolume`](#megapcm_setvolume)
    - [`MegaPCM_SetSFXVolume`](#megapcm_setsfxvolume)
    - [`MegaPCM_SetActiveSamplePitch`](#megapcm_setactivesamplepitch)


## API Cheat Sheet

Here's a minimal Mega PCM 2 example which demonstrates most of API calls. [MD Shell](https://github.com/vladikcomper/md-modules/tree/master/modules/mdshell)'s `Console.Sleep` macro is used here to wait given number of frames during playback.

```m68k
Main:
    ; Bootstrap code
    jsr     MegaPCM_LoadDriver
    lea     SampleTable, a0
    jsr     MegaPCM_LoadSampleTable

    ; Initiate playback
    MPCM_setPan #$40                ; pan left
    MCPM_setVol #8                  ; 50% volume
    MPCM_play #mybgm.id

    ; Playback control & effects
    Console.Sleep #60               ; wait 1 second
    MPCM_setPitch #mybgm.pitch/2    ; 50% playback speed
    Console.Sleep #60               ; wait 1 second
    MPCM_pause
    Console.Sleep #30               ; wait 0.5 seconds
    MPCM_unpause
    Console.Sleep #300              ; wait 5 seconds
    MPCM_stop
    rts

SampleTable:
;                   type        pointer  Hz     flags
mybgm:  dcSample    TYPE_DPCM,  MyBGM,   16000, FLAGS_LOOP
        dc.w    -1    ; end marker

        incdac  MyBGM, "dac/mybgm.dpcmq"
```

See `examples/` directory for more usage examples.


## Macros Reference

This section documents macro commands exposed by Mega PCM 2 bundles since version 2.1. All these commands have routine equivalents, e.g.: `MPCM_play` is equivalent to `jsr MegaPCM_PlaySample`. Macros are usually faster and more convenient to use as they generate code in-place as opposed to calling routines and returning, but they result in slightly larger code.

For controlling playback, prefer macros over routines unless you really wish to save space.

### `MPCM_play`

_(Added in Mega PCM 2.1)_

Plays given sample by ID (>=$81). If currently playing sample has a higher priority, this command is ignored.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Syntax**

```m68k
    MPCM_play sampleIdOp
```

**Arguments**

- `sampleIdOp` - Sample ID operand (e.g. #$81, #mysample.id, d0)

**Examples**

```m68k
    MPCM_play #$81
    MPCM_play #mysample.id      ; when used with Named samples
    MPCM_play d1                ; you should pass sample ID to d1
```

> [!WARNING]
>
> Don't forget `#` before the argument, unless you pass a register or memory address! This macro accepts an operand, not a value! Think of `MPCM_play X` as `move.b X, MegaPCM_CommandInput_Addr`, so you need to pass e.g. `#$81`, not `$81`.

**See also:** A callable [`MegaPCM_PlaySample`](#megapcm_playsample) routine, which uses this macro under the hood.

### `MPCM_pause`

_(Added in Mega PCM 2.1)_

Pauses playback completely until "unpause" command is sent or a new sample is requested.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Syntax**

```m68k
    MPCM_pause
```

**See also:** A callable [`MegaPCM_PausePlayback`](#megapcm_pauseplayback) routine, which uses this macro under the hood.

### `MPCM_unpause`

_(Added in Mega PCM 2.1)_

Unpauses playback. If playback wasn't paused, it has no effect (rather than clearing the last sent command).

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Syntax**

```m68k
    MPCM_unpause
```

**See also:** A callable [`MegaPCM_UnpausePlayback`](#megapcm_unpauseplayback) routine, which uses this macro under the hood.

### `MPCM_stop`

_(Added in Mega PCM 2.1)_

Stops playback completely, regardless of currently playing sample's priority.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Syntax**

```m68k
    MPCM_stop
```

**See also:** A callable [`MegaPCM_StopPlayback`](#megapcm_stopplayback) routine, which uses this macro under the hood.

### `MPCM_setPan`

_(Added in Mega PCM 2.1)_

Sets the default panning for normal (non-SFX) samples. SFX samples use a separate pan setting.

Note that Mega PCM 2 will update panning *only when* a new sample starts playing.

**Syntax**

```m68k
    MPCM_setPan panOp
```

**Arguments**

- `panOp` - Panning operand (e.g. `#$40`, `#$80`, `#$C0`, `d0` etc)

**Examples**

```m68k
    MPCM_setPan #$40
    MPCM_setPan d0      ; you should pass pan setting to d0
```

**See also:** A callable [`MegaPCM_SetPan`](#megapcm_setpan) routine, which uses this macro under the hood.

### `MPCM_setSfxPan`

_(Added in Mega PCM 2.1)_

Sets the default panning for SFX samples. Normal samples use a separate pan setting and are not affected by this.

Note that Mega PCM 2 will update panning *only when* a new sample starts playing.

**Syntax**

```m68k
    MPCM_setSfxPan panOp
```

**Arguments**

- `panOp` - Panning operand (e.g. `#$40`, `#$80`, `#$C0`, `d0` etc)

**Examples**

```m68k
    MPCM_setSfxPan #$C0
    MPCM_setSfxPan d6      ; you should pass pan setting to d6
```

**See also:** A callable [`MegaPCM_SetSfxPan`](#megapcm_setsfxpan) routine, which uses this macro under the hood.

### `MPCM_setVol`

_(Added in Mega PCM 2.1)_

Sets volume for normal (non-SFX) samples. SFX samples use a separate volume setting.

Mega PCM 2 updates volume once per frame. This setting is ignored in "turbo playback" mode.

**Syntax**

```m68k
    MPCM_setVol volumeOp
```

**Arguments**

- `volumeOp` - Volume operand (e.g. `#0` (max), `#$F` (min), `d0` etc)

**Examples**

```m68k
    MPCM_setVol #$F
    MPCM_setVol #0
    MPCM_setVol d2      ; you should pass volume setting to d2
```

**See also:** A callable [`MegaPCM_SetVolume`](#megapcm_setvolume) routine, which uses this macro under the hood.

### `MPCM_setSfxVol`

_(Added in Mega PCM 2.1)_

Sets volume for SFX samples. Normal samples use a separate volume setting and are not affected by this.

Mega PCM 2 updates volume once per frame. This setting is ignored in "turbo playback" mode.

**Syntax**

```m68k
    MPCM_setSfxVol volumeOp
```

**Arguments**

- `volumeOp` - Volume operand (e.g. `#0` (max), `#$F` (min), `d0` etc)

**Examples**

```m68k
    MPCM_setSfxVol #0
    MPCM_setSfxVol #$F
    MPCM_setSfxVol d3      ; you should pass volume setting to d3
```

**See also:** A callable [`MegaPCM_SetSfxVolume`](#megapcm_setsfxvolume) routine, which uses this macro under the hood.


### `MPCM_setPitch`

_(Added in Mega PCM 2.1)_

Updates pitch of currently playing sample. Mega PCM pulls this setting once per frame. This is usually used for pitch effects (e.g. slowdown) and to pull it off properly, you should be aware of which sample is playing and its original (base) pitch value (see example below).

> [!WARNING]
>
> You cannot request to play a sample and immediately set its pitch! E.g. `MPCM_play` followed by `MPCM_setPitch` won't work. Because Mega PCM will only accept your sample by the end of VBlank and reset pitch after loading it. `MPCM_setPitch` is designed for gradually altering pitch over time for currently playing samples.

**Syntax**

```m68k
    MPCM_setPitch pitchOp
```

**Arguments**

- `pitchOp` - Pitch operand (e.g. `#mysample.pitch`, `#0` = 0%, `#$FF` = 100% base rate)

**Examples**

```m68k
    MPCM_play #mysample.id
    Console.Sleep #60               ; sleep for 60 frames
    MPCM_setPitch #mysample.pitch/2 ; cut playback speed in half!
```

**See also:** A callable [`MegaPCM_SetActiveSamplePitch`](#megapcm_setactivesamplepitch) routine, which uses this macro under the hood.

## Routines Reference

### `MegaPCM_LoadDriver`

Loads Mega PCM driver into Z80 memory and waits for its initialization. You only need to call this function once during boot.

> [!NOTE]
>
> Mega PCM 2 performs a few benchmarks during initialization to perfectly calibrate timings for both real hardware and inaccurate emulators alike. This process takes 3-4 frames and `MegaPCM_LoadDriver` will only return once calibration is complete.

**Usage:**

```m68k
    jsr     MegaPCM_LoadDriver       ; takes 3-4 frames to boot
```

**Uses:**

- `d0-d1`, `a0-a1`


### `MegaPCM_LoadSampleTable`

Loads a given sample table to Z80 memory. You must call this function after initialization to be able to play samples by IDs. Sample tables are defined using convenience macros provided by Mega PCM.

> [!NOTE]
>
> You can use several sample tables and switch between them on the fly. However, uploading a large sample table may affect Mega PCM's performance and timings on that frame, so it's recommended to do so when Mega PCM is idling.

> [!NOTE]
>
> If you have [MD Debugger and Error handler](https://github.com/vladikcomper/md-modules/releases) installed, you can take advantage of detailed error reporting if something goes wrong, since Mega PCM 2 library comes bundled with `MPCM_Debugger_LoadSampleTableException` debugger.

**Usage:**

```m68k
    lea     YourSampleTable, a0
    jsr     MegaPCM_LoadSampleTable
    tst.w   d0                          ; has function returned error code?
    beq.s   SampleTable_ok              ; if not, branch
    ; If you have MD Debugger v.2.5 or above:
    RaiseError "MegaPCM_LoadSampleTable returned %<.b d0>", MPCM_Debugger_LoadSampleTableException
    ; Otherwise:
    illegal

SampleTable_ok:
    ; <...>

; ---------------------------------------------------------------
SampleTable:
    ;           type            pointer     Hz                  ; sample id
    dcSample    TYPE_DPCM,      Kick,       8000                ; $81
    dcSample    TYPE_PCM,       Snare,      24000               ; $82
    dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
    dc.w    -1  ; end marker

; ---------------------------------------------------------------
    incdac  Kick, "dac/kick.dpcm"
    incdac  Snare, "dac/snare.pcm"
    incdac  Timpani, "dac/timpani.dpcm"
    even
```

**Input:**

- `a0` - sample table pointer

**Output:**

- `d0` - zero on success, non-zero error code on failure
- `a0` - pointer to a problematic sample in table (if applicable)

**Uses:**

- `d0-d1`, `a0-a1`

**Error codes:**

Error codes are included in Mega PCM definitions:

```m68k
MPCM_ST_TOO_MANY_SAMPLES:           equ $01     ; Too many samples in table
MPCM_ST_UNKNOWN_SAMPLE_TYPE:        equ $02     ; Unknown sample type or missing end marker. Please use one of: TYPE_PCM, TYPE_DPCM, TYPE_PCM_TURBO, TYPE_NONE

MPCM_ST_PITCH_NOT_SET:              equ $10     ; Sample rate can't be auto-detected (only works for .WAV files). Please set it manually

MPCM_ST_WAVE_INVALID_HEADER:        equ $20     ; WAVE error: Invalid WAVE header
MPCM_ST_WAVE_BAD_AUDIO_FORMAT:      equ $21     ; WAVE error: Unsupported audio format. Only PCM is supported
MPCM_ST_WAVE_NOT_MONO:              equ $22     ; WAVE error: Audio must be mono
MPCM_ST_WAVE_NOT_8BIT:              equ $23     ; WAVE error: Audio must be 8-bit unsigned PCM
MPCM_ST_WAVE_BAD_SAMPLE_RATE:       equ $24     ; WAVE error: Unsupported sample rate. Use <=25100 Hz for TYPE_PCM or 32000 Hz for TYPE_PCM_TURBO.
MPCM_ST_WAVE_MISSING_DATA_CHUNK:    equ $25     ; WAVE error: Failed to locate 'data' chunk

MPCM_ST_DPCM_HQ_UNSUPPORTED_VERSION:equ $30     ; DPCM-HQ error: Unsupported version specified in header
MPCM_ST_DPCM_HQ_BAD_SAMPLE_RATE:    equ $31     ; DPCM-HQ error: Unsupported sample rate. Use <=20600 Hz for TYPE_DPCM or 25800 Hz for TYPE_DPCM_TURBO.
```

### `MegaPCM_PlaySample`

Plays given sample by ID (>=$81). If currently playing sample has a higher priority, this command is ignored.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    move.b  #$81, d0            ; play the first sample in table
    jsr     MegaPCM_PlaySample
```

**Input:**

- `d0 .b` - sample id to play (>=$81)


### `MegaPCM_PausePlayback`

Pauses playback completely until `MegaPCM_UnpausePlayback` is called or a new sample is requested.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_PausePlayback
```


### `MegaPCM_UnpausePlayback`

Unpauses playback. If playback wasn't paused, it has no effect (rather than clearing the last sent command).

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_UnpausePlayback
```


### `MegaPCM_StopPlayback`

Stops playback completely, regardless of currently playing sample's priority.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, roughly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_StopPlayback
```


### `MegaPCM_SetPan`

Sets the default panning for normal (non-SFX) samples. SFX samples use a separate pan setting.

Note that Mega PCM 2 will update panning *only when* a new sample starts playing.

**Usage:**

```m68k
    move.b  #$40, d0
    jsr     MegaPCM_SetPan
```

**Input:**

- `d0 .b` - panning (`$40`, `$80` or `$C0`)


### `MegaPCM_SetSFXPan`

Sets the default panning for SFX samples. Normal samples use a separate pan setting.

Note that Mega PCM 2 will update panning *only when* a new sample starts playing.

**Usage:**

```m68k
    move.b  #$40, d0
    jsr     MegaPCM_SetSFXPan
```

**Input:**

- `d0 .b` - panning (`$40`, `$80` or `$C0`)


### `MegaPCM_SetVolume`

Sets volume for normal (non-SFX) samples. SFX samples use a separate volume setting.

Mega PCM 2 updates volume once per frame. This setting is ignored in "turbo playback" mode.

**Usage:**

```m68k
    moveq   #8, d0              ; 50% volume
    jsr     MegaPCM_SetVolume
```

**Input:**

- `d0 .b` - volume level (`0` = max, `$F` = min)


### `MegaPCM_SetSFXVolume`

Sets volume for SFX samples. Normal samples use a separate volume setting.

Mega PCM 2 updates volume once per frame. This setting is ignored in "turbo playback" mode.

**Usage:**

```m68k
    moveq   #8, d0              ; 50% volume
    jsr     MegaPCM_SetSFXVolume
```

**Input:**

- `d0 .b` - volume level (`0` = max, `$F` = min)

### `MegaPCM_SetActiveSamplePitch`

_(Added in Mega PCM 2.1)_

Updates pitch of currently playing sample. Mega PCM pulls this setting once per frame. This is usually used for pitch effects (e.g. slowdown) and to pull it off properly, you should be aware of which sample is playing and its original (base) pitch value (see example below).

> [!WARNING]
>
> You cannot request to play a sample and immediately set its pitch! E.g. `jsr MegaPCM_PlaySample` followed by `jsr MegaPCM_SetActiveSamplePitch` won't work. Because Mega PCM will only accept your sample by the end of VBlank and reset pitch after loading it. This command is designed for gradually altering pitch over time for currently playing samples.

**Usage:**

```m68k
    move.b  #mysample.pitch/2, d0
    jsr     MegaPCM_SetActiveSamplePitch        ; 50% playback speed
```

**Input:**

- `d0 .b` -  pitch level (`0` = 0%, `$FF` = 100% base rate)

