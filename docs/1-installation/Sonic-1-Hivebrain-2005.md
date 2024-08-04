
# Installing Mega PCM 2 in Sonic 1 Hivebrain 2005 Disassembly

> [!WARNING]
>
> Sonic 1 Hivebrain 2005 Disassembly is outdated and its usage is generally not recommended for newer projects. If you're looking to start a fresh project, consider using modern disassemblies like Sonic 1 GitHub Disassembly instead.

This is a step-by-step guide for installing Mega PCM 2 in the old Sonic 1 Hivebrain Disassembly (2005 version). If you're starting a new project, it's highly recommended to use a newer disassembly instead, for example, [Sonic 1 Github Disassembly](Sonic-1-Github-AS.md).

While installing Mega PCM 2 is technically as easy as including a few files and several lines of bootstrap code, a lot of extra steps are required for integrating it with the game. After all, Sonic 1 comes with its own DAC driver and the main sound driver, SMPS. In this guide, we'll remove the old DAC driver, take out all the manual Z80 start/stops to ensure high-quality playback and integrate SMPS with Mega PCM 2.

All steps in the guide are designed to be as simple and short as reasonably possible and are arranged in easy to follow order. You can check yourself at various points of the guide by building a ROM and making sure your modifications work as expected. This guide assumes you have basic skills working with the disassembly: opening `.asm` files, being able to use _Search_ and _Search & Replace_ functions of your text editor and add or remove lines of code shown in the guide.

## Table of Contents

- [Step 1. Disable the original DAC driver](#step-1-disable-the-original-dac-driver)
  - [Step 1.1. Remove old DAC driver loading subroutine](#step-11-remove-old-dac-driver-loading-subroutine)
  - [Step 1.2. Remove calls to the old driver loading routine](#step-12-remove-calls-to-the-old-driver-loading-routine)
  - [Step 1.3. Remove old DAC driver busy check in SMPS](#step-13-remove-old-dac-driver-busy-check-in-smps)
- [Step 2. Remove Z80 stops globally](#step-2-remove-z80-stops-globally)
  - [Step 2.1. Mass-remove "start Z80" command](#step-21-mass-remove--start-z80--command)
  - [Step 2.2. Mass-remove "stop Z80" command](#step-22-mass-remove--stop-z80--command)
  - [Step 2.3. Check yourself](#step-23-check-yourself)
- [Step 3. Installing Mega PCM 2](#step-3-installing-mega-pcm-2)
  - [Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table](#step-31-download-and-unpack-mega-pcm-and-sonic-1-sample-table)
  - [Step 3.2. Include Mega PCM and Sonic 1 sample table](#step-32-include-mega-pcm-and-sonic-1-sample-table)
  - [Step 3.3. Remove hacks for Sega PCM](#step-33-remove-hacks-for-sega-pcm)
  - [Step 3.4. Fully remove the old DAC driver](#step-34-fully-remove-the-old-dac-driver)
  - [Step 3.5. Load Mega PCM 2 and the sample table upon boot](#step-35-load-mega-pcm-2-and-the-sample-table-upon-boot)
  - [Step 3.6. Check yourself: Making sure Mega PCM works](#step-36-check-yourself-making-sure-mega-pcm-works)
- [Step 4. Integrating SMPS with Mega PCM 2](#step-4-integrating-smps-with-mega-pcm-2)
  - [Step 4.1. Patching SMPS for Mega PCM 2: DAC playback](#step-41-patching-smps-for-mega-pcm-2--dac-playback)
  - [Step 4.2. Patching SMPS for Mega PCM 2: FM routines](#step-42-patching-smps-for-mega-pcm-2--fm-routines)
  - [Step 4.3. Check yourself: Testing SMPS and Mega PCM 2](#step-43-check-yourself-testing-smps-and-mega-pcm-2)


## Step 1. Disable the original DAC driver

At this step we simply disable the original DAC driver that Sonic 1 uses. It's as easy as removing a few blocks of code.

### Step 1.1. Remove old DAC driver loading subroutine

Open `sonic1.asm` and search for `SoundDriverLoad:` string. Remove this routine completely:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ---------------------------------------------------------------------------
; Subroutine to load the sound driver
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SoundDriverLoad:                        ; XREF: GameClrRAM; TitleScreen
                nop     
                move.w  #$100,($A11100).l ; stop the Z80
                move.w  #$100,($A11200).l ; reset the Z80
                lea     (Kos_Z80).l,a0  ; load sound driver
                lea     ($A00000).l,a1
                bsr.w   KosDec          ; decompress
                move.w  #0,($A11200).l
                nop     
                nop     
                nop     
                nop     
                move.w  #$100,($A11200).l ; reset the Z80
                move.w  #0,($A11100).l  ; start the Z80
                rts     
; End of function SoundDriverLoad
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```


### Step 1.2. Remove calls to the old driver loading routine

Now you need to remove two calls to subroutine you've just removed.

In the same `sonic1.asm` file, search for `SoundDriverLoad` string. There should be 2 matches:

1. Remove `bsr.w SoundDriverLoad` line above the label `MainGameLoop:`;
2. Remove `bsr.w SoundDriverLoad` line under the label `TitleScreen:` (this one is redundant in the original game, by the way).


### Step 1.3. Remove old DAC driver busy check in SMPS

In `sonic1.asm` file, find `sub_71B4C:` (this is SMPS entry point) and remove the following code right under it (don't remove `sub_71B4C:` label itself):

```m68k
; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


sub_71B4C:                              ; XREF: loc_B10; PalToCRAM

; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                move.w  #$100,($A11100).l ; stop the Z80
                nop     
                nop     
                nop     

loc_71B5A:
                btst    #0,($A11100).l
                bne.s   loc_71B5A

                btst    #7,($A01FFD).l
                beq.s   loc_71B82
                move.w  #0,($A11100).l  ; start the Z80
                nop     
                nop     
                nop     
                nop     
                nop     
                bra.s   sub_71B4C
; ===========================================================================

loc_71B82:
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```


## Step 2. Remove Z80 stops globally

The original game frequently stops Z80 to make sure Z80 driver doesn't access ROM (or M68K bus in general) during DMA transfers. Mega PCM 2 has automatic DMA protection system and **is guaranteed** not to access ROM during DMA (inside VBlank), so Z80 stops are now redundant.

Moreover, those stops harm DAC playback quality and are the main reason Mega Drive games have "scratchy" playback. While other DAC drivers cannot survive without ROM access, Mega PCM 2 can when needed.

### Step 2.1. Mass-remove "start Z80" command

Since Sonic 1 Hivebrain 2005 disassembly doesn't use macros for common operations like start/stop Z80, we have to manually find instructions that implement them through the code.

In case of "start Z80" command, the code responsible for this operation always looks like this:

```m68k
                move.w  #0,($A11100).l  ; start the Z80
```

To quickly remove all instances of this instruction, in `sonic1.asm` file,  just do search and replace of `move.w  #0,($A11100).l` with an empty string (make sure to put TAB character between `move.w` and `#0`!)

### Step 2.2. Mass-remove "stop Z80" command

Stopping Z80 is with a slightly larger code snippet:

```m68k
                move.w  #$100,($A11100).l ; stop the Z80

<<SOMELABEL>>:
                btst    #0,($A11100).l  ; has Z80 stopped?
                bne.s   <<SOMELABEL>>   ; if not, branch
```

The `<<SOMELABEL>>` part is always different between the occurrences as it represents a unique label used for the "wait till Z80 fully stops" loop. This makes simple search & replace much harder.

This time, search for `move.w  #$100,($A11100).l` (make sure to put TAB character between `move.w` and `#0`!) and manually remove this and 3 more lines with the `<<SOMELABEL>>` part:

**Example 1:**

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                move.w  #$100,($A11100).l

loc_BC8:
                btst    #0,($A11100).l
                bne.s   loc_BC8
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

**Example 2:**
```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                move.w  #$100,($A11100).l ; stop the Z80

loc_C76:
                btst    #0,($A11100).l  ; has Z80 stopped?
                bne.s   loc_C76         ; if not, branch
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

This code **will always look the same**, there will always be 3 more lines to remove with a different label.

Keep searching for `move.w  #$100,($A11100).l` and manually removing additional lines as shown above until all occurrences are exhausted.


### Step 2.3. Check yourself

At this point you should have the old DAC driver disabled and Z80 stops completely removed.

Before going on, try searching for string `#0,($A11100).l` in `sonic1.asm`. **You shouldn't get any matches if you removed everything properly.** Then try searching for `#$100,($A11100).l` string, you shouldn't find anything either.

Now try to build your ROM by running `build.bat`. Here's your checklist:

1. Make sure you don't get assembly errors. If you do you won't see `s1built.bin` file or it'll be empty.
2. Your ROM should at least boot, **but music and sounds will be broken**. If you ROM doesn't boot, you likely didn't fully remove code in **Step 1.3**, or you still have other Z80 starts/stops intact.


## Step 3. Installing Mega PCM 2

It's finally time to get to the star of the show, Mega PCM itself! As mentioned in the beginning, installing Mega PCM itself is a easy as dropping a few files and adding a few lines of code. However, a few more steps are required in case of Sonic 1, because of a few hacks involving the infamous "Sega PCM" sample.


### Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table

Another easy one. You need to download a few files and copy them relative to your disassembly's root directory.

1. Go to Mega PCM's releases and find the most recent one: https://github.com/vladikcomper/MegaPCM/releases
2. Download `megapcm.zip` (release bundles) and open `asm68k` directory inside it (ASM68K bundle). Copy `MegaPCM.asm` from that directory to your disassembly's root.
3. Download `sample-tables.zip` and locate `sonic-1` directory inside. Copy `SampleTable.asm` and other files to your disassembly's directory.

### Step 3.2. Include Mega PCM and Sonic 1 sample table

Open `sonic1.asm` and search for `Go_SoundTypes:`. Right **above** that label, add lines marked with `++`:

```m68k
                include "MegaPCM.asm"                   ; ++ ADD THIS LINE
                include "SampleTable.asm"               ; ++ ADD THIS LINE

Go_SoundTypes:
```

### Step 3.3. Remove hacks for Sega PCM

Mega PCM's sample table now properly includes Sega PCM, so we can remove the old one and hacks around it.

In `sonic1.asm` find `SegaPCM:` label. Remove everything as shown below:

```m68k
SegaPCM:        incbin  sound\segapcm.bin               ; -- REMOVE THIS
                even                                    ; -- REMOVE THIS
```

Next, let's replace hack-ish code that the original Sonic 1 used to play Sega PCM. 

Find `Sound_E1:` label. Replace all its code as follows:

```m68k
; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound
; ---------------------------------------------------------------------------

Sound_E1:                               ; XREF: Sound_ExIndex
                moveq   #$FFFFFF8C, d0          ; ++ request SEGA PCM sample
                jmp     MegaPCM_PlaySample      ; ++
```

We've just replaced a busy loop that freezes the game to play SEGA PCM with a simple request to Mega PCM 2. Since the game logic is no longer blocked, we need to add extra wait for SEGA screen, or else it will be over instantaneously.

Go to `Sega_WaitEnd:` and just **above** it, modify `move.w  #$1E,($FFFFF614).w` as follows:

```m68k
                move.w  #$1E+2*60,($FFFFF614).w         ; was $1E
```

This adds extra 2 seconds of wait time. You can change it depending on your SEGA chant's length.


### Step 3.4. Fully remove the old DAC driver

In `sonic1.asm` search for `Kos_Z80:` and **remove all the lines shown below**:
```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Kos_Z80:        incbin  sound\z80_1.bin
                dc.w ((SegaPCM&$FF)<<8)+((SegaPCM&$FF00)>>8)
                dc.b $21
                dc.w (((EndOfRom-SegaPCM)&$FF)<<8)+(((EndOfRom-SegaPCM)&$FF00)>>8)
                incbin  sound\z80_2.bin
                even

; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

Now that this inclusion is gone, let's clean up some files:
- Remove `sound/z80_1.bin` and `sound/z80_2.bin` files;
- Remove `sound/segapcm.bin`.

Now that the old driver is removed, we're on the final stretch for patching SMPS to work with Mega PCM 2 instead!

### Step 3.5. Load Mega PCM 2 and the sample table upon boot

Finally, let's load Mega PCM 2 and its sample table during game's initialization.

Open `sonic.asm` file and find `MainGameLoop:` label. Just **above it**, insert the following code:

```m68k
                jsr     MegaPCM_LoadDriver
                lea     SampleTable, a0
                jsr     MegaPCM_LoadSampleTable
                tst.w   d0                      ; was sample table loaded successfully?
                beq.s   @SampleTableOk          ; if yes, branch
                if def(__DEBUG__)
                    ; for MD Debugger v.2.5 or above
                    RaiseError "MegaPCM_LoadSampleTable returned %<.b d0>", MPCM_Debugger_LoadSampleTableException
                else
                    illegal
                endif
@SampleTableOk:
```

Note that if you have [MD Debugger and Error handler](https://github.com/vladikcomper/md-modules/releases) installed, you can take advantage of detailed error reporting in Debug builds (`s1built.debug.bin`) if something goes wrong during initialization.

### Step 3.6. Check yourself: Making sure Mega PCM works

In `sonic1.asm` file, insert the following code right **below** the driver load code you've just added in **Step 3.5**:

```m68k
                ; REMOVE ME ONCE TESTED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                moveq   #$FFFFFF8C, d0          ; request SEGA PCM sample
                jsr     MegaPCM_PlaySample
                bra.s   *                       ; FREEZE, BECAUSE IT'S A TEST
```

Build your ROM. You should see a black screen and SEGA chant should play.

If everything works, **remove this code now**. It's time to integrate our sound drivers proper!


## Step 4. Integrating SMPS with Mega PCM 2

We're now on the final stretch! It's time to make SMPS and Mega PCM 2 work together. Up until this point, music and sounds were mostly broken, but we'll have everything fixed in no time.

### Step 4.1. Patching SMPS for Mega PCM 2: DAC playback

In `sonic1.asm` file, find `.loc_71C88:` label (it's a part of `DACUpdateTrack` subroutine). You need to edit it as follows (remove all lines marked with `--`, add lines marked with `++`):

```m68k
loc_71C88:
                move.l  a4,4(a5)
                btst    #2,(a5)
                bne.s   locret_71CAA
                moveq   #0,d0
                move.b  $10(a5),d0
                cmpi.b  #$80,d0
                beq.s   locret_71CAA
                ;btst   #3,d0                   ; -- REMOVE THIS LINE
                ;bne.s  loc_71CAC               ; -- REMOVE THIS LINE
                ;move.b d0,($A01FFF).l          ; -- REMOVE THIS LINE
                MPCM_stopZ80                            ; ++
                move.b  d0, $A00000+Z_MPCM_CommandInput ; ++ send DAC sample to Mega PCM
                MPCM_startZ80                           ; ++

locret_71CAA:
                rts     
```

The removed code branched to `loc_71CAC` to setup pitch hacks for the old driver. With Mega PCM, we don't need dirty hacks anymore, so remove the following code completely:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ===========================================================================

loc_71CAC:
                subi.b  #$88,d0
                move.b  byte_71CC4(pc,d0.w),d0
                move.b  d0,($A000EA).l
                move.b  #$83,($A01FFF).l
                rts     
; End of function sub_71C4E
```

### Step 4.2. Patching SMPS for Mega PCM 2: FM routines

Finally, find `loc_72716:` label and replace everything until `; End of function sub_72764` with this code:

```m68k
; ===========================================================================
loc_72716:
                btst    #2,(a5)                         ; Is track being overriden by sfx?
                bne.s   @locret                         ; Return if yes
                bra.w   sub_72722
; ===========================================================================
; locret_72720:
@locret:
                rts     

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

sub_72722:
                move.b  1(a5), d2
                subq.b  #4, d2                          ; Is this bound for part I or II?
                bcc.s   loc_7275A                       ; If part II, branch
                addq.b  #4, d2                          ; Add in voice control bits
                add.b   d2, d0                          ;

; ---------------------------------------------------------------------------
sub_7272E:
                MPCM_stopZ80
                MPCM_ensureYMWriteReady
@waitLoop:      tst.b   ($A04000).l             ; is FM busy?
                bmi.s   @waitLoop               ; branch if yes
                move.b  d0, ($A04000).l
                nop
                move.b  d1, ($A04001).l
                nop
                nop
@waitLoop2:     tst.b   ($A04000).l             ; is FM busy?
                bmi.s   @waitLoop2              ; branch if yes
                move.b  #$2A, ($A04000).l       ; restore DAC output for Mega PCM
                MPCM_startZ80
                rts
; End of function sub_7272E

; ===========================================================================
loc_7275A:
                add.b   d2,d0                   ; Add in to destination register

; ---------------------------------------------------------------------------
sub_72764:
                MPCM_stopZ80
                MPCM_ensureYMWriteReady
@waitLoop:      tst.b   ($A04000).l             ; is FM busy?
                bmi.s   @waitLoop               ; branch if yes
                move.b  d0, ($A04002).l
                nop
                move.b  d1, ($A04003).l
                nop
                nop
@waitLoop2:     tst.b   ($A04000).l             ; is FM busy?
                bmi.s   @waitLoop2              ; branch if yes
                move.b  #$2A, ($A04000).l       ; restore DAC output for Mega PCM
                MPCM_startZ80
                rts
; End of function sub_72764
```

You've just replaced FM routines with better, more optimized versions compatible with Mega PCM 2.


### Step 4.3. Check yourself: Testing SMPS and Mega PCM 2

And that concludes the basic integration of Mega PCM 2 with Sonic 1's SMPS!

Run `build.bat` to build your ROM and test it. All music, sounds and DAC samples should work now.

## Next steps

While this guide completes basic Mega PCM 2 installation, there are still a few exiting features and refinements your SMPS driver can't use yet! To take full advantage of Mega PCM 2 capabilities, with DAC fade in/fade out, pausing/unpausing as well as many QoL improvements, see the [Extended Mega PCM 2 integration guide](../2-advanced-integration/Sonic-1-Github-AS.md) (unfortunately, this guide is currently only available for S1 Github AS disassembly).
