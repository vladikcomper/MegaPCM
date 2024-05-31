
# Extended Mega PCM 2 integration in Sonic 1 Github Disassembly (AS)

> [!WARNING]
>
> This guide is work-in-progress, some sections are pending (DAC fade in/fade out and a few fixes). Please see S1 SMPS integration from `examples/` directory for a complete implementation example.

In the installation guide we only achieved the most basic integration between SMPS and Mega PCM 2. To take advantage of Mega PCM 2's features like DAC fade in/out and pause/unpause and fix a few potential issues, further SMPS modifications are necessary.

> [!NOTE]
> 
> This guide was written based on the reference S1 SMPS integration from `examples/` directory. You can see [`examples/s1-smps-integration/s1.sounddriver.asm`](../../examples/s1-smps-integration/s1.sounddriver.asm) as a working example.

## Implement DAC pause/unpause

In `s1.sounddriver.asm` search for `PauseMusic:`, you should see the following code:

```m68k
; loc_71E50:
PauseMusic:
                bmi.s   .unpausemusic           ; Branch if music is being unpaused
                cmpi.b  #2,f_pausemusic(a6)
                beq.w   .unpausedallfm
                move.b  #2,f_pausemusic(a6)
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
                bmi.s   .unpausemusic           ; Branch if music is being unpaused
                cmpi.b  #2,f_pausemusic(a6)
                beq.w   .done
                move.b  #2,f_pausemusic(a6)
                moveq   #$FFFFFFB4,d0           ; Command to set AMS/FMS/panning
                moveq   #0,d1                   ; No panning, AMS or FMS
                jsr     WriteFMI(pc)            ; FM1
                jsr     WriteFMII(pc)           ; FM4
                addq.b  #1,d0
                jsr     WriteFMI(pc)            ; FM2
                jsr     WriteFMII(pc)           ; FM5
                addq.b  #1,d0
                jsr     WriteFMI(pc)            ; FM3
                tst.b   v_music_fm6_track(a6)   ; is FM6 playing?
                bpl.s   .notFM6                 ; if not, don't touch it, because FM6 is owned by Mega PCM then
                jsr     WriteFMII(pc)           ; FM6
        .notFM6:
```

With this change, SMPS will no longer take overship of DAC panning, since Mega PCM 2 should completely own the channel.

Next, scroll below until you find this line:

```m68k
                jsr     PSGSilenceAll(pc)
```

Just **above** it, insert the following:

```m68k
                MPCM_stopZ80
                move.b  #Z_MPCM_COMMAND_PAUSE, z80_ram+Z_MPCM_CommandInput ; pause DAC
                MPCM_startZ80
```

This is our new way of pausing the DAC channel. Instead of just silencing it (and keep the sample playing) we instruct Mega PCM 2 to pause the playback.

Now, scroll down into `.unpausemusic:` section until you see this:

```m68k
                lea     v_music_fmdac_tracks(a6),a5
                moveq   #((v_music_fmdac_tracks_end-v_music_fmdac_tracks)/TrackSz)-1,d4 ; 6 FM + 1 DAC tracks
```

**Replace** it with this:

```m68k
                lea     v_music_fm_tracks(a6),a5
                moveq   #6-1,d4                         ; 6 FM
```

Again, Mega PCM 2 owns DAC channel now and SMPS should touch it to avoid bugs and synchronization issues.

Finally, find `.unpausedallfm:` line below. Right above it (and before `bra.w   DoStartZ80`) **insert this**:

```m68k
                MPCM_stopZ80
                move.b  #0, z80_ram+Z_MPCM_CommandInput ; unpause DAC
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
-               tst.b   v_fadeout_counter(a6)   ; Is music being faded out?
-               bne.w   .clear_sndprio          ; Exit if it is
-               tst.b   f_fadein_flag(a6)       ; Is music being faded in?
-               bne.w   .clear_sndprio          ; Exit if it is
```

Next, find `Sound_PlaySpecial:` and, similarly, remove these lines:

```diff
-               tst.b   v_fadeout_counter(a6)   ; Is music being faded out?
-               bne.w   .locret                 ; Exit if it is
-               tst.b   f_fadein_flag(a6)       ; Is music being faded in?
-               bne.w   .locret                 ; Exit if it is
```

This will allow SFX and special SFX to play during fade in and out.

Next, find `FadeOutMusic:` and somewhere below it, remove the following line:
```diff
-               clr.b   v_music_dac_track+TrackPlaybackControl(a6)      ; Stop DAC track
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
                move.b  #$80,v_sound_id(a6)     ; set music to $80 (silence)
                jsr     FMSilenceAll(pc)
                bra.w   PSGSilenceAll
```

Right **above** them, add this:

```m68k
                MPCM_stopZ80
                move.b  #Z_MPCM_COMMAND_STOP, Z80_RAM+Z_MPCM_CommandInput ; stop DAC playback
                MPCM_startZ80
```

This is a clean and proper way to stop DAC now, not forcefully disabling the channel.

**How to test:**

- Code should compile after your changes.
- The easiest way is to get a 1-up and make sure you are able to hear both DAC and SFX when it fades in back to level's BGM. Don't worry, we will address DAC fade in/out effects in the next section.

## Implement DAC fade in and fade out

_Work in progress_
