
# How to play DAC BGM using SMPS and Mega PCM 2

This guide will show you an easy and reliable way of implementing DAC BGMs natively using SMPS and Mega PCM 2 in Sonic 1 Github AS disassembly.

The overall process goes as follows:
1. Add your music to Mega PCM 2's sample table;
2. Replace or create a dummy SMPS music file which plays your BGM's sample in a DAC channel;
3. That's it, you can now play your BGM natively using SMPS.

This method has the following advantages:
- Your BGM is immediately available in the sound test;
- SMPS treats it as a proper BGM: it will stop when another BGM is played and will react to fade in/fade out commands (unless it's `TYPE_PCM_TURBO` which excludes volume control).

## 1. Adding a sample for BGM

Let's assume you have `my-bgm.wav` file in the correct format you need to use as a BGM. Add it to your project's directory (preferably `sound/dac` directory in case of Sonic 1 disassembly).

Now open Mega PCM 2's sample table (`SampleTable.asm`) and add your sample in any free slot in the table, or append it to the end:

```m68k
SampleTable:
    ;           type            pointer     Hz
    dcSample    TYPE_DPCM,      Kick,       8000                ; $81
    dcSample    TYPE_PCM,       Snare,      24000               ; $82
    dcSample    TYPE_DPCM,      Timpani,    7250                ; $83
    dcSample    TYPE_PCM,       MyBGM,      0, FLAGS_LOOP       ; $84  NOTE: sample rate is auto-detected from WAV file
    ; <...>
    dc.w    -1  ; end marker

; ---------------------------------------------------------------
    ; <...>
    incdac  MySFX, "sound/dac/my-bgm.wav"
```

You'll probably want your BGM to loop (otherwise it'll just stop once finishes), so add `FLAGS_LOOP` flag for the sample as shown above.

Make sure your file's format is supported by Mega PCM 2. WAV or raw PCM files should be in **8-bit unsigned mono** format and have the supported sample rate. See [Sample table format](../Sample_table_format.md) for more information.

> [!NOTE]
>
> Mega PCM 2 verifies your sample table during boot. For WAV files, it will error out if the format is not supported. If you have MD Debugger installed and you followed Mega PCM 2 installation guide precisely, you should see a very detailed error description pointing to the problematic sample. See [Troubleshooting](../Troubleshooting.md) for more information.

## 2. Wraping sample into SMPS music file 

For simplicity, let's assume you want to replace GHZ BGM (sound id `$81`) with your new DAC BGM. In Sonic 1 Github AS disassembly, it's located in `sound/music/Mus81 - GHZ.asm` file.

Open this file and replace its contants with the following:

```m68k
Mus81_GHZ_Header:
    smpsHeaderStartSong 1
    smpsHeaderVoice     Mus81_GHZ_Voices
    smpsHeaderChan      $01, $00
    smpsHeaderTempo     $01, $03

    smpsHeaderDAC       Mus81_GHZ_DAC

Mus81_GHZ_DAC:
    dc.b    $84         ; play BGM sample
    smpsStop

Mus81_GHZ_Voices:
```

Replace `$84` below `Mus81_GHZ_DAC:` with your sample id, if it's different.

Now, when you build the ROM and go to GHZ, it should play your new DAC BGM instead.

> [!WARNING]
>
> Your DAC BGM can still be interrupted by DAC SFX, so make sure you don't play them.

> [!WARNING]
>
> Your BGM won't support fade out effect if it has `TYPE_PCM_TURBO` or `FLAGS_SFX` flag. "Fade in" effect after 1-up jingle also isn't supported by SMPS for continously playing samples (only newly requested drums will be picked up in normal BGMs).
