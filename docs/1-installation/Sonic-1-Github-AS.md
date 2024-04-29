
# Installing Mega PCM 2 in Sonic 1 Github Disassembly (AS)

This is a step-by-step guide for installing Mega PCM 2 in Sonic 1 Github Disassembly. Note that it targets the **AS branch** of the disassembly.

While installing Mega PCM 2 is technically as easy as including a few files and several lines of bootstrap code, a lot of extra steps are required for integrating it with the game. After all, Sonic 1 comes with its own DAC driver and the main sound driver, SMPS. In this guide, we'll remove the old DAC driver, take out all the manual Z80 start/stops to ensure high-quality playback and integrate SMPS with Mega PCM 2.

All steps in the guide are designed to be as simple and short as reasonably possible and are arranged in easy to follow order. You can check yourself at various points of the guide by building a ROM and making sure your modifications work as expected. This guide assumes you have basic skills working with the disassembly: opening `.asm` files, being able to use _Search_ and _Search & Replace_ functions of your text editor and add or remove lines of code shown in the guide.


## Step 1. Disable the original DAC driver

At this step we simply disable the original DAC driver that Sonic 1 uses. It's as easy as removing a few blocks of code.

### Step 1.1. Remove old DAC driver loading subroutine

Open `sonic.asm` and search for `DACDriverLoad:` string (or `SoundDriverLoad:` if your disassembly version is pre-October 2023). Remove this routine completely:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ---------------------------------------------------------------------------
; Subroutine to load the DAC driver
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; SoundDriverLoad:
DACDriverLoad:
                nop     
                stopZ80
                resetZ80
                lea     (DACDriver).l,a0        ; load DAC driver
                lea     (z80_ram).l,a1          ; target Z80 RAM
                bsr.w   KosDec                  ; decompress
                resetZ80a
                nop     
                nop     
                nop     
                nop     
                resetZ80
                startZ80
                rts     
; End of function DACDriverLoad
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```


### Step 1.2. Remove calls to the old driver loading routine

Now you need to remove two calls to subroutine you've just removed.

In the same `sonic.asm` file, search for `DACDriverLoad` string (`SoundDriverLoad` in older disassemblies). There should be 2 matches:

1. Remove `bsr.w DACDriverLoad` / `bsr.w SoundDriverLoad` line above the label `MainGameLoop:`;
2. Remove `bsr.w DACDriverLoad` / `bsr.w SoundDriverLoad` line under the label `GM_Title:` (this one is redundant in the original game, by the way).


### Step 1.3. Remove old DAC driver busy check in SMPS

Now open `s1.sounddriver.asm` file, find `UpdateMusic:` and remove the following code right under it (don't remove `UpdateMusic:` label itself):

```m68k
; ---------------------------------------------------------------------------
; Subroutine to update music more than once per frame
; (Called by horizontal & vert. interrupts)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_71B4C:
UpdateMusic:

; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                stopZ80
                nop     
                nop     
                nop     
; loc_71B5A:
.updateloop:
                btst    #0,(z80_bus_request).l          ; Is the z80 busy?
                bne.s   .updateloop                     ; If so, wait

                btst    #7,(z80_dac_status).l           ; Is DAC accepting new samples?
                beq.s   .driverinput                    ; Branch if yes
                startZ80
                nop     
                nop     
                nop     
                nop     
                nop     
                bra.s   UpdateMusic
; ===========================================================================
; loc_71B82:
.driverinput:
; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

## Step 2. Remove Z80 stops globally

The original game frequently stops Z80 to make sure Z80 driver doesn't access ROM (or M68K bus in general) during DMA transfers. Mega PCM 2 has automatic DMA protection system and **is guaranteed** not to access ROM during DMA (inside VBlank), so Z80 stops are now redundant.

Moreover, those stops harm DAC playback quality and are the main reason Mega Drive games have "scratchy" playback. While other DAC driver cannot survive without ROM access, Mega PCM 2 can when needed.

### Step 2.1. Remove all Z80 macros

This is another easy one and tearing things down is fun, isn't it?

Open `Macros.asm` file and remove all Z80 related macros: `stopZ80`, `startZ80`, `waitZ80`, `resetZ80`, `resetZ80a`. Basically, scroll down until you see the following fragment and **remove all the lines shown below**:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ---------------------------------------------------------------------------
; stop the Z80
; ---------------------------------------------------------------------------

stopZ80:        macro
                move.w  #$100,(z80_bus_request).l
                endm

; ---------------------------------------------------------------------------
; wait for Z80 to stop
; ---------------------------------------------------------------------------

waitZ80:        macro
.wait:  btst    #0,(z80_bus_request).l
                bne.s   .wait
                endm

; ---------------------------------------------------------------------------
; reset the Z80
; ---------------------------------------------------------------------------

resetZ80:       macro
                move.w  #$100,(z80_reset).l
                endm

resetZ80a:      macro
                move.w  #0,(z80_reset).l
                endm

; ---------------------------------------------------------------------------
; start the Z80
; ---------------------------------------------------------------------------

startZ80:       macro
                move.w  #0,(z80_bus_request).l
                endm

; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```


### Step 2.2. Remove all invocations of Z80 macros

Now you need to remove every occurrence of now-removed macros. There are several ways to pull it off:

1. **The easy way:** Do global search & replace (across **all files** in your disassembly), replacing `stopZ80`, `startZ80` and `waitZ80` with an empty string. **Use case-sensitive search!** Note that `resetZ80`, `resetZ80a` should be already taken care of when removing `DACDriverLoad`/`SoundDriverLoad`. Case-sensitive search is important, otherwise you may corrupt `DoStopZ80:` label in `s1.sounddriver.asm` file will become `Do:` (this is unlikely to break things, it's just incorrect);
2. **The hard way:** try building your ROM by running `build.bat` or `build.lua`. You'll a ton of errors regarding the removed macros. Use error log (also saved as `sonic.log`) as a reference to find and remove all lines referencing `stopZ80`, `startZ80` and `waitZ80`.


### Step 2.3. Check yourself

At this point you should have the old DAC driver disabled and Z80 stops completely removed.

Try to build your ROM by running `build.bat` or `build.lua`. Here's your checklist:

1. Make sure you don't get assembly errors. If you do (errors are logged in `sonic.log`), make sure you removed all macro invocations in **Step 2.2**.
2. Your ROM should at least boot, **but music and sounds will be broken**. If you ROM doesn't boot, you likely didn't fully remove code in **Step 1.3**, or you still have other Z80 starts/stops intact.


## Step 3. Installing Mega PCM 2

It's finally time to get to the star of the show, Mega PCM itself! As mentioned in the beginning, installing Mega PCM itself is a easy as dropping a few files and adding a few lines of code. However, a few more steps are required in case of Sonic 1, because of a few hacks involving the infamous "Sega PCM" sample.

### Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table

Another easy one. You need to download a few files and copy them relative to your disassembly's root directory.

1. Download AS bundle of Mega PCM 2. Copy `MegaPCM.asm` file to your disassembly's root.
2. Download Sonic 1 sample table. Copy `SampleTable.asm` and other files to your directory and replace DAC samples (but don't remove the old ones yet!)


### Step 3.2. Include Mega PCM and Sonic 1 sample table

Open `sonic.asm` and search for `SoundDriver:`. Right after that label, add lines marked with `++`:

```m68k
                include "MegaPCM.asm"                   ; ++ ADD THIS LINE
                include "SampleTable.asm"               ; ++ ADD THIS LINE

SoundDriver:    include "s1.sounddriver.asm"
```


### Step 3.3. Remove hacks for Sega PCM

Mega PCM's sample table now properly includes Sega PCM, so we can remove the old one and hacks around it.

Open `s1.sounddriver.asm` file and find `SegaPCM:` label. You need to remove both the sample inclusion and checks surrounding it, basically, **remove all the lines shown below**:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ---------------------------------------------------------------------------
; 'Sega' chant PCM sample
; ---------------------------------------------------------------------------
                ; Don't let Sega sample cross $8000-byte boundary
                ; (DAC driver doesn't switch banks automatically)
                if ((*)&$7FFF)+Size_of_SegaPCM>$8000
                        align $8000
                endif
SegaPCM:        binclude        "sound/dac/sega.pcm"
SegaPCM_End
                even

                if SegaPCM_End-SegaPCM>$8000
                        fatal "Sega sound must fit within $8000 bytes, but you have a $\{SegaPCM_End-SegaPCM} byte Sega sound."
                endif
                if SegaPCM_End-SegaPCM>Size_of_SegaPCM
                        fatal "Size_of_SegaPCM = $\{Size_of_SegaPCM}, but you have a $\{SegaPCM_End-SegaPCM} byte Sega sound."
                endif

; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

Next, let's replace hack-ish code that the original Sonic 1 used to play Sega PCM. 

In the same `s1.sounddriver.asm` file, find `PlaySegaSound:` label. Replace all its code as follows:

```m68k
; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound
; ---------------------------------------------------------------------------
; Sound_E1: PlaySega:
PlaySegaSound:
                moveq   #$FFFFFF8C, d0          ; ++ request SEGA PCM sample
                jmp     MegaPCM_PlaySample      ; ++
```

We've just replaced a busy loop that freezes the game to play SEGA PCM with a simple request to Mega PCM 2. Since the game logic is no longer blocked, we need to add extra wait for SEGA screen, or else it will be over instantaneously.

In `sonic.asm` file, go to `Sega_WaitEnd:` and just **above** it, modify `move.w  #$1E,(v_demolength).w` as follows:

```m68k
                move.w  #$1E+2*60,(v_demolength).w         ; was $1E
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
                ;RaiseError "Bad sample table (code %<.b d0>)"  ; uncomment if you have MD Debugger and Error handler installed
                illegal
.SampleTableOk:
```

Note that if you have [MD Debugger and Error handler](https://github.com/vladikcomper/md-modules/releases) installed, you can uncomment `RaiseError` macro to display a more meaningful message if something goes wrong during initialization.


### Step 3.5. Check yourself: Making sure Mega PCM works

In the same `sonic.asm` file, insert the following code right **below** the driver load code you've just added in **Step 3.4**:

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

### Step 4.1. Fully remove the old DAC driver

Open `s1.sounddriver.asm` and search for `DACDriver:` (or `Kos_Z80:` if disassembly is pre-October 2023). You should see the following fragment, **remove all the lines shown below**:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ===========================================================================
; ---------------------------------------------------------------------------
; DAC driver (Kosinski-compressed)
; ---------------------------------------------------------------------------
; Kos_Z80:
DACDriver:      include         "sound/z80.asm"

; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

Now that this inclusion is gone, let's clean up some files:
- Remove `sound/z80.asm` file;
- Remove `sound/dac/snare.dpcm` file (it's now replaced with `snare.pcm`);
- Remove `sound/dac/sega.pcm` file (it's now replaced with `sega.wav` for convenience);
- You may also remove `sound/dac/readme.txt` file, because it's not accurate anymore.

Open `Constants.asm` and remove the following lines (if you have pre-September 2023 disassembly, `z80_dac_timpani_pitch` will be named `z80_dac3_pitch`):
```m68k
; REMOVE EVERYTHING BELOW       >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;z80_dac3_pitch:        equ z80_ram+zSample3_Pitch      ; BEFORE SEPTEMBER 2023
z80_dac_timpani_pitch:  equ z80_ram+zTimpani_Pitch      ; AFTER SEPTEMBER 2023
z80_dac_status:         equ z80_ram+zDAC_Status
z80_dac_sample:         equ z80_ram+zDAC_Sample

; REMOVE EVERYTHING ABOVE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```

Now that the old driver and its constants are removed, we're on the final stretch for patching SMPS to work with Mega PCM 2 instead!

### Step 4.2. Patching SMPS for Mega PCM 2: DAC playback

Open `s1.sounddriver.asm` file and find `.gotsampleduration:` label (it's a part of `DACUpdateTrack` subroutine). You need to edit it as follows (remove all lines marked with `--`, add lines marked with `++`):

```m68k
; loc_71C88:
.gotsampleduration:
                move.l  a4,TrackDataPointer(a5) ; Save pointer
                btst    #2,TrackPlaybackControl(a5)                     ; Is track being overridden?
                bne.s   .locret                 ; Return if yes
                moveq   #0,d0
                move.b  TrackSavedDAC(a5),d0    ; Get sample
                cmpi.b  #$80,d0                 ; Is it a rest?
                beq.s   .locret                 ; Return if yes
                ;btst    #3,d0                  ; -- REMOVE THIS LINE
                ;bne.s   .timpani               ; -- REMOVE THIS LINE
                ;move.b  d0,(z80_dac_sample).l  ; -- REMOVE THIS LINE
                MPCM_stopZ80                            ; ++
                move.b  d0, z80_ram+Z_MPCM_CommandInput ; ++ send DAC sample to Mega PCM
                MPCM_startZ80                           ; ++
; locret_71CAA:
.locret:
                rts
; End of function DACUpdateTrack
```

The removed code branched to `.timpani` to setup pitch hacks for the old driver. With Mega PCM, we don't need dirty hacks anymore, so remove the following code completely:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ===========================================================================
; loc_71CAC:
.timpani:
                subi.b  #$88,d0         ; Convert into an index
                move.b  DAC_sample_rate(pc,d0.w),d0
                ; Warning: this affects the raw pitch of sample $83, meaning it will
                ; use this value from then on.
                move.b  d0,(z80_dac_timpani_pitch).l
                move.b  #$83,(z80_dac_sample).l ; Use timpani
                rts     
```

### Step 4.3. Patching SMPS for Mega PCM 2: FM routines

Finally, in the same `s1.sounddriver.asm` file, find this `WriteFMIorII:` label and replace everything until `; End of function WriteFMII` with this code:

```m68k
; ===========================================================================
; loc_72716:
WriteFMIorIIMain:
                btst    #2,TrackPlaybackControl(a5)     ; Is track being overriden by sfx?
                bne.s   .locret                         ; Return if yes
                bra.w   WriteFMIorII
; ===========================================================================
; locret_72720:
.locret:
                rts     

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_72722:
WriteFMIorII:
                move.b  TrackVoiceControl(a5), d2
                subq.b  #4, d2                          ; Is this bound for part I or II?
                bcc.s   WriteFMIIPart                   ; If yes, branch
                addq.b  #4, d2                          ; Add in voice control bits
                add.b   d2, d0                          ;

; ---------------------------------------------------------------------------
WriteFMI:
                MPCM_stopZ80
                MPCM_ensureYMWriteReady
                move.b  d0, (ym2612_a0).l
                move.b  d1, (ym2612_d0).l
.waitLoop:      tst.b   (ym2612_d0).l           ; is FM busy?
                bmi.s   .waitLoop               ; branch if yes
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
                move.b  d0, (ym2612_a1).l
                move.b  d1, (ym2612_d1).l
.waitLoop:      tst.b   (ym2612_d0).l           ; is FM busy?
                bmi.s   .waitLoop               ; branch if yes
                move.b  #$2A, (ym2612_a0).l     ; restore DAC output for Mega PCM
                MPCM_startZ80           
                rts
; End of function WriteFMII
```

You've just replaced `WriteFMIorIIMain`, `WriteFMIorII`, `WriteFMI` and `WriteFMII` routines with better, more optimized versions compatible with Mega PCM 2.


### Step 4.3. Check yourself: Testing SMPS and Mega PCM 2

And that concludes the basic integration of Mega PCM 2 with Sonic 1's SMPS!

Run `build.bat` or `build.lua` to build your ROM and test it. All music, sounds and DAC samples should work now.
