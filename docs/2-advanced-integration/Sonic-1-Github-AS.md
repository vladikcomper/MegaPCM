
# Extended Mega PCM 2 integration in Sonic 1 Github Disassembly (AS)

In the installation guide we only achieved the most basic integration between SMPS and Mega PCM 2. To take advantage of Mega PCM 2's features like DAC fade in/out and pause/unpause and fix a few potential issues, further SMPS modifications are necessary.

> [!NOTE]
> 
> This guide was written based on the reference S1 SMPS integrations from `examples/` directory. You can see [`examples/s1-smps-integration/s1.sounddriver.asm`](../../examples/s1-smps-integration/s1.sounddriver.asm) as a working example.

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

**Replace** the snipped above with this:

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

## Implement DAC fade in and fade out

_Work in progress_
