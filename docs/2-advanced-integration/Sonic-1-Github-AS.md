
# Extended Mega PCM 2 integration in Sonic 1 Github Disassembly (AS)

> [!WARNING]
>
> This guide is work-in-progress, some sections are pending (DAC fade in/fade out and a few fixes). Please see S1 SMPS integration from `examples/` directory for a complete implementation example.

In the installation guide we only achieved the most basic integration between SMPS and Mega PCM 2. To take advantage of Mega PCM 2's features like DAC fade in/out and pause/unpause and fix a few potential issues, further SMPS modifications are necessary.

> [!NOTE]
> 
> This guide was written based on the reference S1 SMPS integration from `examples/` directory. You can see [`examples/s1-smps-integration/s1.sounddriver.asm`](../../examples/s1-smps-integration/s1.sounddriver.asm) as a working example.

## Table of Contents

- [Restore DAC panning](#restore-dac-panning)
- [Implement DAC pause/unpause](#implement-dac-pause-unpause)
- [Don't stop DAC and SFX on fading](#don-t-stop-dac-and-sfx-on-fading)
- [Implement DAC fade in and fade out](#implement-dac-fade-in-and-fade-out)

## Restore DAC panning

To keep everything in sync and consistent, Mega PCM 2 takes over and "owns" the DAC channel, which includes DAC panning. SMPS, however, also tries to directly control every channel, including DAC and this may lead to a few inconsistencies, like non-working panning. The fix is easy enough and should make panning flag on SMPS side fully functional again.

In `s1.sounddriver.asm` search for `cfPanningAMSFMS:`, you should see something like this:
```m68k
; loc_72ACC:
cfPanningAMSFMS:
                move.b  (a4)+,d1                        ; New AMS/FMS/panning value
                tst.b   SMPS_Track.VoiceControl(a5)     ; Is this a PSG track?
                bmi.s   locret_72AEA                    ; Return if yes
                move.b  SMPS_Track.AMSFMSPan(a5),d0     ; Get current AMS/FMS/panning
                andi.b  #$37,d0                         ; Retain bits 0-2, 3-4 if set
                or.b    d0,d1                           ; Mask in new value
                move.b  d1,SMPS_Track.AMSFMSPan(a5)     ; Store value
                move.b  #$B4,d0                         ; Command to set AMS/FMS/panning
                bra.w   WriteFMIorIIMain
```

Just **replace** the code above with this:

```m68k
; loc_72ACC:
                move.b  (a4)+,d1                        ; New AMS/FMS/panning value
                tst.b   SMPS_Track.VoiceControl(a5)     ; Is this a PSG track?
                bmi.s   locret_72AEA                    ; Return if yes
                moveq   #$37, d0
                and.b   SMPS_Track.AMSFMSPan(a5),d0     ; Get current AMS/FMS
                or.b    d0,d1                           ; Add new panning bits
                move.b  d1,SMPS_Track.AMSFMSPan(a5)     ; Store value
                tst.b   SMPS_RAM.f_updating_dac(a6)     ; Are we updating DAC?
                bmi.s   .updateDACPanning               ; If yes, branch
                moveq   #$FFFFFFB4,d0                   ; Command to set AMS/FMS/panning
                bra.w   WriteFMIorIIMain

        .updateDACPanning:
                ; Send to DAC panning Mega PCM instead of updating it directly.
                ; Mega PCM needs to track panning on its own to restore it in
                ; normal sample is interrupted by an SFX sample
                MPCM_stopZ80
                and.b   #$C0, d1
                move.b  d1, MPCM_Z80_RAM+Z_MPCM_PanInput
                MPCM_startZ80
                rts
```

If your disassembly is **pre-June 2024**, you should rename some of the variables in the example above:
- `SMPS_Track.VoiceControl(a5)` (new) -> `TrackVoiceControl(a5)` (old)
- `SMPS_Track.AMSFMSPan(a5)` (new) -> `TrackAMSFMSPan(a5)` (old)
- `SMPS_RAM.f_updating_dac(a6)` (new) -> `f_updating_dac(a6)` (old)

As you can see, this updated code merely extends the original. In fact, we've added a few new lines after the line `move.b d1,TrackAMSFMSPan(a5)` and a few micro-optimization (saves a few CPU cycles).

Finally, let's reset panning and other DAC settings when BGM is initialized. Find `.bgm_fmdone:` and just **below** this line, add the following:

```m68k
                MPCM_stopZ80
                move.b  #0, MPCM_Z80_RAM+Z_MPCM_VolumeInput     ; set DAC volume to maximum
                move.b  #$C0, MPCM_Z80_RAM+Z_MPCM_PanInput      ; set panning to LR
                MPCM_startZ80
```

## Implement DAC pause/unpause

In `s1.sounddriver.asm` search for `PauseMusic:`, you should see the following code:

```m68k
; loc_71E50:
PauseMusic:
                bmi.s   .unpausemusic   ; Branch if music is being unpaused
                cmpi.b  #2,SMPS_RAM.f_pausemusic(a6)
                beq.w   .unpausedallfm
                move.b  #2,SMPS_RAM.f_pausemusic(a6)
                moveq   #2,d3
                move.b  #$B4,d0         ; Command to set AMS/FMS/panning
                moveq   #0,d1           ; No panning, AMS or FMS
; loc_71E6A:
.killpanloop:
                jsr     WriteFMI(pc)
                jsr     WriteFMII(pc)
                addq.b  #1,d0
                dbf     d3,.killpanloop
```

**Replace** the snippet above with this:

```m68k
; loc_71E50:
PauseMusic:
                bmi.s   .unpausemusic                   ; Branch if music is being unpaused
                cmpi.b  #2,SMPS_RAM.f_pausemusic(a6)
                beq.w   .done
                move.b  #2,SMPS_RAM.f_pausemusic(a6)
                moveq   #$FFFFFFB4,d0                   ; Command to set AMS/FMS/panning
                moveq   #0,d1                           ; No panning, AMS or FMS
                jsr     WriteFMI(pc)                    ; FM1
                jsr     WriteFMII(pc)                   ; FM4
                addq.b  #1,d0
                jsr     WriteFMI(pc)                    ; FM2
                jsr     WriteFMII(pc)                   ; FM5
                addq.b  #1,d0
                jsr     WriteFMI(pc)                    ; FM3
                tst.b   SMPS_RAM.v_music_fm6_track(a6)  ; is FM6 playing?
                bpl.s   .notFM6                         ; if not, don't touch it, because FM6 is owned by Mega PCM then
                jsr     WriteFMII(pc)                   ; FM6
        .notFM6:
```

If your disassembly is **pre-June 2024**, you should rename some of the variables in the example above:
- `SMPS_RAM.f_pausemusic(a6)` (new) -> `f_pausemusic(a6)` (old)
- `SMPS_RAM.v_music_fm6_track(a6)` (new) -> `v_music_fm6_track(a6)` (old)

With this change, SMPS will no longer take overship of DAC panning, since Mega PCM 2 should completely own the channel.

Next, scroll below until you find this line:

```m68k
                jsr     PSGSilenceAll(pc)
```

Just **above** it, insert the following:

```m68k
                MPCM_stopZ80
                move.b  #Z_MPCM_COMMAND_PAUSE, MPCM_Z80_RAM+Z_MPCM_CommandInput ; pause DAC
                MPCM_startZ80
```

This is our new way of pausing the DAC channel. Instead of just silencing it (and keep the sample playing) we instruct Mega PCM 2 to pause the playback.

Now, scroll down into `.unpausemusic:` section until you see this:

```m68k
                lea     SMPS_RAM.v_music_fmdac_tracks(a6),a5
                moveq   #SMPS_MUSIC_FM_DAC_TRACK_COUNT-1,d4     ; 6 FM + 1 DAC tracks
```

In older versions of the disassembly this setion may look like this:

```m68k
                lea     v_music_fmdac_tracks(a6),a5
                moveq   #((v_music_fmdac_tracks_end-v_music_fmdac_tracks)/TrackSz)-1,d4 ; 6 FM + 1 DAC tracks
```

**Replace** it with this:

```m68k
                lea     SMPS_RAM.v_music_fm_tracks(a6),a5
                moveq   #6-1,d4                         ; 6 FM
```

If your disassembly is **pre-June 2024**, replace `SMPS_RAM.v_music_fm_tracks(a6)` with just `v_music_fm_tracks(a6)`.

Again, Mega PCM 2 owns DAC channel now and SMPS should touch it to avoid bugs and synchronization issues.

Finally, find `.unpausedallfm:` line below. Right above it (and before `bra.w   DoStartZ80`) **insert this**:

```m68k
.unpausedallfm: ; <-- Make sure new code goes below this line
                MPCM_stopZ80
                move.b  #0, MPCM_Z80_RAM+Z_MPCM_CommandInput ; unpause DAC
                MPCM_startZ80

.done:
```

**How to test:**

- Code should compile after your changes.
- You can try to play a really long sample (via `MegaPCM_PlaySample` or by modifying SMPS music to reference it in DAC channel); you should be able to pause/unpause it properly in-game.

## Don't stop DAC and SFX on fading

By default, SMPS stops DAC and disables all SFX during fade in/out sequences. Let's do a quality of life improvement and fix this. We won't suppress SFX and stop DAC only when fade out is complete. This prepares the ground to implement actual DAC fading in the next section.

In `s1.sounddriver.asm` find `Sound_PlaySFX:` and **remove** the following lines below it:

```diff
-               tst.b   SMPS_RAM.v_fadeout_counter(a6)  ; Is music being faded out?
-               bne.w   .clear_sndprio                  ; Exit if it is
-               tst.b   SMPS_RAM.f_fadein_flag(a6)      ; Is music being faded in?
-               bne.w   .clear_sndprio                  ; Exit if it is
```

Next, find `Sound_PlaySpecial:` and, similarly, remove these lines:

```diff
-               tst.b   SMPS_RAM.v_fadeout_counter(a6)  ; Is music being faded out?
-               bne.w   .locret                         ; Exit if it is
-               tst.b   SMPS_RAM.f_fadein_flag(a6)      ; Is music being faded in?
-               bne.w   .locret                         ; Exit if it is
```

This will allow SFX and special SFX to play during fade in and out.

Next, find `FadeOutMusic:` and somewhere below it, remove the following line:
```diff
-               clr.b   SMPS_RAM.v_music_dac_track.PlaybackControl(a6)  ; Stop DAC track
```

Now, find `StopAllSound:` and remove the following lines right below it (don't remove the label itself):
```diff
 StopAllSound:
-               moveq   #$2B,d0         ; Enable/disable DAC
-               move.b  #$80,d1         ; Enable DAC
-               jsr     WriteFMI(pc)
```

Since Mega PCM 2 now "owns" the DAC channel, we don't need this to avoid issues. Mega PCM will enable and disable DAC automatically for you.

Finally, scroll down until you see these lines:

```m68k
                move.b  #$80,SMPS_RAM.v_sound_id(a6)    ; set music to $80 (silence)
                jsr     FMSilenceAll(pc)
                bra.w   PSGSilenceAll
```

Right **above** them, add this:

```m68k
                MPCM_stopZ80
                move.b  #Z_MPCM_COMMAND_STOP, MPCM_Z80_RAM+Z_MPCM_CommandInput ; stop DAC playback
                MPCM_startZ80
```

This is a clean and proper way to stop DAC now, not forcefully disabling the channel.

**How to test:**

- Code should compile after your changes.
- The easiest way is to get a 1-up and make sure you are able to hear both DAC and SFX when it fades in back to level's BGM. Don't worry, we will address DAC fade in/out effects in the next section.

## Implement DAC fade in and fade out

It's finally time for the start of the show! Smooth DAC fade in/out, which is all about increasing/decreasing DAC volume gradually.

In `s1.sounddriver.asm`, locate the following code (search for `.DoFadeOut:`):

```m68k
; sub_72504:
DoFadeOut:
                move.b  SMPS_RAM.v_fadeout_delay(a6),d0 ; Has fadeout delay expired?
                beq.s   .continuefade                   ; Branch if yes
                subq.b  #1,SMPS_RAM.v_fadeout_delay(a6)
                rts     
; ===========================================================================
; loc_72510:
.continuefade:
                subq.b  #1,SMPS_RAM.v_fadeout_counter(a6)       ; Update fade counter
                beq.w   StopAllSound                            ; Branch if fade is done
                move.b  #3,SMPS_RAM.v_fadeout_delay(a6)         ; Reset fade delay
```

Right **below** this snippet, insert the following code:

```m68k
                ; Fade out DAC
                lea     SMPS_RAM.v_music_dac_track(a6),a5
                tst.b   (a5)                                    ; is DAC playing?
                bpl.s   .dac_done                               ; if yes, branch
                addq.b  #4, SMPS_Track.Volume(a5)               ; Increase volume attenuation
                bpl.s   .dac_update_volume
                and.b   #$7F, (a5)                              ; Stop channel
                bra.s   .dac_done

.dac_update_volume:
                move.b  SMPS_Track.Volume(a5), d0
                lsr.b   #3, d0
                MPCM_stopZ80
                move.b  d0, MPCM_Z80_RAM+Z_MPCM_VolumeInput
                MPCM_startZ80
.dac_done:
```

As usual, if your disassembly is **pre-June 2024**, you may need to change some variable names:
- `SMPS_RAM.v_music_dac_track(a6)` (new) -> `v_music_dac_track(a6)` (old)
- `SMPS_Track.Volume(a5)` (new) -> `TrackVolume(a5)` (old)

Now, let's give "fade in" sequence the same treatment. Locate the following code below `DoFadeIn:`:

```m68k
; sub_7267C:
DoFadeIn:
                tst.b   SMPS_RAM.v_fadein_delay(a6)     ; Has fadein delay expired?
                beq.s   .continuefade                   ; Branch if yes
                subq.b  #1,SMPS_RAM.v_fadein_delay(a6)
                rts     
; ===========================================================================
; loc_72688:
.continuefade:
                tst.b   SMPS_RAM.v_fadein_counter(a6)           ; Is fade done?
                beq.s   .fadedone                               ; Branch if yes
                subq.b  #1,SMPS_RAM.v_fadein_counter(a6)        ; Update fade counter
                move.b  #2,SMPS_RAM.v_fadein_delay(a6)          ; Reset fade delay
```

Right **below** it, insert the following code:

```m68k
                ; Fade in DAC
                lea     SMPS_RAM.v_music_dac_track(a6),a5
                tst.b   (a5)                                    ; is DAC playing?
                bpl.s   .dac_done                               ; if yes, branch
                subq.b  #4, SMPS_Track.Volume(a5)               ; Increase volume attenuation
                bcc.s   .dac_update_volume
                move.b  #0, SMPS_Track.Volume(a5)
                bra.s   .dac_done

.dac_update_volume:
                move.b  SMPS_Track.Volume(a5), d0
                lsr.b   #3, d0
                MPCM_stopZ80
                move.b  d0, MPCM_Z80_RAM+Z_MPCM_VolumeInput
                MPCM_startZ80
.dac_done:
```

Again, if your disassembly is **pre-June 2024**, you need to rename the following variables in the code above:
- `SMPS_RAM.v_music_dac_track(a6)` (new) -> `v_music_dac_track(a6)` (old)
- `SMPS_Track.Volume(a5)` (new) -> `TrackVolume(a5)` (old)

If you try to build now, you'll most likely get "jump distance too big" error on this line under `.continuefade:`:

```m68k
                beq.s   .fadedone                               ; Branch if yes
```

This is because new code we've added made this location too far for a short branch. Replace `beq.s` with `beq.w` to fix this.

At last, we need to fix initialization of "fade in to previous" sequence, which still forcefully disables DAC channel. Find `cfFadeInToPrevious:`, locate and remove the following line somewhere below it:

```diff
-               bset    #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)       ; Set 'SFX overriding' bit
```

In older disassemblies, this line may've looked like this:
```diff
-               bset    #2,v_music_dac_track+TrackPlaybackControl(a6)    ; Set 'SFX overriding' bit
```

Then right **below** the line you've just removed, insert the following code:
```m68k
                tst.b   SMPS_RAM.v_music_dac_track(a6)                  ; is DAC playing?
                bpl.s   .dacdone                                        ; if not, branch
                move.b  #$7F, SMPS_RAM.v_music_dac_track.Volume(a6)     ; set initial DAC volume
.dacdone:
```

If you're using an older disassembly, replace some variables as follows:
- `SMPS_RAM.v_music_dac_track(a6)` (new) -> `v_music_dac_track(a6)` (old);
- `SMPS_RAM.v_music_dac_track.Volume(a6)` (new) -> `v_music_dac_track+TrackVolume(a6)` (old)

Finally, find `.fadedone:` and remove a similar line just below it:

```diff
; loc_726D6:
.fadedone:
-               bclr    #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)       ; Clear 'SFX overriding' bit
```

Again, in older disassembly, it may look like this:
```diff
; loc_726D6:
.fadedone:
-               bclr    #2,v_music_dac_track+TrackPlaybackControl(a6)       ; Clear 'SFX overriding' bit
```

**How to test:**

- Code should compile after your changes.
- To easily test fade in: Open Level Select, play sound $81 (GHZ), then play sound $88 (1-up); when 1-up jingle finishes, you should hear DAC fade in as GHZ music resumes.
- For testing fade out: Start any level from level select while other GHZ is playing; the sequence is shorter (full fade out won't happen as new BGM starts to play early), but you should notice DAC fading out instead of cutting abruptly.
