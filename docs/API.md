
# Mega PCM 2 API

This document describes subroutines exposed by Mega PCM 2 that can you call after installation. While this API is meant for M68K assembly projects, it's also optimized for possible C/C++ integrations (only uses scratch registers and one argument at most).

The bare minimum you need is `MegaPCM_LoadDriver` and `MegaPCM_LoadSampleTable` for setup and `MegaPCM_PlaySample` for playback.


## Table of contents

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


## `MegaPCM_LoadDriver`

Loads Mega PCM driver into Z80 memory and waits for its initialization. You only need to call this function once during boot.

> [!NOTE]
>
> Mega PCM 2 performs a few benchmarks during initialization to perfectly calibrate timings for both real hardware and inaccurate emulators alike. This process takes 3-4 frames and `MegaPCM_LoadDriver` will only return once calibration is complete.

**Usage:**

```m68k
    jsr     MegaPCM_LoadDriver
```

**Uses:**

- d0-d1, a0-a1


## `MegaPCM_LoadSampleTable`

Loads a given sample table to Z80 memory. You must call this function after initialization to be able to play samples by IDs. Sample tables are defined using conveniant macros provided by Mega PCM.

> [!NOTE]
>
> You can use several sample tables and switch between them on the fly. However, uploading a large sample table may affect Mega PCM's performance and timings on that frame, so it's recommended to do so when Mega PCM is idling.

**Usage:**

```m68k
    lea     YourSampleTable, a0
    jsr     MegaPCM_LoadSampleTable
    tst.w   d0                          ; has function returned error code?
    bne     YourErrorHandler            ; your subroutine to display error code (d0) or fail
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

- a0 - sample table pointer

**Output:**

- d0 - zero on success, non-zero error code on failure
- a0 - pointer to a problemmatic sample in table (if applicable)

**Uses:**

- d0-d1, a0-a1

**Error codes:**

Error codes are included in Mega PCM definitions:

```m68k
MPCM_ST_TOO_MANY_SAMPLES:           equ $01
MPCM_ST_UNKNOWN_SAMPLE_TYPE:        equ $02

MPCM_ST_PITCH_NOT_SET:              equ $10

MPCM_ST_WAVE_INVALID_HEADER:        equ $20
MPCM_ST_WAVE_BAD_AUDIO_FORMAT:      equ $21
MPCM_ST_WAVE_NOT_MONO:              equ $22
MPCM_ST_WAVE_NOT_8BIT:              equ $23
MPCM_ST_WAVE_BAD_SAMPLE_RATE:       equ $24
MPCM_ST_WAVE_MISSING_DATA_CHUNK:    equ $25
```

## `MegaPCM_PlaySample`

Plays given sample by ID (>$80). If currently playing sample has a higher priority

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, rougly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    move.b  #$81, d0            ; play the first sample in table
    jsr     MegaPCM_PlaySample
```

**Input:**

- d0 .b - sample id to play (>$80)


## `MegaPCM_PausePlayback`

Pauses playback completely until `MegaPCM_UnpausePlayback` is called or a new sample is requested.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, rougly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_PausePlayback
```


## `MegaPCM_UnpausePlayback`

Unpauses playback, undoes the effect of `MegaPCM_PausePlayback`. If playback wasn't paused, it has no effect (rather than clearing the last sent command).

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, rougly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_UnpausePlayback
```


## `MegaPCM_StopPlayback`

Stops playback completely, regardless of sample flags or priority.

> [!NOTE]
>
> Mega PCM accepts commands (play, pause, stop) once per frame, rougly a few scanlines after VBlank is over. If commands are sent more than once per frame, only the last stored command will be processed.

**Usage:**

```m68k
    jsr     MegaPCM_StopPlayback
```


## `MegaPCM_SetPan`

Sets panning for normal (non-SFX) samples. SFX samples use a separate pan setting.

Note that Mega PCM 2 updates panning *only when* a sample starts playing.

**Usage:**

```m68k
    move.b  #$40, d0
    jsr     MegaPCM_SetPan
```

**Input:**

- d0 .b - panning ($40, $80 or $C0)


## `MegaPCM_SetSFXPan`

Sets panning for SFX samples. Normal samples use a separate pan setting.

Note that Mega PCM 2 updates panning *only when* a sample starts playing.

**Usage:**

```m68k
    move.b  #$40, d0
    jsr     MegaPCM_SetSFXPan
```

**Input:**

- d0 .b - panning ($40, $80 or $C0)


## `MegaPCM_SetVolume`

Sets volume for normal (non-SFX) samples. SFX samples use a separate volume setting.

Mega PCM 2 updates volume once per frame. This setting is ignored in 32 kHz "turbo playback" mode.

**Usage:**

```m68k
    moveq   #8, d0              ; 50% volume
    jsr     MegaPCM_SetVolume
```

**Input:**

- d0 .b - volume level (0 = max, $F = min)


## `MegaPCM_SetSFXVolume`

Sets volume for SFX samples. Normal samples use a separate volume setting.

Mega PCM 2 updates volume once per frame. This setting is ignored in 32 kHz "turbo playback" mode.

**Usage:**

```m68k
    moveq   #8, d0              ; 50% volume
    jsr     MegaPCM_SetSFXVolume
```

**Input:**

- d0 .b - volume level (0 = max, $F = min)
