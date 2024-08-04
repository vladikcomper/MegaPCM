
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
    dcSample    TYPE_PCM,       MySFX,      0, FLAGS_SFX        ; $84  NOTE: sample rate is auto-detected from WAV file
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
    move.b  #<<YOUR SAMPLE ID>>, d0
    jsr     MegaPCM_PlaySample
```

Where `<<YOUR SAMPLE ID>>` is a sample number in Mega PCM's sample table. You usually count these manually starting from $81 (comments in the sample table above help in tracking those numbers).

In our example ID should be `$84` (as noted in the sample table).


> [!WARNING]
>
> As of version 2.0, samples with `FLAGS_SFX` have the highest priority and cannot be interrupted by other samples, even if they have `FLAGS_SFX` set as well. This may not be desired in some scenarios, where you want currently playing SFX to cut when another one is played.
>
> In this case, however, the only easy workaround is to remove `FLAGS_SFX` from your sample and risk it being interrupted by BGM drums and inheriting their settings (panning and volume). Another workaround, which I don't recommend because of how hard & dirty it is, is to do `jsr MegaPCM_StopPlayback`, wait 1 frame for Mega PCM to accept the command and then play the desired SFX.
