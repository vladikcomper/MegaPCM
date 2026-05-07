
# Installing Mega PCM 2 in Sonic 1 Github Disassembly

This is a step-by-step guide for installing Mega PCM 2 in [Sonic 1 Github Disassembly](https://github.com/sonicretro/s1disasm), it should work for both **AS** (the default) and **ASM68K** assembler branches, since they were aligned starting with 2026 releases.

> [!NOTE]
>
> This guide was tested against [v.26.03](https://github.com/sonicretro/s1disasm/releases/tag/v26.03) and [v.26.05](https://github.com/sonicretro/s1disasm/releases/tag/v26.05) versions of Sonic 1 Github disassembly. If newer releases introduce breaking changes not compatible with this guide, feel free to open an issue in this repository.

Installing Mega PCM 2 technically only involves adding a few files and several lines of bootstrap code, but quite a few extra steps are required for full integration with the game. After all, Sonic 1 comes with its own DAC driver and the main sound driver, SMPS. So we'll remove the old DAC driver, take out all the manual Z80 start/stops to ensure high-quality playback and integrate SMPS with Mega PCM 2.

All steps in the guide are designed to be as simple and short as reasonably possible and are arranged in easy to follow order. You can check yourself at various points of the guide by building a ROM and making sure your modifications work as expected. This guide assumes you have basic skills working with the disassembly: opening `.asm` files, being able to use _Search_ and _Search & Replace_ functions of your text editor and add or remove lines of code shown in the guide.

> [!NOTE]
>
> A ready-to-use Sonic 1 Disassembly with this guide applied as also available here: https://github.com/vladikcomper/s1disasm-megapcm2

## Table of Contents

- [Step 1. Remove old DAC driver](#step-1-remove-old-dac-driver)
  - [Step 1.1. Remove old DAC driver loading subroutine](#step-11-remove-old-dac-driver-loading-subroutine)
  - [Step 1.2. Remove old DAC driver busy check in SMPS](#step-12-remove-old-dac-driver-busy-check-in-smps)
  - [Step 1.3. Check yourself](#step-13-check-yourself)
- [Step 2. Remove Z80 stops globally](#step-2-remove-z80-stops-globally)
  - [Step 2.1. Remove all Z80 macros](#step-21-remove-all-z80-macros)
  - [Step 2.2. Remove all invocations of Z80 macros](#step-22-remove-all-invocations-of-z80-macros)
  - [Step 2.3. Check yourself](#step-23-check-yourself)
- [Step 3. Installing Mega PCM 2](#step-3-installing-mega-pcm-2)
  - [Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table](#step-31-download-and-unpack-mega-pcm-and-sonic-1-sample-table)
  - [Step 3.2. Include Mega PCM and Sonic 1 sample table](#step-32-include-mega-pcm-and-sonic-1-sample-table)
  - [Step 3.3. Remove hacks for Sega PCM](#step-33-remove-hacks-for-sega-pcm)
  - [Step 3.4. Load Mega PCM 2 and the sample table upon boot](#step-34-load-mega-pcm-2-and-the-sample-table-upon-boot)
  - [Step 3.5. Check yourself: Making sure Mega PCM works](#step-35-check-yourself-making-sure-mega-pcm-works)
- [Step 4. Integrating SMPS with Mega PCM 2](#step-4-integrating-smps-with-mega-pcm-2)
  - [Step 4.1. Patching SMPS for Mega PCM 2: DAC playback](#step-41-patching-smps-for-mega-pcm-2--dac-playback)
  - [Step 4.2. Patching SMPS for Mega PCM 2: FM routines](#step-42-patching-smps-for-mega-pcm-2--fm-routines)
  - [Step 4.3. Fully remove the old DAC driver](#step-43-fully-remove-the-old-dac-driver)
  - [Step 4.4. Check yourself: Testing SMPS and Mega PCM 2](#step-44-check-yourself-testing-smps-and-mega-pcm-2)
- [Next Steps](#next-steps)


## Step 1. Remove old DAC driver

At this step we simply remove Sonic 1's original DAC driver. It's as easy as removing a few files and blocks of code.

### Step 1.1. Remove old DAC driver loading routine

Open `sonic.asm` and search for `DACDriverLoad:` string (or `SoundDriverLoad:` if your disassembly version is pre-October 2023). **Remove** this routine completely:

```diff
- ; ===========================================================================
- ; ---------------------------------------------------------------------------
- ; Subroutine to load the DAC driver
- ; ---------------------------------------------------------------------------
- 
- ; SoundDriverLoad: <--- old misnomer
- DACDriverLoad:
-                 nop                                     ; delay
-                 stopZ80                                 ; request Z80 stop on
-                 deassertZ80Reset                        ; request Z80 reset off
-                 lea     (DACDriver).l,a0                ; load compressed DAC driver address as source
-                 lea     (z80_ram).l,a1                  ; set Z80 RAM address as target
-                 bsr.w   KosDec                          ; decompress the DAC driver into Z80 RAM
-                 assertZ80Reset                          ; request Z80 reset on
-                 nop                                     ; delay (while the Z80 resets)
-                 nop                                     ; ''
-                 nop                                     ; ''
-                 nop                                     ; ''
-                 deassertZ80Reset                        ; request Z80 reset off
-                 startZ80                                ; request Z80 stop off
-                 rts                                     ; return
- ; End of function DACDriverLoad
```

Now you need to remove the two calls to subroutine you've just removed.

In the same `sonic.asm` file, search for `DACDriverLoad` string (`SoundDriverLoad` in older disassemblies). There should be 2 matches:

1. Remove `bsr.w DACDriverLoad` line (`bsr.w SoundDriverLoad` in older version) above the label `MainGameLoop:`;
2. Remove `bsr.w DACDriverLoad` line (`bsr.w SoundDriverLoad` in older version) under the label `GM_Title:` (this one is redundant in the original game, by the way).


### Step 1.2. Remove old DAC driver busy check in SMPS

Now open `s1.sounddriver.asm` file, find `UpdateMusic:` and **remove the following code right under it** (don't remove `UpdateMusic:` label itself!):

```diff
; ---------------------------------------------------------------------------
; Subroutine to update music more than once per frame
; (Called by horizontal & vert. interrupts)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_71B4C:
UpdateMusic:
-                 stopZ80
-                 nop     
-                 nop     
-                 nop     
- ; loc_71B5A:
- .updateloop:
-                 btst    #0,(z80_bus_request).l          ; Is the z80 busy?
-                 bne.s   .updateloop                     ; If so, wait
- 
-                 btst    #7,(z80_dac_status).l           ; Is DAC accepting new samples?
-                 beq.s   .driverinput                    ; Branch if yes
-                 startZ80
-                 nop     
-                 nop     
-                 nop     
-                 nop     
-                 nop     
-                 bra.s   UpdateMusic
- ; ===========================================================================
- ; loc_71B82:
- .driverinput:
```

### Step 1.3. Check yourself

Let's make sure your ROM at least builds after these changes. To build, run `build.bat` or `build.lua` (AS). If there are no assembly errors, you're good for Step 2.

> [!NOTE]
>
> Don't expect ROM to work yet! At this point, even if it builds successfully, it won't boot (you'll see a black screen in most emulators) because we disrupted loading Z80 start/reset flow.


## Step 2. Remove Z80 stops globally

The original game frequently stops Z80 to make sure Z80 driver doesn't access ROM (or M68K bus in general) during DMA transfers. Mega PCM 2 has automatic DMA protection system and **is guaranteed** not to access ROM during DMA (inside VBlank), so Z80 stops are now redundant.

Moreover, those stops harm DAC playback quality and are the main reason Mega Drive games have "scratchy" playback. While other DAC drivers cannot survive without ROM access, Mega PCM 2 can when needed.

### Step 2.1. Remove all Z80 macros

This is another easy one and tearing things down is fun, isn't it?

Open `Macros.asm` file and remove all Z80 related macros: `stopZ80`, `startZ80`, `waitZ80`, `deassertZ80Reset`, `assertZ80Reset` (last two are `resetZ80`, `resetZ80a` if your disassembly is pre-July 2024). Basically, scroll down until you see the following fragment and **remove all the lines shown below**:

```diff
- ; ---------------------------------------------------------------------------
- ; stop the Z80
- ; ---------------------------------------------------------------------------
- 
- stopZ80:        macro
-                 move.w  #$100,(z80_bus_request).l
-                 endm
- 
- ; ---------------------------------------------------------------------------
- ; wait for Z80 to stop
- ; ---------------------------------------------------------------------------
- 
- waitZ80:        macro
- .wait:          btst    #0,(z80_bus_request).l
-                 bne.s   .wait
-                 endm
- 
- ; ---------------------------------------------------------------------------
- ; reset the Z80
- ; ---------------------------------------------------------------------------
- 
- deassertZ80Reset:       macro
-                 move.w  #$100,(z80_reset).l
-                 endm
- 
- assertZ80Reset: macro
-                 move.w  #0,(z80_reset).l
-                 endm
- 
- ; ---------------------------------------------------------------------------
- ; start the Z80
- ; ---------------------------------------------------------------------------
- 
- startZ80:       macro
-                 move.w  #0,(z80_bus_request).l
-                 endm
- 
```

> [!NOTE]
>
> If you're working on **ASM68K** branch, some macros may look slightly different, but their names are the same.


### Step 2.2. Remove all invocations of Z80 macros

Now you need to remove every occurrence of now-removed macros. There are several ways to pull it off:

- **The easy way (Recommended):** Do global search & replace (across **all files** in your disassembly), replacing `stopZ80`, `startZ80` and `waitZ80` with an empty string. **Use case-sensitive search!** If your editor supports regex, you can combine search term into: `stopZ80|startZ80|waitZ80`.

   Note that `assertZ80Reset`, `deassertZ80Reset` (`resetZ80`, `resetZ80a` in older versions) should be already taken care of when removing `DACDriverLoad`/`SoundDriverLoad`. Case-sensitive search is important, otherwise you may corrupt `DoStopZ80:` label in `s1.sounddriver.asm` file will become `Do:` (this is unlikely to break things, it's just incorrect);

- **The hard way (Manual removals):** Try building your ROM by running `build.bat` or `build.lua`. You'll a ton of errors regarding the removed macros. Use error log (also saved as `sonic.log`) as a reference to find and remove all lines referencing `stopZ80`, `startZ80` and `waitZ80`.


### Step 2.3. Check yourself

At this point you should have the old DAC driver disabled and Z80 stops completely removed.

Try to build your ROM by running `build.bat` or `build.lua` (AS). Here's your checklist:

1. Make sure you don't get assembly errors. If you do (errors are logged in `sonic.log`), make sure you removed all macro invocations in **Step 2.2**.
2. Your ROM should at least boot, **but music and sounds will be broken**. If you ROM doesn't boot, you likely didn't fully remove code in **Step 1.3**, or you still have other Z80 starts/stops intact.


## Step 3. Installing Mega PCM 2

It's finally time to get to the star of the show, Mega PCM itself! As mentioned at the beginning, installing Mega PCM itself is a easy as dropping a few files and adding a few lines of code. However, a few more steps are required in case of Sonic 1, because of a few hacks involving the infamous "Sega PCM" sample.

### Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table

Another easy one. You need to download a few files and copy them relative to your disassembly's root directory.

1. Go to Mega PCM's releases and find the most recent one: https://github.com/vladikcomper/MegaPCM/releases
2. Download `megapcm.zip` (release bundles). Locate `MegaPCM.asm` and `MegaPCM.Macros.asm` files for your assembler (`as` directory for AS, otherwise `asm68k`) and copy them your disassembly's root (`.asm` files, not the directory itself!).
3. Download `sample-tables.zip` and open `sonic-1` directory inside it. Copy `SampleTable.asm` and other files to your directory and replace DAC samples (but don't remove the old ones yet!)


### Step 3.2. Include Mega PCM and Sonic 1 sample table

Open `sonic.asm`. Near the very beginning, just above `include "Macros.asm"` include `MegaPCM.Macros.asm` file:

```diff
; ===========================================================================
; Simplifying macros and functions
+       include "MegaPCM.Macros.asm"
        include "Macros.asm"
```

Now search for `SoundDriver:`. Add new includes **right above this label** and, optionally, remove padding logic outlined in the disassembly:

```diff
-       ; SoundDriver starts at $71990 in all revisions, which amounts
-       ; to $62A bytes of padding for rev00 and $63C for rev01/rev02.
-       ; It appears to be placed in such a way that the sound driver
-       ; ends right on the $80000 mark in the ROM in all revisions.
-       ; From a technical standpoint, this padding serves no purpose.
-       if PaddingOptimization=0
-               if Revision=0
-                       dc.b    [$62A]$FF
-               else
-                       dc.b    [$63C]$FF
-               endif
-       endif
         
; ---------------------------------------------------------------------------
+
+               include "MegaPCM.asm"
+               include "SampleTable.asm"

SoundDriver:    include "s1.sounddriver.asm"
                even
```


### Step 3.3. Remove hacks for Sega PCM

Mega PCM's sample table now properly includes Sega PCM, so we can remove the old one and hacks around it.


Next, let's replace hack-ish code that the original Sonic 1 used to play Sega PCM. 

In the same `s1.sounddriver.asm` file, find `PlaySegaSound:` label. **Replace all** its code (until `rts`) with this:

```m68k
; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound
; ---------------------------------------------------------------------------
; Sound_E1: PlaySega:
PlaySegaSound:
                MPCM_play #dacSega.id
                rts
```

> [!NOTE]
>
> If you're using a custom `SampleTable.asm`, not the default one from Mega PCM release page, make sure your SEGA sample has `dacSega:` before `dcSample` for `dacSega.id` reference to work.

We've just replaced a busy loop that freezes the game to play SEGA PCM with a simple request to Mega PCM 2. Since the game logic is no longer blocked, we need to add extra wait for SEGA screen, or else it will be over instantaneously.

In `sonic.asm` file, go to `Sega_WaitEnd:` and just **above** it, modify `move.w  #30,(v_generictimer).w` (was `v_demolength` in older disassemblies) as follows:

```m68k
                move.w  #30+2*60,(v_generictimer).w         ; was 30
```

This adds extra 2 seconds of wait time. You can change it depending on your SEGA chant's length.


### Step 3.4. Load Mega PCM 2 and the sample table upon boot

Finally, let's load Mega PCM 2 and its sample table during game's initialization.

Open `sonic.asm` file and find `MainGameLoop:` label. Just **above it**, insert the following code:

```m68k
                jsr     MegaPCM_LoadDriver
                lea     SampleTable, a0
                jsr     MegaPCM_LoadSampleTable
                tst.w   d0                      ; was sample table loaded successfully?
                beq.s   .SampleTableOk          ; if yes, branch
                ifdef __DEBUG__ ; if def(__DEBUG__) for ASM68K
                    ; for MD Debugger v.2.5 or above
                    RaiseError "MegaPCM_LoadSampleTable returned %<.b d0>", MPCM_Debugger_LoadSampleTableException
                else
                    illegal
                endif
.SampleTableOk:
```

Note that if you have [MD Debugger and Error handler](https://github.com/vladikcomper/md-modules/releases) installed, you can take advantage of detailed error reporting in Debug builds (`s1built.debug.bin`) if something goes wrong during initialization.


### Step 3.5. Check yourself: Making sure Mega PCM works

In the same `sonic.asm` file, insert the following code right **below** the driver load code you've just added in **Step 3.4**:

```m68k
                ; REMOVE ME ONCE TESTED! >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                MPCM_play #dacSega.id
                bra.s   *                       ; FREEZE, BECAUSE IT'S A TEST
```

Build your ROM. You should see a black screen and SEGA chant should play.

> [!NOTE]
>
> If you get errors related to Mega PCM macros (e.g. `incdac`), make sure you're suing the correct bundle version for your assembler (e.g. `as` for The AS Macro Assembler, `asm68k` for ASM68K).

If everything works, **remove this code now**. It's time to integrate our sound drivers proper!


## Step 4. Integrating SMPS with Mega PCM 2

We're now on the final stretch! It's time to make SMPS and Mega PCM 2 work together. Up until this point, music and sounds were mostly broken, but we'll have everything fixed in no time.

### Step 4.1. Patching SMPS for Mega PCM 2: DAC playback

Open `s1.sounddriver.asm` file and find `.gotsampleduration:` label (it's a part of `DACUpdateTrack` subroutine). You need to remove highlighted lines and add `MPCM_play d0` as shown:

```diff
  ; loc_71C88:
  .gotsampleduration:
                  move.l  a4,SMPS_Track.DataPointer(a5)           ; Save pointer
                  btst    #2,SMPS_Track.PlaybackControl(a5)       ; Is track being overridden?
                  bne.s   .locret                                 ; Return if yes
                  moveq   #0,d0
                  move.b  SMPS_Track.SavedDAC(a5),d0      ; Get sample
                  cmpi.b  #$80,d0                         ; Is it a rest?
                  beq.s   .locret                         ; Return if yes
-                 btst    #3,d0                           ; Is bit 3 set (samples between $88-$8F)?
-                 bne.s   .timpani                        ; Various timpani
-                 move.b  d0,(z80_ram+zDAC_Sample).l
+                 MPCM_play d0
  ; locret_71CAA:
  .locret:
                  rts
- ; ===========================================================================
- ; loc_71CAC:
- .timpani:
-                 subi.b  #$88,d0                         ; Convert into an index
-                 move.b  DAC_sample_rate(pc,d0.w),d0
-                 ; Warning: this affects the raw pitch of sample $83, meaning it will
-                 ; use this value from then on.
-                 move.b  d0,(z80_ram+zTimpani_Pitch).l
-                 move.b  #$83,(z80_ram+zDAC_Sample).l    ; Use timpani
-                 rts
  ; End of function DACUpdateTrack
  
- ; ===========================================================================
- ; Note: this only defines rates for samples $88-$8D, meaning $8E-$8F are invalid.
- ; Also, $8C-$8D are so slow you may want to skip them.
- ; byte_71CC4:
- timpaniLoopCounter function scale,dpcmLoopCounter(int(zDAC_Timpani.sample_rate*scale))
- 
- DAC_sample_rate:
-                 dc.b timpaniLoopCounter(1.30)
-                 dc.b timpaniLoopCounter(1.20)
-                 dc.b timpaniLoopCounter(0.97)
-                 dc.b timpaniLoopCounter(0.95)
-                 dc.b $FF, $FF
-                 even
```

> [!NOTE]
>
> In **ASM68K** branch, `DAC_sample_rate` will appear as raw bytes instead of with `timpaniLoopCounter`. Remove it as usual.

### Step 4.2. Patching SMPS for Mega PCM 2: FM routines

Finally, in the same `s1.sounddriver.asm` file, find `WriteFMIorII:` label and **replace everything** until `; End of function WriteFMII` with this code:

```m68k
; ===========================================================================
; loc_72716:
WriteFMIorIIMain:
                btst    #2,SMPS_Track.PlaybackControl(a5); Is track being overriden by sfx?
                bne.s   .locret                         ; Return if yes
                bra.w   WriteFMIorII
; ===========================================================================
; locret_72720:
.locret:
                rts

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_72722:
WriteFMIorII:
                move.b  SMPS_Track.VoiceControl(a5), d2
                subq.b  #4, d2                          ; Is this bound for part I or II?
                bcc.s   WriteFMIIPart                   ; If yes, branch
                addq.b  #4, d2                          ; Add in voice control bits
                add.b   d2, d0                          ;

; ---------------------------------------------------------------------------
WriteFMI:
                MPCM_stopZ80
                MPCM_ensureYMWriteReady
.waitLoop:      tst.b   (ym2612_a0).l           ; is FM busy?
                bmi.s   .waitLoop               ; branch if yes
                move.b  d0, (ym2612_a0).l
                nop
                move.b  d1, (ym2612_d0).l
                nop
                nop
.waitLoop2:     tst.b   (ym2612_a0).l           ; is FM busy?
                bmi.s   .waitLoop2              ; branch if yes
                move.b  #$2A, (ym2612_a0).l     ; restore DAC output for Mega PCM
                MPCM_startZ80
                rts
; End of function WriteFMI

; ===========================================================================
; loc_7275A:
WriteFMIIPart:
                add.b   d2,d0                   ; Add in to destination register

; ---------------------------------------------------------------------------
WriteFMII:
                MPCM_stopZ80
                MPCM_ensureYMWriteReady
.waitLoop:      tst.b   (ym2612_a0).l           ; is FM busy?
                bmi.s   .waitLoop               ; branch if yes
                move.b  d0, (ym2612_a1).l
                nop
                move.b  d1, (ym2612_d1).l
                nop
                nop
.waitLoop2:     tst.b   (ym2612_a0).l           ; is FM busy?
                bmi.s   .waitLoop2              ; branch if yes
                move.b  #$2A, (ym2612_a0).l     ; restore DAC output for Mega PCM
                MPCM_startZ80
                rts
; End of function WriteFMII
```

> [!NOTE]
>
> If your disassembly is **pre-June 2024**, you should replace some variables in the code above:
> - `SMPS_Track.PlaybackControl(a5)` (new) -> `TrackPlaybackControl(a5)` (old)
> - `SMPS_Track.VoiceControl(a5)` (new) -> `TrackVoiceControl(a5)` (old)

You've just replaced `WriteFMIorIIMain`, `WriteFMIorII`, `WriteFMI` and `WriteFMII` routines with better, more optimized versions compatible with Mega PCM 2.

### Step 4.4. Fully remove the old DAC driver

This step slightly differs between AS and ASM68K branches of Sonic 1 Github disassembly, because AS assembles incorporates assemblying of old DAC driver into its build system. Use instructions relevant for your branch.

**For AS branch (default):**

Open `s1.sounddriver.asm` and search for `DACDriver:` (or `Kos_Z80:` if disassembly is pre-October 2023). You should see the following fragment, **remove all the lines shown below**:

```diff
- ; ===========================================================================
- ; ---------------------------------------------------------------------------
- ; DAC driver (Kosinski-compressed)
- ; ---------------------------------------------------------------------------
- ; Kos_Z80:
- DACDriver:      include         "sound/z80.asm"
```

Now find `SegaPCM:` label. You need to remove both the sample inclusion and checks surrounding it, basically, **remove all the lines shown below**:

```diff
- ; ---------------------------------------------------------------------------
- ; 'Sega' chant PCM sample
- ; ---------------------------------------------------------------------------
-                 ; Don't let Sega sample cross $8000-byte boundary
-                 ; (DAC driver doesn't switch banks automatically)
-                 if ((*)&$7FFF)+Size_of_SegaPCM>$8000
-                         align $8000
-                 endif
- SegaPCM:        binclude        "sound/dac/sega.pcm"
- SegaPCM_End
-                 even
- 
-                 if SegaPCM_End-SegaPCM>$8000
-                         fatal "Sega sound must fit within $8000 bytes, but you have a $\{SegaPCM_End-SegaPCM} byte Sega sound."
-                 endif
-                 if SegaPCM_End-SegaPCM>Size_of_SegaPCM
-                         fatal "Size_of_SegaPCM = $\{Size_of_SegaPCM}, but you have a $\{SegaPCM_End-SegaPCM} byte Sega sound."
-                 endif
```

Now that these `include`s are gone, let's remove unnecessary files:

- Remove `sound/z80.asm` file;
- Remove `sound/dac/pcm` and `sound/dac/dpcm` sub-directories
    - These are artifacts of old DAC driver, your Mega PCM samples are already added to `sound/dac` directory itself.

Now, we need to remove old DAC driver from the build system. Open `build.lua` and remove highlighted lines and replace call to `common.build_rom_and_handle_failure(...)` as shown with one added line:

```diff
- --------------
- -- Settings --
- --------------
- 
- -- Set this to true to use a better compression algorithm for the DAC driver.
- -- Having this set to false will use an inferior compression algorithm that
- -- results in an accurate ROM being produced.
- local improved_dac_driver_compression = false
- 
- ---------------------
- -- End of settings --
- ---------------------
```

Finally, in the same `build.lua` file, remove and alter the following lines as shown:

```diff

- -- Produce PCM and DPCM data.
- common.convert_pcm_files_in_directory("sound/dac/pcm")
- common.convert_dpcm_files_in_directory("sound/dac/dpcm")

  -- Build the ROM.
- local compression = improved_dac_driver_compression and "kosinski-optimised" or "kosinski"
  common.build_rom_and_handle_failure("sonic", "s1built", "", "-p=FF -z=0," .. compression .. ",Size_of_DAC_driver_guess,after", false, "https://github.com/sonicretro/s1disasm")
+ common.build_rom_and_handle_failure("sonic", "s1built", "", "-p=FF", false, "https://github.com/sonicretro/s1disasm")
```

**For ASM68K branch:**

Open `s1.sounddriver.asm` and search for `DACDriver:`; you should see the following fragment, **remove all the lines shown below**:

```diff
-; ===========================================================================
-; ---------------------------------------------------------------------------
-; DAC driver (Kosinski-compressed)
-; ---------------------------------------------------------------------------
-; Kos_Z80:
-DACDriver:
-        ; In the ASM68K branch, the DAC driver is a binary blob. We do some
-        ; hackery here to manually patch some of its pointers. In the
-        ; AS branch, this driver is properly disassembled.
-        binclude    "sound/z80.bin", 0, $15
-        dc.b ((SegaPCM&$FF8000)/$8000)&1                        ; Least bit of bank ID (bit 15 of address)
-        binclude    "sound/z80.bin", $16, 6
-        dc.b ((SegaPCM&$FF8000)/$8000)>>1                       ; ... the remaining bits of bank ID (bits 16-23)
-        binclude    "sound/z80.bin", $1D, $93
-        dc.w ((SegaPCM&$FF)<<8)+((SegaPCM&$7F00)>>8)|$80                ; Pointer to Sega PCM, relative to start of ROM bank (i.e., little_endian($8000 + SegaPCM&$7FFF)
-        binclude    "sound/z80.bin", $B2, 1
-        dc.w (((SegaPCM_End-SegaPCM)&$FF)<<8)+(((SegaPCM_End-SegaPCM)&$FF00)>>8)    ; ... the size of the Sega PCM (little endian)
-        binclude    "sound/z80.bin", $B5, $16AB
-        even
```

Now find `SegaPCM:` label. You need to remove both the sample inclusion and checks surrounding it, basically, **remove all the lines shown below**:

```diff
- ; ---------------------------------------------------------------------------
- ; 'Sega' chant PCM sample
- ; ---------------------------------------------------------------------------
-         ; Don't let Sega sample cross $8000-byte boundary
-         ; (DAC driver doesn't switch banks automatically)
-         if ((*)&$7FFF)+Size_of_SegaPCM>$8000
-             align $8000
-         endif
- SegaPCM:    binclude    "sound/dac/sega.pcm"
- SegaPCM_End
- SegaPCM.size:   equ SegaPCM_End-SegaPCM
-         even
- 
-         if SegaPCM.size>$8000
-             inform 3,"Sega sound must fit within $8000 bytes, but you have a $%h byte Sega sound.",SegaPCM_End-SegaPCM
-         endif
-         if SegaPCM.size>Size_of_SegaPCM
-             inform 3,"Size_of_SegaPCM = $%h, but you have a $%h byte Sega sound.",Size_of_SegaPCM,SegaPCM_End-SegaPCM
-         endif
```

Now the driver is gone, let's remove unnecessary files:

- Remove `sound/z80.bin` file;
- Remove old files from `sound/dac` directory:
  - `sound/dac/sega.pcm`
  - `sound/dac/snare.dpcm`
  - `sound/dac/readme.txt`


### Step 4.3. Check yourself: Testing SMPS and Mega PCM 2

And that concludes the basic integration of Mega PCM 2 with Sonic 1's SMPS!

Run `build.bat` or `build.lua` to build your ROM and test it. All music, sounds and DAC samples should work now.


## Next steps

While this guide completes basic Mega PCM 2 installation, there are still a few exciting features and refinements your SMPS driver can't use yet! To take full advantage of Mega PCM 2 capabilities, with DAC fade in/fade out, pausing/unpausing as well as many QoL improvements, see the [Extended Mega PCM 2 integration guide](../2-advanced-integration/Sonic-1-Github-AS.md).
