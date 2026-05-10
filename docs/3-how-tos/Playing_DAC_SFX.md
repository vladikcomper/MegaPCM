
# How to play SFX samples with Mega PCM 2

Mega PCM 2 makes it easy to add arbitrary WAV or PCM/DPCM files and playing them at any time during the game.

Doing so is extremely easy and only involves 2 steps:

1. Add a new sample in Mega PCM 2's sample table with `FLAGS_SFX` flag;
2. Play it using `MegaPCM_PlaySample`.

Let's go over them in detail.

## 1. Adding a sample for SFX

Let's assume you have `my-sfx.wav` file in the correct format you need to play. Add it to your project's directory (preferably `sound/dac` directory in case of Sonic 1 disassembly).

Now open Mega PCM 2's sample table (`SampleTable.asm`) and add your sample in any free slot in the table, or append it to the end:

```m68k
SampleTable:
        ;           type            pointer     Hz
        dcSample    TYPE_DPCM,      Kick,       8000                ; $81
        dcSample    TYPE_PCM,       Snare,      24000               ; $82
        dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
sfx:    dcSample    TYPE_PCM,       MySFX,      0, FLAGS_SFX        ; $84  NOTE: sample     rate is auto-detected from WAV file
        ; <...>
        dc.w    -1  ; end marker

; ---------------------------------------------------------------
        ; <...>
        incdac  MySFX, "sound/dac/my-sfx.wav"
```

It's highly recommended that your sample has `FLAGS_SFX` set in the sample table (as shown above). It will still work without it, but it may get interrupted by BGM drums, which would have the same priority otherwise.

Make sure your file's format is supported by Mega PCM 2. WAV or raw PCM files should be in **8-bit unsigned mono** format and have the supported sample rate. See [Sample table format](../Sample_table_format.md) for more information.

> [!NOTE]
>
> Mega PCM 2 verifies your sample table during boot. For WAV files, it will error out if the format is not supported. If you have MD Debugger installed and you followed Mega PCM 2 installation guide precisely, you should see a very detailed error description pointing to the problematic sample. See [Troubleshooting](../Troubleshooting.md) for more information.

## 2. Playing the sample

Use this code to play your sample when desired:

```m68k
    MPCM_play #sfx.id
```

`sfx.id` refers to the sample ID in Mega PCM's sample table, as in this example, we've added `sfx:` label before `MySFX` sample (remember that all labels must be unique!). 

Or alternatively, you can use this older approach:

```m68k
    ; Alternative, older code:
    move.b  #sfx.id, d0
    jsr     MegaPCM_PlaySample
```

`MPCM_play #X` and `move.b #X, d0 / jsr MegaPCM_PlaySample` are interchangeable, but the former results in a cleaner and more flexible code. The only minor downside is that it generates code in-place, which takes slightly more space (but it's faster because you don't have to call a subroutine). So unless you need to save a few bytes, always prefer `MPCM_play` (and `MPCM_*` macros in general).
