
# Mega PCM 2 integration for Sonic 1 Github disassembly

## Step 1. Disable the original DAC driver

**Step 1.1. Remove old DAC driver loading subroutine (`DACDriverLoad`/`SoundDriverLoad`)**

Open `sonic.asm` and search for `DACDriverLoad:` (or `SoundDriverLoad:` if your disassembly version is pre-October 2023). Remove this routine completely:

```m68k
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
```

**Step 1.2. Remove calls to `DACDriverLoad`/`SoundDriverLoad`**

Now you need to remove two calls to `DACDriverLoad` (`SoundDriverLoad` in older disassemblies).

1. Remove `bsr.w DACDriverLoad` / `bsr.w SoundDriverLoad` under `GM_Title:`
2. Remove `bsr.w DACDriverLoad` / `bsr.w SoundDriverLoad` above `MainGameLoop:`

**Step 1.3. Remove old DAC driver busy check in SMPS**

While in `s1.sounddriver.asm`, find `UpdateMusic:` and remove the following code right under it (don't remove `UpdateMusic:` label itself):

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
```

## Step 2. Remove Z80 stops globally

**Step 2.1. Remove all Z80 macros**

This is an easy one and tearing stuff down is fun, isn't it?

Open `Macros.asm` and remove all Z80 related macros: `stopZ80`, `startZ80`, `waitZ80`, `resetZ80`, `resetZ80a`. Basically **all these lines need to be removed**:

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
```


**Step 2.2. Remove all invocations of Z80 macros**

Now you need to remove every occurance of now-removed macros. There are several ways to pull it off:

1. **The easy way:** global search & replace, replacing `stopZ80`, `startZ80` and `waitZ80` with an empty string **using case-sensitive search**. Note that `resetZ80`, `resetZ80a` should be already taken care of when removing `DACDriverLoad`/`SoundDriverLoad`. Case-sensitive search is important, otherwise you may corrupt `DoStopZ80:` label in `s1.sounddriver.asm` file will become `Do:` (this is unlikely to break things, it's just incorrect).
2. **The hard way:** try building your ROM by running `build.bat` or `build.lua`. You'll a ton of errors regarding the removed macros. Use error log (also saved as `sonic.log`) as a reference to find and remove all lines referencing `stopZ80`, `startZ80` and `waitZ80`.

**Step 2.3. Check yourself**

At this point you should have the old DAC driver disabled and Z80 stops completely removed.

Build your ROM by running `build.bat` or `build.lua`. Make sure you don't get errors. Your ROM should also boot, **but music and sounds will be broken**. If you ROM doesn't boot, you likely didn't fully remove code in **Step 1.3**, or you still have other Z80 starts/stops intact.

## Step 3. Installing Mega PCM 2

**Step 3.1. Download and unpack Mega PCM and Sonic 1 sample table.**

Now it's time to get to the meat! 

1. Download AS bundle of Mega PCM 2. Copy `MegaPCM.asm` file to your disassembly's root.
2. Download Sonic 1 sample table. Copy `SampleTable.asm` and other files to your directory and replace DAC samples (don't remove old ones yet).

**Step 3.2. Include Mega PCM and Sonic 1 sample table.**

Open `sonic.asm` and search for `SoundDriver:`. Right after that label, add lines marked with `++`:

```m68k
                include "MegaPCM.asm"                   ; ++ ADD THIS LINE
                include "SampleTable.asm"               ; ++ ADD THIS LINE

SoundDriver:    include "s1.sounddriver.asm"
```

**Step 3.3. Remove hacks for Sega PCM**

Mega PCM's sample table now properly includes Sega PCM, so we can remove the old one.

Open `s1.sounddriver.asm`, find `PlaySegaSound:` label. Replace all the code with the following:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound
; ---------------------------------------------------------------------------
; Sound_E1: PlaySega:
PlaySegaSound:
                moveq   #$FFFFFF8C, d0          ; ++ request SEGA PCM sample
                jmp     MegaPCM_PlaySample      ; ++
```

Remove this:

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
```

**Step 3.4. Load Mega PCM and the sample table upon boot**

Above `MainGameLoop:`

```m68k
                jsr     MegaPCM_LoadDriver
                lea     SampleTable, a0
                jsr     MegaPCM_LoadSampleTable
                tst.w   d0                      ; was sample table loaded successfully?
                beq.s   .SampleTableOk
                ;RaiseError "Bad sample table (code %<.b d0>)"  ; uncomment if you have MD Debugger and Error handler installed
                illegal
.SampleTableOk:
```

**Step 3.5. Check yourself: Making sure Mega PCM works**

Above `MainGameLoop:`

```m68k
                ; REMOVE ME ONCE TESTED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                moveq   #$FFFFFF8C, d0          ; request SEGA PCM sample
                jsr     MegaPCM_PlaySample
                bra.s   *                       ; FREEZE, BECAUSE IT'S A TEST
```

Build your ROM. You should see black screen and SEGA chant should play.

If everything works, **remove this code now**. It's time to integrate our sound drivers proper!


## Step 4. Integrating SMPS with Mega PCM 2

**Step 4.1. Fully remove the old DAC driver**

Now, open `s1.sounddriver.asm` and search for `DACDriver:` (or `Kos_Z80:` if disassembly is pre-October 2023).

Remove this:

```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

; ===========================================================================
; ---------------------------------------------------------------------------
; DAC driver (Kosinski-compressed)
; ---------------------------------------------------------------------------
; Kos_Z80:
DACDriver:      include         "sound/z80.asm"
```

Now that this inclusion is gone, let's clean up some files:
- Remove `sound/z80.asm` file;
- Remove `sound/dac/snare.dpcm` file (it's now replaced with `snare.pcm`);
- Remove `sound/dac/sega.pcm` file (it's now replaced with `sega.wav` for convenience).

Open `Constants.asm` and remove the following lines (if you have pre-September 2023 disassembly, `z80_dac_timpani_pitch` will be named `z80_dac3_pitch`):
```m68k
; REMOVE EVERYTHING BELOW >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;z80_dac3_pitch:        equ z80_ram+zSample3_Pitch      ; BEFORE SEPTEMBER 2023
z80_dac_timpani_pitch:  equ z80_ram+zTimpani_Pitch      ; AFTER SEPTEMBER 2023
z80_dac_status:         equ z80_ram+zDAC_Status
z80_dac_sample:         equ z80_ram+zDAC_Sample
```

Now that the old driver and its constants are removed, we're on the final stretch for patching SMPS to work with Mega PCM 2 instead!

**Step 4.2. Patching SMPS for Mega PCM 2: DAC playback**

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

**Step 4.3. Patching SMPS for Mega PCM 2: FM routines**

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
                move.b  d0, (ym2612_a1).l
                move.b  d1, (ym2612_d1).l
.waitLoop:      tst.b   (ym2612_d0).l           ; is FM busy?
                bmi.s   .waitLoop               ; branch if yes
                move.b  #$2A, (ym2612_a0).l     ; restore DAC output for Mega PCM
                MPCM_startZ80           
                rts
; End of function WriteFMII
```

You've just replaced `WriteFMIorIIMain`, `WriteFMIorII`, `WriteFMI` and `WriteFMII` routines with better, more optimized versions comptabile with Mega PCM 2.


**Step 4.3. Check yourself: Testing SMPS and Mega PCM 2**

And that concludes the basic integration of Mega PCM 2 with Sonic 1's SMPS!

Run `build.bat` or `build.lua` to build your ROM and test it. All music, sounds and DAC samples should work now.
