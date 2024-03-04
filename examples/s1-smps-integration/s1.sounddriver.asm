
; ---------------------------------------------------------------------------
; Vladikcomper:
; This is native Sonic 1 sound driver from Github disassembly with a few
; modifications to be used with Mega PCM 2:
; - Replaced ASM versions and BGM and SFX with binary files for simplicity;
; - Greatly reduced number of Z80 stops;
; - Fully support Mega PCM 2 features: DAC fade in and fade out, panning;
; - Don't cut SFX when playing new BGM or during fade in/out;
; - Fixed numerous bugs.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Modified SMPS 68k Type 1b sound driver
; The source code to a similar version of the driver can be found here:
; https://hiddenpalace.org/News/Sega_of_Japan_Sound_Documents_and_Source_Code
; ---------------------------------------------------------------------------
; Go_SoundTypes:
Go_SoundPriorities:	dc.l SoundPriorities
; Go_SoundD0:
Go_SpecSoundIndex:	dc.l SpecSoundIndex
Go_MusicIndex:		dc.l MusicIndex
Go_SoundIndex:		dc.l SoundIndex
; off_719A0:
Go_SpeedUpIndex:	dc.l SpeedUpIndex
Go_PSGIndex:		dc.l PSG_Index
; ---------------------------------------------------------------------------
; PSG instruments used in music
; ---------------------------------------------------------------------------
PSG_Index:
		dc.l PSG1, PSG2, PSG3
		dc.l PSG4, PSG5, PSG6
		dc.l PSG7, PSG8, PSG9
PSG1:		incbin	"s1-smps-integration/psg/psg1.bin"
PSG2:		incbin	"s1-smps-integration/psg/psg2.bin"
PSG3:		incbin	"s1-smps-integration/psg/psg3.bin"
PSG4:		incbin	"s1-smps-integration/psg/psg4.bin"
PSG6:		incbin	"s1-smps-integration/psg/psg6.bin"
PSG5:		incbin	"s1-smps-integration/psg/psg5.bin"
PSG7:		incbin	"s1-smps-integration/psg/psg7.bin"
PSG8:		incbin	"s1-smps-integration/psg/psg8.bin"
PSG9:		incbin	"s1-smps-integration/psg/psg9.bin"
; ---------------------------------------------------------------------------
; New tempos for songs during speed shoes
; ---------------------------------------------------------------------------
; DANGER! several songs will use the first few bytes of MusicIndex as their main
; tempos while speed shoes are active. If you don't want that, you should add
; their "correct" sped-up main tempos to the list.
; byte_71A94:
SpeedUpIndex:
		dc.b 7		; GHZ
		dc.b $72	; LZ
		dc.b $73	; MZ
		dc.b $26	; SLZ
		dc.b $15	; SYZ
		dc.b 8		; SBZ
		dc.b $FF	; Invincibility
		dc.b 5		; Extra Life
		;dc.b ?		; Special Stage
		;dc.b ?		; Title Screen
		;dc.b ?		; Ending
		;dc.b ?		; Boss
		;dc.b ?		; FZ
		;dc.b ?		; Sonic Got Through
		;dc.b ?		; Game Over
		;dc.b ?		; Continue Screen
		;dc.b ?		; Credits
		;dc.b ?		; Drowning
		;dc.b ?		; Get Emerald

; ---------------------------------------------------------------------------
; Music	Pointers
; ---------------------------------------------------------------------------
MusicIndex:
ptr_mus81:	dc.l Music81
ptr_mus82:	dc.l Music82
ptr_mus83:	dc.l Music83
ptr_mus84:	dc.l Music84
ptr_mus85:	dc.l Music85
ptr_mus86:	dc.l Music86
ptr_mus87:	dc.l Music87
ptr_mus88:	dc.l Music88
ptr_mus89:	dc.l Music89
ptr_mus8A:	dc.l Music8A
ptr_mus8B:	dc.l Music8B
ptr_mus8C:	dc.l Music8C
ptr_mus8D:	dc.l Music8D
ptr_mus8E:	dc.l Music8E
ptr_mus8F:	dc.l Music8F
ptr_mus90:	dc.l Music90
ptr_mus91:	dc.l Music91
ptr_mus92:	dc.l Music92
ptr_mus93:	dc.l Music93
ptr_musend
; ---------------------------------------------------------------------------
; Priority of sound. New music or SFX must have a priority higher than or equal
; to what is stored in v_sndprio or it won't play. If bit 7 of new priority is
; set ($80 and up), the new music or SFX will not set its priority -- meaning
; any music or SFX can override it (as long as it can override whatever was
; playing before). Usually, SFX will only override SFX, special SFX ($D0-$DF)
; will only override special SFX and music will only override music.
; ---------------------------------------------------------------------------
; SoundTypes:
SoundPriorities:
		dc.b     $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90	; $81
		dc.b $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90	; $90
		dc.b $80,$70,$70,$70,$70,$70,$70,$70,$70,$70,$68,$70,$70,$70,$60,$70	; $A0
		dc.b $70,$60,$70,$60,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$7F	; $B0
		dc.b $60,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70	; $C0
		dc.b $80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80	; $D0
		dc.b $90,$90,$90,$90,$90                                            	; $E0

; ---------------------------------------------------------------------------
; Subroutine to update music more than once per frame
; (Called by horizontal & vert. interrupts)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71B4C:
UpdateMusic:
		lea	(v_snddriver_ram&$FFFFFF).l,a6
		clr.b	f_voice_selector(a6)
		tst.b	f_pausemusic(a6)		; is music paused?
		bne.w	PauseMusic			; if yes, branch
		subq.b	#1,v_main_tempo_timeout(a6)	; Has main tempo timer expired?
		bne.s	.skipdelay
		jsr	TempoWait(pc)
; loc_71B9E:
.skipdelay:
		move.b	v_fadeout_counter(a6),d0
		beq.s	.skipfadeout
		jsr	DoFadeOut(pc)
; loc_71BA8:
.skipfadeout:
		tst.b	f_fadein_flag(a6)
		beq.s	.skipfadein
		jsr	DoFadeIn(pc)
; loc_71BB2:
.skipfadein:
	if FixBugs
		moveq	#0,d0
		or.b	v_soundqueue2(a6),d0
		or.w	v_soundqueue0(a6),d0
	else
		; DANGER! The following line only checks v_soundqueue0 and v_soundqueue1, breaking v_soundqueue2.
		tst.w	v_soundqueue0(a6)	; is a music or sound queued for playing?
	endif
		beq.s	.nosndinput		; if not, branch
		jsr	CycleSoundQueue(pc)
; loc_71BBC:
.nosndinput:
		cmpi.b	#$80,v_sound_id(a6)	; is song queue set for silence (empty)?
		beq.s	.nonewsound		; If yes, branch
		jsr	PlaySoundID(pc)
; loc_71BC8:
.nonewsound:
		lea	v_music_dac_track(a6),a5
		tst.b	TrackPlaybackControl(a5) ; Is DAC track playing?
		bpl.s	.dacdone		; Branch if not
		jsr	DACUpdateTrack(pc)
; loc_71BD4:
.dacdone:
		clr.b	f_updating_dac(a6)
		moveq	#((v_music_fm_tracks_end-v_music_fm_tracks)/TrackSz)-1,d7	; 6 FM tracks
; loc_71BDA:
.bgmfmloop:
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.bgmfmnext		; Branch if not
		jsr	FMUpdateTrack(pc)
; loc_71BE6:
.bgmfmnext:
		dbf	d7,.bgmfmloop

		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d7 ; 3 PSG tracks
; loc_71BEC:
.bgmpsgloop:
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.bgmpsgnext		; Branch if not
		jsr	PSGUpdateTrack(pc)
; loc_71BF8:
.bgmpsgnext:
		dbf	d7,.bgmpsgloop

		move.b	#$80,f_voice_selector(a6)			; Now at SFX tracks
		moveq	#((v_sfx_fm_tracks_end-v_sfx_fm_tracks)/TrackSz)-1,d7	; 3 FM tracks (SFX)
; loc_71C04:
.sfxfmloop:
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.sfxfmnext		; Branch if not
		jsr	FMUpdateTrack(pc)
; loc_71C10:
.sfxfmnext:
		dbf	d7,.sfxfmloop

		moveq	#((v_sfx_psg_tracks_end-v_sfx_psg_tracks)/TrackSz)-1,d7 ; 3 PSG tracks (SFX)
; loc_71C16:
.sfxpsgloop:
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.sfxpsgnext		; Branch if not
		jsr	PSGUpdateTrack(pc)
; loc_71C22:
.sfxpsgnext:
		dbf	d7,.sfxpsgloop
		
		move.b	#$40,f_voice_selector(a6) ; Now at special SFX tracks
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.specfmdone		; Branch if not
		jsr	FMUpdateTrack(pc)
; loc_71C38:
.specfmdone:
		adda.w	#TrackSz,a5
		tst.b	TrackPlaybackControl(a5) ; Is track playing
		bpl.s	.specpsgdone		; Branch if not
		jsr	PSGUpdateTrack(pc)
; loc_71C44:
.specpsgdone:
		rts
; End of function UpdateMusic


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71C4E: UpdateDAC:
DACUpdateTrack:
		subq.b	#1,TrackDurationTimeout(a5)	; Has DAC sample timeout expired?
		bne .locret				; Return if not ### .s
		move.b	#$80,f_updating_dac(a6)		; Set flag to indicate this is the DAC
;DACDoNext:
		movea.l	TrackDataPointer(a5),a4	; DAC track data pointer
; loc_71C5E:
.sampleloop:
		moveq	#0,d5
		move.b	(a4)+,d5	; Get next SMPS unit
		cmpi.b	#$E0,d5		; Is it a coord. flag?
		blo.s	.notcoord	; Branch if not
		jsr	CoordFlag(pc)
		bra.s	.sampleloop
; ===========================================================================
; loc_71C6E:
.notcoord:
		tst.b	d5			; Is it a sample?
		bpl.s	.gotduration		; Branch if not (duration)
		move.b	d5,TrackSavedDAC(a5)	; Store new sample
		move.b	(a4)+,d5		; Get another byte
		bpl.s	.gotduration		; Branch if it is a duration
		subq.w	#1,a4			; Put byte back
		move.b	TrackSavedDuration(a5),TrackDurationTimeout(a5) ; Use last duration
		bra.s	.gotsampleduration
; ===========================================================================
; loc_71C84:
.gotduration:
		jsr	SetDuration(pc)
; loc_71C88:
.gotsampleduration:
		move.l	a4,TrackDataPointer(a5) ; Save pointer
		btst	#2,TrackPlaybackControl(a5)			; Is track being overridden?
		bne.s	.locret			; Return if yes
		moveq	#0,d0
		move.b	TrackSavedDAC(a5),d0	; Get sample
		cmpi.b	#$80,d0			; Is it a rest?
		beq.s	.locret			; Return if yes
		MPCM_stopZ80
		move.b	d0, Z80_RAM+Z_MPCM_CommandInput	; send DAC sample to Mega PCM
		MPCM_startZ80
; locret_71CAA:
.locret:
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71CCA:
FMUpdateTrack:
		subq.b	#1,TrackDurationTimeout(a5)	; Update duration timeout
		bne.s	.notegoing			; Branch if it hasn't expired
		bclr	#4,TrackPlaybackControl(a5)	; Clear 'do not attack next note' bit
		jsr	FMDoNext(pc)
		jsr	FMPrepareNote(pc)
		bra.w	FMNoteOn
; ===========================================================================
; loc_71CE0:
.notegoing:
		jsr	NoteTimeoutUpdate(pc)
		jsr	DoModulation(pc)
		bra.w	FMUpdateFreq
; End of function FMUpdateTrack


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71CEC:
FMDoNext:
		movea.l	TrackDataPointer(a5),a4		; Track data pointer
		bclr	#1,TrackPlaybackControl(a5)	; Clear 'track at rest' bit
; loc_71CF4:
.noteloop:
		moveq	#0,d5
		move.b	(a4)+,d5	; Get byte from track
		cmpi.b	#$E0,d5		; Is this a coord. flag?
		blo.s	.gotnote	; Branch if not
		jsr	CoordFlag(pc)
		bra.s	.noteloop
; ===========================================================================
; loc_71D04:
.gotnote:
		jsr	FMNoteOff(pc)
		tst.b	d5		; Is this a note?
		bpl.s	.gotduration	; Branch if not
		jsr	FMSetFreq(pc)
		move.b	(a4)+,d5	; Get another byte
		bpl.s	.gotduration	; Branch if it is a duration
		subq.w	#1,a4		; Otherwise, put it back
		bra.w	FinishTrackUpdate
; ===========================================================================
; loc_71D1A:
.gotduration:
		jsr	SetDuration(pc)
		bra.w	FinishTrackUpdate
; End of function FMDoNext


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71D22:
FMSetFreq:
		subi.b	#$80,d5			; Make it a zero-based index
		beq.s	TrackSetRest
		add.b	TrackTranspose(a5),d5	; Add track transposition
		andi.w	#$7F,d5			; Clear high byte and sign bit
		lsl.w	#1,d5
		lea	FMFrequencies(pc),a0
		move.w	(a0,d5.w),d6
		move.w	d6,TrackFreq(a5)	; Store new frequency
		rts	
; End of function FMSetFreq


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71D40:
SetDuration:
		move.b	d5,d0
		move.b	TrackTempoDivider(a5),d1	; Get dividing timing
; loc_71D46:
.multloop:
		subq.b	#1,d1
		beq.s	.donemult
		add.b	d5,d0
		bra.s	.multloop
; ===========================================================================
; loc_71D4E:
.donemult:
		move.b	d0,TrackSavedDuration(a5)	; Save duration
		move.b	d0,TrackDurationTimeout(a5)	; Save duration timeout
		rts	
; End of function SetDuration

; ===========================================================================
; loc_71D58:
TrackSetRest:
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		clr.w	TrackFreq(a5)			; Clear frequency

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71D60:
FinishTrackUpdate:
		move.l	a4,TrackDataPointer(a5)	; Store new track position
		move.b	TrackSavedDuration(a5),TrackDurationTimeout(a5)	; Reset note timeout
		btst	#4,TrackPlaybackControl(a5)	; Is track set to not attack note?
		bne.s	.locret				; If so, branch
		move.b	TrackNoteTimeoutMaster(a5),TrackNoteTimeout(a5)	; Reset note fill timeout
		clr.b	TrackVolEnvIndex(a5)		; Reset PSG volume envelope index (even on FM tracks...)
		btst	#3,TrackPlaybackControl(a5)	; Is modulation on?
		beq.s	.locret				; If not, return
		movea.l	TrackModulationPtr(a5),a0	; Modulation data pointer
		move.b	(a0)+,TrackModulationWait(a5)	; Reset wait
		move.b	(a0)+,TrackModulationSpeed(a5)	; Reset speed
		move.b	(a0)+,TrackModulationDelta(a5)	; Reset delta
		move.b	(a0)+,d0			; Get steps
		lsr.b	#1,d0				; Halve them
		move.b	d0,TrackModulationSteps(a5)	; Then store
		clr.w	TrackModulationVal(a5)		; Reset frequency change
; locret_71D9C:
.locret:
		rts	
; End of function FinishTrackUpdate


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71D9E: NoteFillUpdate
NoteTimeoutUpdate:
		tst.b	TrackNoteTimeout(a5)	; Is note fill on?
		beq.s	.locret
		subq.b	#1,TrackNoteTimeout(a5)	; Update note fill timeout
		bne.s	.locret				; Return if it hasn't expired
		bset	#1,TrackPlaybackControl(a5)	; Put track at rest
		tst.b	TrackVoiceControl(a5)		; Is this a PSG track?
		bmi.w	.psgnoteoff			; If yes, branch
		jsr	FMNoteOff(pc)
		addq.w	#4,sp				; Do not return to caller
		rts	
; ===========================================================================
; loc_71DBE:
.psgnoteoff:
		jsr	PSGNoteOff(pc)
		addq.w	#4,sp		; Do not return to caller
; locret_71DC4:
.locret:
		rts	
; End of function NoteTimeoutUpdate


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71DC6:
DoModulation:
		addq.w	#4,sp				; Do not return to caller (but see below)
		btst	#3,TrackPlaybackControl(a5)	; Is modulation active?
		beq.s	.locret				; Return if not
		tst.b	TrackModulationWait(a5)	; Has modulation wait expired?
		beq.s	.waitdone			; If yes, branch
		subq.b	#1,TrackModulationWait(a5)	; Update wait timeout
		rts	
; ===========================================================================
; loc_71DDA:
.waitdone:
		subq.b	#1,TrackModulationSpeed(a5)	; Update speed
		beq.s	.updatemodulation		; If it expired, want to update modulation
		rts	
; ===========================================================================
; loc_71DE2:
.updatemodulation:
		movea.l	TrackModulationPtr(a5),a0	; Get modulation data
		move.b	1(a0),TrackModulationSpeed(a5)	; Restore modulation speed
		tst.b	TrackModulationSteps(a5)	; Check number of steps
		bne.s	.calcfreq			; If nonzero, branch
		move.b	3(a0),TrackModulationSteps(a5)	; Restore from modulation data
		neg.b	TrackModulationDelta(a5)	; Negate modulation delta
		rts	
; ===========================================================================
; loc_71DFE:
.calcfreq:
		subq.b	#1,TrackModulationSteps(a5)	; Update modulation steps
		move.b	TrackModulationDelta(a5),d6	; Get modulation delta
		ext.w	d6
		add.w	TrackModulationVal(a5),d6	; Add cumulative modulation change
		move.w	d6,TrackModulationVal(a5)	; Store it
		add.w	TrackFreq(a5),d6		; Add note frequency to it
		subq.w	#4,sp		; In this case, we want to return to caller after all
; locret_71E16:
.locret:
		rts	
; End of function DoModulation


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_71E18:
FMPrepareNote:
		btst	#1,TrackPlaybackControl(a5)	; Is track resting?
		bne.s	locret_71E48			; Return if so
		move.w	TrackFreq(a5),d6		; Get current note frequency
		beq.s	FMSetRest			; Branch if zero
; loc_71E24:
FMUpdateFreq:
		move.b	TrackDetune(a5),d0 	; Get detune value
		ext.w	d0
		add.w	d0,d6				; Add note frequency
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	locret_71E48			; Return if so
		move.w	d6,d1
		lsr.w	#8,d1
		move.b	#$A4,d0			; Register for upper 6 bits of frequency
		jsr	WriteFMIorII(pc)
		move.b	d6,d1
		move.b	#$A0,d0			; Register for lower 8 bits of frequency
		jsr	WriteFMIorII(pc)	; (It would be better if this were a jmp)
; locret_71E48:
locret_71E48:
		rts	
; ===========================================================================
; loc_71E4A:
FMSetRest:
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		rts	
; End of function FMPrepareNote

; ===========================================================================
; loc_71E50:
PauseMusic:
		bmi.s	.unpausemusic		; Branch if music is being unpaused
		cmpi.b	#2,f_pausemusic(a6)
		beq.w	.unpausedallfm
		move.b	#2,f_pausemusic(a6)
		moveq	#$FFFFFFB4,d0		; Command to set AMS/FMS/panning
		moveq	#0,d1			; No panning, AMS or FMS
		jsr	WriteFMI(pc)		; FM1
		jsr	WriteFMII(pc)		; FM4
		addq.b	#1,d0
		jsr	WriteFMI(pc)		; FM2
		jsr	WriteFMII(pc)		; FM5
		addq.b	#1,d0
		jsr	WriteFMI(pc)		; FM3
		tst.b	v_music_fm6_track(a6)	; is FM6 playing?
		bpl.s	.notFM6			; if not, don't touch it, because FM6 is owned by Mega PCM then
		jsr	WriteFMII(pc)		; FM6
	.notFM6:

		; TODO: Set RR to maximum

		moveq	#2,d3
		moveq	#$28,d0		; Key on/off register
; loc_71E7C:
.noteoffloop:
		move.b	d3,d1		; FM1, FM2, FM3
		jsr	WriteFMI(pc)
		addq.b	#4,d1		; FM4, FM5, FM6
		jsr	WriteFMI(pc)
		dbf	d3,.noteoffloop

		MPCM_stopZ80
		move.b	#Z_MPCM_COMMAND_PAUSE, Z80_RAM+Z_MPCM_CommandInput ; pause DAC
		MPCM_startZ80

		jmp	PSGSilenceAll(pc)
; ===========================================================================
; loc_71E94:
.unpausemusic:
		clr.b	f_pausemusic(a6)
		moveq	#TrackSz,d3

		lea	v_music_fm_tracks(a6),a5
		moveq	#6-1,d4				; 6 FM
; loc_71EA0:
.bgmfmloop:
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.bgmfmnext			; Branch if not
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.bgmfmnext			; Branch if yes
		moveq	#$FFFFFFB4,d0			; Command to set AMS/FMS/panning
		move.b	TrackAMSFMSPan(a5),d1		; Get value from track RAM
		jsr	WriteFMIorII(pc)
; loc_71EB8:
.bgmfmnext:
		adda.w	d3,a5
		dbf	d4,.bgmfmloop

		lea	v_sfx_fm_tracks(a6),a5
		moveq	#3-1,d4				; 3 FM tracks (SFX)
; loc_71EC4:
.sfxfmloop:
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.sfxfmnext			; Branch if not
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.sfxfmnext			; Branch if yes
		move.b	#$B4,d0				; Command to set AMS/FMS/panning
		move.b	TrackAMSFMSPan(a5),d1		; Get value from track RAM
		jsr	WriteFMIorII(pc)
; loc_71EDC:
.sfxfmnext:
		adda.w	d3,a5
		dbf	d4,.sfxfmloop

		lea	v_spcsfx_track_ram(a6),a5
		btst	#7,TrackPlaybackControl(a5)	; Is track playing?
		beq.s	.unpausedallfm			; Branch if not
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.unpausedallfm			; Branch if yes
		move.b	#$B4,d0				; Command to set AMS/FMS/panning
		move.b	TrackAMSFMSPan(a5),d1		; Get value from track RAM
		jsr	WriteFMIorII(pc)
; loc_71EFE:
.unpausedallfm:
		MPCM_stopZ80
		move.b	#0, Z80_RAM+Z_MPCM_CommandInput	; unpause DAC
		MPCM_startZ80
		rts

; ---------------------------------------------------------------------------
; Subroutine to	play a sound or	music track
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Sound_Play:
CycleSoundQueue:
		movea.l	(Go_SoundPriorities).l,a0
		lea	v_soundqueue0(a6),a1	; load music track number
		move.b	v_sndprio(a6),d3	; Get priority of currently playing SFX
		moveq	#v_soundqueue_end-v_soundqueue_start-1,d4
; loc_71F12:
.inputloop:
		move.b	(a1),d0			; move track number to d0
		move.b	d0,d1
		clr.b	(a1)+			; Clear entry
		subi.b	#bgm__First,d0		; Make it into 0-based index
		bcs.s	.nextinput		; If negative (i.e., it was $80 or lower), branch
		cmpi.b	#$80,v_sound_id(a6)	; Is v_sound_id a $80 (silence/empty)?
		beq.s	.havesound		; If yes, branch
		move.b	d1,v_soundqueue0(a6)	; Put sound into v_soundqueue0
		bra.s	.nextinput
; ===========================================================================
; loc_71F2C:
.havesound:
		andi.w	#$7F,d0			; Clear high byte and sign bit
		move.b	(a0,d0.w),d2		; Get sound type
		cmp.b	d3,d2			; Is it a lower priority sound?
		blo.s	.nextinput		; Branch if yes
		move.b	d2,d3			; Store new priority
		move.b	d1,v_sound_id(a6)	; Queue sound for playing
; loc_71F3E:
.nextinput:
		dbf	d4,.inputloop

		tst.b	d3			; We don't want to change sound priority if it is negative
		bmi.s	.locret
		move.b	d3,v_sndprio(a6)	; Set new sound priority
; locret_71F4A:
.locret:
		rts	
; End of function CycleSoundQueue


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Sound_ChkValue:
PlaySoundID:
		moveq	#0,d7
		move.b	v_sound_id(a6),d7
		beq.w	StopAllSound
		bpl.s	.locret			; If >= 0, return (not a valid sound, bgm or command)
		move.b	#$80,v_sound_id(a6)	; reset	music flag
	if FixBugs
		cmpi.b	#bgm__Last,d7	; Is this music ($81-$93)?
	else
		; DANGER! Music ends at $93, yet this checks until $9F; attempting to
		; play sounds $94-$9F will cause a crash!
		; See LevSel_NoCheat for more.
		cmpi.b	#bgm__Last+$C,d7	; Is this music ($81-$9F)?
	endif
		bls.w	Sound_PlayBGM		; Branch if yes
		cmpi.b	#sfx__First,d7		; Is this after music but before sfx? (redundant check)
		blo.w	.locret			; Return if yes
		cmpi.b	#sfx__Last,d7		; Is this sfx ($A0-$CF)?
		bls.w	Sound_PlaySFX		; Branch if yes
		cmpi.b	#spec__First,d7		; Is this after sfx but before special sfx? (redundant check)
		blo.w	.locret			; Return if yes
	if FixBugs
		cmpi.b	#spec__Last,d7		; Is this special sfx ($D0-$D0)?
		bls.w	Sound_PlaySpecial	; Branch if yes
		cmpi.b	#flg__First,d7		; Is this after special sfx but before $E0?
		blo.w	.locret			; Return if yes
	else
		; DANGER! Special SFXes end at $D0, yet this checks until $DF; attempting to
		; play sounds $D1-$DF will cause a crash!
		cmpi.b	#spec__Last+$10,d7	; Is this special sfx ($D0-$DF)?
		blo.w	Sound_PlaySpecial	; Branch if yes
	endif
		cmpi.b	#flg__Last,d7		; Is this $E0-$E4?
		bls.s	Sound_E0toE4		; Branch if yes
; locret_71F8C:
.locret:
		rts	
; ===========================================================================

Sound_E0toE4:
		subi.b	#flg__First,d7
		lsl.w	#2,d7
		jmp	Sound_ExIndex(pc,d7.w)
; ===========================================================================

Sound_ExIndex:
ptr_flgE0:	bra.w	FadeOutMusic		; $E0
ptr_flgE1:	bra.w	PlaySegaSound		; $E1
ptr_flgE2:	bra.w	SpeedUpMusic		; $E2
ptr_flgE3:	bra.w	SlowDownMusic		; $E3
ptr_flgE4:	bra.w	StopAllSound		; $E4
ptr_flgend
; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound (disabled)
; ---------------------------------------------------------------------------
; Sound_E1: PlaySega:
PlaySegaSound:
		rts	
; ===========================================================================
; ---------------------------------------------------------------------------
; Play music track $81-$9F
; ---------------------------------------------------------------------------
; Sound_81to9F:
Sound_PlayBGM:
		cmpi.b	#bgm_ExtraLife,d7	; is the "extra life" music to be played?
		bne.s	.bgmnot1up		; if not, branch
		tst.b	f_1up_playing(a6)	; Is a 1-up music playing?
		bne.w	.locdblret		; if yes, branch
		lea	v_music_track_ram(a6),a5
		moveq	#((v_music_track_ram_end-v_music_track_ram)/TrackSz)-1,d0	; 1 DAC + 6 FM + 3 PSG tracks
; loc_71FE6:
.clearsfxloop:
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX is overriding' bit
		adda.w	#TrackSz,a5
		dbf	d0,.clearsfxloop

		lea	v_sfx_track_ram(a6),a5
		moveq	#((v_sfx_track_ram_end-v_sfx_track_ram)/TrackSz)-1,d0	; 3 FM + 3 PSG tracks (SFX)
; loc_71FF8:
.cleartrackplayloop:
		bclr	#7,TrackPlaybackControl(a5)	; Clear 'track is playing' bit
		adda.w	#TrackSz,a5
		dbf	d0,.cleartrackplayloop

		clr.b	v_sndprio(a6)		; Clear priority
		movea.l	a6,a0
		lea	v_1up_ram_copy(a6),a1
		move.w	#((v_music_track_ram_end-v_startofvariables)/4)-1,d0	; Backup $220 bytes: all variables and music track data
; loc_72012:
.backupramloop:
		move.l	(a0)+,(a1)+
		dbf	d0,.backupramloop

		move.b	#$80,f_1up_playing(a6)
		clr.b	v_sndprio(a6)		; Clear priority again (?)
		bra.s	.bgm_loadMusic
; ===========================================================================
; loc_72024:
.bgmnot1up:
		clr.b	f_1up_playing(a6)
		clr.b	v_fadein_counter(a6)
; loc_7202C:
.bgm_loadMusic:
		jsr	InitMusicPlayback(pc)
		movea.l	(Go_SpeedUpIndex).l,a4
		subi.b	#bgm__First,d7
		move.b	(a4,d7.w),v_speeduptempo(a6)
		movea.l	(Go_MusicIndex).l,a4
		lsl.w	#2,d7
		movea.l	(a4,d7.w),a4		; a4 now points to (uncompressed) song data
		moveq	#0,d0
		move.w	(a4),d0			; load voice pointer
		add.l	a4,d0			; It is a relative pointer
		move.l	d0,v_voice_ptr(a6)
		move.b	5(a4),d0		; load tempo
		move.b	d0,v_tempo_mod(a6)
		tst.b	f_speedup(a6)
		beq.s	.nospeedshoes
		move.b	v_speeduptempo(a6),d0
; loc_72068:
.nospeedshoes:
		move.b	d0,v_main_tempo(a6)
		move.b	d0,v_main_tempo_timeout(a6)
		moveq	#0,d1
		movea.l	a4,a3
		addq.w	#6,a4			; Point past header
		moveq	#0,d7
		move.b	2(a3),d7		; load number of FM+DAC tracks
		beq.w	.bgm_fmdone		; branch if zero
		subq.b	#1,d7
		move.b	#$C0,d1			; Default AMS+FMS+Panning
		move.b	4(a3),d4		; load tempo dividing timing
		moveq	#TrackSz,d6
		move.b	#1,d5			; Note duration for first "note"

		MPCM_stopZ80
		move.b	#0, Z80_RAM+Z_MPCM_VolumeInput	; set DAC volume to maximum
		MPCM_startZ80

		lea	v_music_fmdac_tracks(a6),a1
		lea	FMDACInitBytes(pc),a2
; loc_72098:
.bgm_fmloadloop:
		bset	#7,TrackPlaybackControl(a1)	; Initial playback control: set 'track playing' bit
		move.b	(a2)+,TrackVoiceControl(a1)	; Voice control bits
		move.b	d4,TrackTempoDivider(a1)
		move.b	d6,TrackStackPointer(a1)	; set "gosub" (coord flag $F8) stack init value
		move.b	d1,TrackAMSFMSPan(a1)		; Set AMS/FMS/Panning
		move.b	d5,TrackDurationTimeout(a1)	; Set duration of first "note"
		moveq	#0,d0
		move.w	(a4)+,d0			; load DAC/FM pointer
		add.l	a3,d0				; Relative pointer
		move.l	d0,TrackDataPointer(a1)		; Store track pointer
		move.w	(a4)+,TrackTranspose(a1)	; load FM channel modifier
		adda.w	d6,a1
		dbf	d7,.bgm_fmloadloop

.bgm_fmdone:
		moveq	#0,d7
		move.b	3(a3),d7	; Load number of PSG tracks
		beq.s	.bgm_psgdone	; branch if zero
		subq.b	#1,d7
		lea	v_music_psg_tracks(a6),a1
		lea	PSGInitBytes(pc),a2
; loc_72126:
.bgm_psgloadloop:
		bset	#7,TrackPlaybackControl(a1)	; Initial playback control: set 'track playing' bit
		move.b	(a2)+,TrackVoiceControl(a1)	; Voice control bits
		move.b	d4,TrackTempoDivider(a1)
		move.b	d6,TrackStackPointer(a1)	; set "gosub" (coord flag $F8) stack init value
		move.b	d5,TrackDurationTimeout(a1)	; Set duration of first "note"
		moveq	#0,d0
		move.w	(a4)+,d0			; load PSG channel pointer
		add.l	a3,d0				; Relative pointer
		move.l	d0,TrackDataPointer(a1)	; Store track pointer
		move.w	(a4)+,TrackTranspose(a1)	; load PSG modifier
		move.b	(a4)+,d0			; load redundant byte
		move.b	(a4)+,TrackVoiceIndex(a1)	; Initial PSG tone
		adda.w	d6,a1
		dbf	d7,.bgm_psgloadloop
; loc_72154:
.bgm_psgdone:
		lea	v_sfx_track_ram(a6),a1
		moveq	#((v_sfx_track_ram_end-v_sfx_track_ram)/TrackSz)-1,d7	; 6 SFX tracks
; loc_7215A:
.sfxstoploop:
		tst.b	TrackPlaybackControl(a1) ; Is SFX playing?
		bpl.w	.sfxnext		; Branch if not
		moveq	#0,d0
		move.b	TrackVoiceControl(a1),d0 ; Get voice control bits
		bmi.s	.sfxpsgchannel		; Branch if this is a PSG channel
		subq.b	#2,d0			; SFX can't have FM1 or FM2
		lsl.b	#2,d0			; Convert to index
		bra.s	.gotchannelindex
; ===========================================================================
; loc_7216E:
.sfxpsgchannel:
		lsr.b	#3,d0		; Convert to index
; loc_72170:
.gotchannelindex:
		lea	SFX_BGMChannelRAM(pc),a0
		movea.l	(a0,d0.w),a0
		bset	#2,TrackPlaybackControl(a0)	; Set 'SFX is overriding' bit
; loc_7217C:
.sfxnext:
		adda.w	d6,a1
		dbf	d7,.sfxstoploop

		tst.w	v_spcsfx_fm4_track+TrackPlaybackControl(a6)	; Is special SFX being played?
		bpl.s	.checkspecialpsg				; Branch if not
		bset	#2,v_music_fm4_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
; loc_7218E:
.checkspecialpsg:
		tst.w	v_spcsfx_psg3_track+TrackPlaybackControl(a6)	; Is special SFX being played?
		bpl.s	.sendfmnoteoff					; Branch if not
		bset	#2,v_music_psg3_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
; loc_7219A:
.sendfmnoteoff:
		lea	v_music_fm_tracks(a6),a5
		moveq	#((v_music_fm_tracks_end-v_music_fm_tracks)/TrackSz)-1,d4	; 6 FM tracks
; loc_721A0:
.fmnoteoffloop:
		btst	#2, TrackPlaybackControl(a5)	; is channel overriden?
		bne.s	.fmnoteoffnext			; if yes, branch
		moveq	#$40,d3				; Total level
		moveq	#$7F,d1				; Total attenuation (silent)
		rept 4-1
			move.b	d3,d0
			bsr.w	WriteFMIorII		; operators 1-3
			addq.b	#4,d3
		endr
		move.b	d3,d0
		bsr.w	WriteFMIorII			; operator 4
		jsr	SendFMNoteOff(pc)

.fmnoteoffnext:
		adda.w	d6,a5
		dbf	d4,.fmnoteoffloop		; run all FM tracks

		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d4 ; 3 PSG tracks
; loc_721AC:
.psgnoteoffloop:
		jsr	PSGNoteOff(pc)
		adda.w	d6,a5
		dbf	d4,.psgnoteoffloop		; run all PSG tracks
; loc_721B6:
.locdblret:
		addq.w	#4,sp	; Tamper with return value to not return to caller
		rts	
; ===========================================================================
; byte_721BA:
FMDACInitBytes:	dc.b 6,	0, 1, 2, 4, 5, 6	; first byte is for DAC; then notice the 0, 1, 2 then 4, 5, 6; this is the gap between parts I and II for YM2612 port writes
		even
; byte_721C2:
PSGInitBytes:	dc.b $80, $A0, $C0	; Specifically, these configure writes to the PSG port for each channel
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Play normal sound effect
; ---------------------------------------------------------------------------
; Sound_A0toCF:
Sound_PlaySFX:
		tst.b	f_1up_playing(a6)	; Is 1-up playing?
		bne.w	.clear_sndprio		; Exit is it is
		cmpi.b	#sfx_Ring,d7		; is ring sound	effect played?
		bne.s	.sfx_notRing		; if not, branch
		tst.b	v_ring_speaker(a6)	; Is the ring sound playing on right speaker?
		bne.s	.gotringspeaker		; Branch if not
		move.b	#sfx_RingLeft,d7	; play ring sound in left speaker
; loc_721EE:
.gotringspeaker:
		bchg	#0,v_ring_speaker(a6)	; change speaker
; Sound_notB5:
.sfx_notRing:
		cmpi.b	#sfx_Push,d7		; is "pushing" sound played?
		bne.s	.sfx_notPush		; if not, branch
		tst.b	f_push_playing(a6)	; Is pushing sound already playing?
		bne.w	.locret			; Return if not
		move.b	#$80,f_push_playing(a6)	; Mark it as playing
; Sound_notA7:
.sfx_notPush:
		movea.l	(Go_SoundIndex).l,a0
		subi.b	#sfx__First,d7		; Make it 0-based
		lsl.w	#2,d7			; Convert sfx ID into index
		movea.l	(a0,d7.w),a3		; SFX data pointer
		movea.l	a3,a1
		moveq	#0,d1
		move.w	(a1)+,d1		; Voice pointer
		add.l	a3,d1			; Relative pointer
		move.b	(a1)+,d5		; Dividing timing
	if FixBugs
		moveq	#0,d7
	else
		; DANGER! there is a missing 'moveq #0,d7' here, without which SFXes whose
		; index entry is above $3F will cause a crash.
		; This bug is fixed in Ristar's driver.
	endif
		move.b	(a1)+,d7	; Number of tracks (FM + PSG)
		subq.b	#1,d7
		moveq	#TrackSz,d6
; loc_72228:
.sfx_loadloop:
		moveq	#0,d3
		move.b	1(a1),d3	; Channel assignment bits
		move.b	d3,d4
		bmi.s	.sfxinitpsg	; Branch if PSG
		subq.w	#2,d3		; SFX can only have FM3, FM4 or FM5
		lsl.w	#2,d3
		lea	SFX_BGMChannelRAM(pc),a5
		movea.l	(a5,d3.w),a5
		bset	#2,TrackPlaybackControl(a5)	; Mark music track as being overridden
		bra.s	.sfxoverridedone
; ===========================================================================
; loc_72244:
.sfxinitpsg:
		lsr.w	#3,d3
		lea	SFX_BGMChannelRAM(pc),a5
		movea.l	(a5,d3.w),a5
		bset	#2,TrackPlaybackControl(a5)	; Mark music track as being overridden
		cmpi.b	#$C0,d4			; Is this PSG 3?
		bne.s	.sfxoverridedone	; Branch if not
		move.b	d4,d0
		ori.b	#$1F,d0			; Command to silence PSG 3
		move.b	d0,(psg_input).l
		bchg	#5,d0			; Command to silence noise channel
		move.b	d0,(psg_input).l
; loc_7226E:
.sfxoverridedone:
		movea.l	SFX_SFXChannelRAM(pc,d3.w),a5
		movea.l	a5,a2
		moveq	#(TrackSz/4)-1,d0	; $30 bytes
; loc_72276:
.clearsfxtrackram:
		clr.l	(a2)+
		dbf	d0,.clearsfxtrackram

		move.w	(a1)+,TrackPlaybackControl(a5)	; Initial playback control bits
		move.b	d5,TrackTempoDivider(a5)	; Initial voice control bits
		moveq	#0,d0
		move.w	(a1)+,d0			; Track data pointer
		add.l	a3,d0				; Relative pointer
		move.l	d0,TrackDataPointer(a5)	; Store track pointer
		move.w	(a1)+,TrackTranspose(a5)	; load FM/PSG channel modifier
		move.b	#1,TrackDurationTimeout(a5)	; Set duration of first "note"
		move.b	d6,TrackStackPointer(a5)	; set "gosub" (coord flag $F8) stack init value
		tst.b	d4				; Is this a PSG channel?
		bmi.s	.sfxpsginitdone			; Branch if yes
		move.b	#$C0,TrackAMSFMSPan(a5)	; AMS/FMS/Panning
		move.l	d1,TrackVoicePtr(a5)		; Voice pointer
; loc_722A8:
.sfxpsginitdone:
		dbf	d7,.sfx_loadloop

		tst.b	v_sfx_fm4_track+TrackPlaybackControl(a6)	; Is special SFX being played?
		bpl.s	.doneoverride					; Branch if not
		bset	#2,v_spcsfx_fm4_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
; loc_722B8:
.doneoverride:
		tst.b	v_sfx_psg3_track+TrackPlaybackControl(a6)	; Is SFX being played?
		bpl.s	.locret						; Branch if not
		bset	#2,v_spcsfx_psg3_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
; locret_722C4:
.locret:
		rts	
; ===========================================================================
; loc_722C6:
.clear_sndprio:
		clr.b	v_sndprio(a6)	; Clear priority
		rts	
; ===========================================================================
; ---------------------------------------------------------------------------
; RAM addresses for FM and PSG channel variables used by the SFX
; ---------------------------------------------------------------------------
; dword_722CC: BGMChannelRAM:
SFX_BGMChannelRAM:
		dc.l (v_snddriver_ram+v_music_fm3_track)&$FFFFFF
		dc.l 0
		dc.l (v_snddriver_ram+v_music_fm4_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_music_fm5_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_music_psg1_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_music_psg2_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_music_psg3_track)&$FFFFFF	; Plain PSG3
		dc.l (v_snddriver_ram+v_music_psg3_track)&$FFFFFF	; Noise
; dword_722EC: SFXChannelRAM:
SFX_SFXChannelRAM:
		dc.l (v_snddriver_ram+v_sfx_fm3_track)&$FFFFFF
		dc.l 0
		dc.l (v_snddriver_ram+v_sfx_fm4_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_sfx_fm5_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_sfx_psg1_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_sfx_psg2_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_sfx_psg3_track)&$FFFFFF	; Plain PSG3
		dc.l (v_snddriver_ram+v_sfx_psg3_track)&$FFFFFF	; Noise
; ===========================================================================
; ---------------------------------------------------------------------------
; Play GHZ waterfall sound
; ---------------------------------------------------------------------------
; Sound_D0toDF:
Sound_PlaySpecial:
		tst.b	f_1up_playing(a6)	; Is 1-up playing?
		bne.w	.locret			; Return if so
		movea.l	(Go_SpecSoundIndex).l,a0
		subi.b	#spec__First,d7		; Make it 0-based
		lsl.w	#2,d7
		movea.l	(a0,d7.w),a3
		movea.l	a3,a1
		moveq	#0,d0
		move.w	(a1)+,d0			; Voice pointer
		add.l	a3,d0				; Relative pointer
		move.l	d0,v_special_voice_ptr(a6)	; Store voice pointer
		move.b	(a1)+,d5			; Dividing timing
	if FixBugs
		moveq	#0,d7
	else
		; DANGER! there is a missing 'moveq #0,d7' here, without which special SFXes whose
		; index entry is above $3F will cause a crash. This instance was not fixed in Ristar's driver.
	endif
		move.b	(a1)+,d7			; Number of tracks (FM + PSG)
		subq.b	#1,d7
		moveq	#TrackSz,d6
; loc_72348:
.sfxloadloop:
		move.b	1(a1),d4					; Voice control bits
		bmi.s	.sfxoverridepsg					; Branch if PSG
		bset	#2,v_music_fm4_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit

		lea	v_spcsfx_fm4_track(a6),a5
		bra.s	.sfxinitpsg
; ===========================================================================
; loc_7235A:
.sfxoverridepsg:
		bset	#2,v_music_psg3_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
		lea	v_spcsfx_psg3_track(a6),a5
; loc_72364:
.sfxinitpsg:
		movea.l	a5,a2
		moveq	#(TrackSz/4)-1,d0	; $30 bytes
; loc_72368:
.clearsfxtrackram:
		clr.l	(a2)+
		dbf	d0,.clearsfxtrackram

		move.w	(a1)+,TrackPlaybackControl(a5)	; Initial playback control bits & voice control bits
		move.b	d5,TrackTempoDivider(a5)
		moveq	#0,d0
		move.w	(a1)+,d0			; Track data pointer
		add.l	a3,d0				; Relative pointer
		move.l	d0,TrackDataPointer(a5)	; Store track pointer
		move.w	(a1)+,TrackTranspose(a5)	; load FM/PSG channel modifier
		move.b	#1,TrackDurationTimeout(a5)	; Set duration of first "note"
		move.b	d6,TrackStackPointer(a5)	; set "gosub" (coord flag $F8) stack init value
		tst.b	d4				; Is this a PSG channel?
		bmi.s	.sfxpsginitdone			; Branch if yes
		move.b	#$C0,TrackAMSFMSPan(a5)	; AMS/FMS/Panning
; loc_72396:
.sfxpsginitdone:
		dbf	d7,.sfxloadloop

		tst.b	v_sfx_fm4_track+TrackPlaybackControl(a6)	; Is track playing?
		bpl.s	.doneoverride					; Branch if not
		bset	#2,v_spcsfx_fm4_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
; loc_723A6:
.doneoverride:
		tst.b	v_sfx_psg3_track+TrackPlaybackControl(a6)	; Is track playing?
		bpl.s	.locret						; Branch if not
		bset	#2,v_spcsfx_psg3_track+TrackPlaybackControl(a6)	; Set 'SFX is overriding' bit
		ori.b	#$1F,d4						; Command to silence channel
		move.b	d4,(psg_input).l
		bchg	#5,d4			; Command to silence noise channel
		move.b	d4,(psg_input).l
; locret_723C6:
.locret:
		rts	
; End of function PlaySoundID

; ===========================================================================
; ---------------------------------------------------------------------------
; Unused RAM addresses for FM and PSG channel variables used by the Special SFX
; ---------------------------------------------------------------------------
; The first block would have been used for overriding the music tracks
; as they have a lower priority, just as they are in Sound_PlaySFX
; The third block would be used to set up the Special SFX
; The second block, however, is for the SFX tracks, which have a higher priority
; and would be checked for if they're currently playing
; If they are, then the third block would be used again, this time to mark
; the new tracks as 'currently playing'

; These were actually used in Moonwalker's driver (and other SMPS 68k Type 1a drivers)

; BGMFM4PSG3RAM:
;SpecSFX_BGMChannelRAM:
		dc.l (v_snddriver_ram+v_music_fm4_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_music_psg3_track)&$FFFFFF
; SFXFM4PSG3RAM:
;SpecSFX_SFXChannelRAM:
		dc.l (v_snddriver_ram+v_sfx_fm4_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_sfx_psg3_track)&$FFFFFF
; SpecialSFXFM4PSG3RAM:
;SpecSFX_SpecSFXChannelRAM:
		dc.l (v_snddriver_ram+v_spcsfx_fm4_track)&$FFFFFF
		dc.l (v_snddriver_ram+v_spcsfx_psg3_track)&$FFFFFF

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Snd_FadeOut1: Snd_FadeOutSFX: FadeOutSFX:
StopSFX:
		clr.b	v_sndprio(a6)		; Clear priority
		lea	v_sfx_track_ram(a6),a5
		moveq	#((v_sfx_track_ram_end-v_sfx_track_ram)/TrackSz)-1,d7	; 3 FM + 3 PSG tracks (SFX)
; loc_723EA:
.trackloop:
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.w	.nexttrack			; Branch if not
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		moveq	#0,d3
		move.b	TrackVoiceControl(a5),d3	; Get voice control bits
		bmi.s	.trackpsg			; Branch if PSG
		jsr	FMNoteOff(pc)
		cmpi.b	#4,d3						; Is this FM4?
		bne.s	.getfmpointer					; Branch if not
		tst.b	v_spcsfx_fm4_track+TrackPlaybackControl(a6)	; Is special SFX playing?
		bpl.s	.getfmpointer					; Branch if not
	if FixBugs
		movea.l	a5,a3
	else
		; DANGER! there is a missing 'movea.l a5,a3' here, without which the
		; code is broken. It is dangerous to do a fade out when a GHZ waterfall
		; is playing its sound!
	endif
		lea	v_spcsfx_fm4_track(a6),a5
		movea.l	v_special_voice_ptr(a6),a1	; Get special voice pointer
		bra.s	.gotfmpointer
; ===========================================================================
; loc_72416:
.getfmpointer:
		subq.b	#2,d3		; SFX only has FM3 and up
		lsl.b	#2,d3
		lea	SFX_BGMChannelRAM(pc),a0
		movea.l	a5,a3
		movea.l	(a0,d3.w),a5
		movea.l	v_voice_ptr(a6),a1	; Get music voice pointer
; loc_72428:
.gotfmpointer:
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX is overriding' bit
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		move.b	TrackVoiceIndex(a5),d0	; Current voice
		jsr	SetVoice(pc)
		movea.l	a3,a5
		bra.s	.nexttrack
; ===========================================================================
; loc_7243C:
.trackpsg:
		jsr	PSGNoteOff(pc)
		lea	v_spcsfx_psg3_track(a6),a0
	if FixBugs
		; cfStopTrack does this check but this function oddly lacks it.
		tst.b	TrackPlaybackControl(a0)	; Is track playing?
		bpl.s	.getchannelptr			; Branch if not
	endif
		cmpi.b	#$E0,d3			; Is this a noise channel:
		beq.s	.gotpsgpointer		; Branch if yes
		cmpi.b	#$C0,d3			; Is this PSG 3?
		beq.s	.gotpsgpointer		; Branch if yes

.getchannelptr:
		lsr.b	#3,d3
		lea	SFX_BGMChannelRAM(pc),a0
		movea.l	(a0,d3.w),a0
; loc_7245A:
.gotpsgpointer:
		bclr	#2,TrackPlaybackControl(a0)	; Clear 'SFX is overriding' bit
		bset	#1,TrackPlaybackControl(a0)	; Set 'track at rest' bit
		cmpi.b	#$E0,TrackVoiceControl(a0)	; Is this a noise channel?
		bne.s	.nexttrack			; Branch if not
		move.b	TrackPSGNoise(a0),(psg_input).l ; Set noise type
; loc_72472:
.nexttrack:
		adda.w	#TrackSz,a5
		dbf	d7,.trackloop

		rts	
; End of function StopSFX


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Snd_FadeOut2: FadeOutSFX2: FadeOutSpecialSFX:
StopSpecialSFX:
		lea	v_spcsfx_fm4_track(a6),a5
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.fadedfm			; Branch if not
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	.fadedfm			; Branch if not
		jsr	SendFMNoteOff(pc)
		lea	v_music_fm4_track(a6),a5
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX is overriding' bit
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.fadedfm			; Branch if not
		movea.l	v_voice_ptr(a6),a1		; Voice pointer
		move.b	TrackVoiceIndex(a5),d0		; Current voice
		jsr	SetVoice(pc)
; loc_724AE:
.fadedfm:
		lea	v_spcsfx_psg3_track(a6),a5
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.fadedpsg			; Branch if not
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	.fadedpsg			; Return if not
		jsr	SendPSGNoteOff(pc)
		lea	v_music_psg3_track(a6),a5
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX is overriding' bit
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.fadedpsg			; Return if not
		cmpi.b	#$E0,TrackVoiceControl(a5)	; Is this a noise channel?
		bne.s	.fadedpsg			; Return if not
		move.b	TrackPSGNoise(a5),(psg_input).l ; Set noise type
; locret_724E4:
.fadedpsg:
		rts	
; End of function StopSpecialSFX

; ===========================================================================
; ---------------------------------------------------------------------------
; Fade out music
; ---------------------------------------------------------------------------
; Sound_E0:
FadeOutMusic:
		jsr	StopSFX(pc)
		jsr	StopSpecialSFX(pc)
		move.b	#3,v_fadeout_delay(a6)			; Set fadeout delay to 3
		move.b	#$28,v_fadeout_counter(a6)		; Set fadeout counter
		clr.b	f_speedup(a6)				; Disable speed shoes tempo
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72504:
DoFadeOut:
		move.b	v_fadeout_delay(a6),d0	; Has fadeout delay expired?
		beq.s	.continuefade		; Branch if yes
		subq.b	#1,v_fadeout_delay(a6)
		rts	
; ===========================================================================
; loc_72510:
.continuefade:
		subq.b	#1,v_fadeout_counter(a6)	; Update fade counter
		beq.w	StopAllSound			; Branch if fade is done
		move.b	#3,v_fadeout_delay(a6)		; Reset fade delay

		; Fade out DAC
		lea	v_music_dac_track(a6),a5
		tst.b	(a5)				; is DAC playing?
		bpl.s	.dac_done			; if yes, branch
		addq.b	#4, TrackVolume(a5)		; Increase volume attenuation
		bpl.s	.dac_update_volume
		and.b	#$7F, (a5)			; Stop channel
		bra.s	.dac_done

.dac_update_volume:
		move.b	TrackVolume(a5), d0
		lsr.b	#3, d0
		MPCM_stopZ80
		move.b	d0, Z80_RAM+Z_MPCM_VolumeInput
		MPCM_startZ80
.dac_done:

		lea	v_music_fm_tracks(a6),a5
		moveq	#((v_music_fm_tracks_end-v_music_fm_tracks)/TrackSz)-1,d7	; 6 FM tracks
; loc_72524:
.fmloop:
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.nextfm				; Branch if not
		addq.b	#1,TrackVolume(a5)		; Increase volume attenuation
		bpl.s	.sendfmtl			; Branch if still positive
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		bra.s	.nextfm
; ===========================================================================
; loc_72534:
.sendfmtl:
		jsr	SendVoiceTL(pc)
; loc_72538:
.nextfm:
		adda.w	#TrackSz,a5
		dbf	d7,.fmloop

		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d7	; 3 PSG tracks
; loc_72542:
.psgloop:
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.nextpsg			; branch if not
		addq.b	#1,TrackVolume(a5)		; Increase volume attenuation
		cmpi.b	#$10,TrackVolume(a5)		; Is it greater than $F?
		blo.s	.sendpsgvol			; Branch if not
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		bra.s	.nextpsg
; ===========================================================================
; loc_72558:
.sendpsgvol:
		move.b	TrackVolume(a5),d6	; Store new volume attenuation
		jsr	SetPSGVolume(pc)
; loc_72560:
.nextpsg:
		adda.w	#TrackSz,a5
		dbf	d7,.psgloop

		rts	
; End of function DoFadeOut


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_7256A:
FMSilenceAll:
		moveq	#3-1,d3		; 3 FM channels for each YM2612 part
		moveq	#$28,d0		; FM key on/off register
; loc_7256E:
.noteoffloop:
		move.b	d3,d1
		jsr	WriteFMI(pc)
		addq.b	#4,d1		; Move to YM2612 part 1
		jsr	WriteFMI(pc)
		dbf	d3,.noteoffloop

		moveq	#$40,d0		; Set TL on FM channels...
		moveq	#$7F,d1		; ... to total attenuation...
		moveq	#2,d4		; ... for all 3 channels...
; loc_72584:
.channelloop:
		moveq	#3,d3		; ... for all operators on each channel...
; loc_72586:
.channeltlloop:
		jsr	WriteFMI(pc)	; ... for part 0...
		jsr	WriteFMII(pc)	; ... and part 1.
		addq.w	#4,d0		; Next TL operator
		dbf	d3,.channeltlloop

		subi.b	#$F,d0		; Move to TL operator 1 of next channel
		dbf	d4,.channelloop

		rts	
; End of function FMSilenceAll

; ===========================================================================
; ---------------------------------------------------------------------------
; Stop music
; ---------------------------------------------------------------------------
; Sound_E4: StopSoundAndMusic:
StopAllSound:
		moveq	#$27,d0		; Timers, FM3 mode
		moveq	#0,d1		; FM3 normal mode, disable timers
		jsr	WriteFMI(pc)
		movea.l	a6,a0
	if FixBugs
		move.w	#((v_spcsfx_track_ram_end-v_startofvariables)/4)-1,d0	; Clear $400 bytes: all variables and track data
	else
		; DANGER! This should be clearing all variables and track data, but misses the last $10 bytes of v_spcsfx_psg3_Track.
		move.w	#((v_spcsfx_track_ram_end-v_startofvariables-$10)/4)-1,d0	; Clear $390 bytes: all variables and most track data
	endif
; loc_725B6:
.clearramloop:
		clr.l	(a0)+
		dbf	d0,.clearramloop

		MPCM_stopZ80
		move.b	#Z_MPCM_COMMAND_STOP, Z80_RAM+Z_MPCM_CommandInput ; stop DAC playback
		MPCM_startZ80

		move.b	#$80,v_sound_id(a6)	; set music to $80 (silence)
		jsr	FMSilenceAll(pc)
		bra.w	PSGSilenceAll

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_725CA:
InitMusicPlayback:
		movea.l	a6,a0
		; Save several values
		move.b	v_sndprio(a6),d1
		move.b	f_1up_playing(a6),d2
		move.b	f_speedup(a6),d3
		move.b	v_fadein_counter(a6),d4
		move.w	v_soundqueue0(a6),d5
	if FixBugs
		move.b	v_soundqueue2(a6),d6
	else
		; DANGER! Only v_soundqueue0 and v_soundqueue1 are backed up, once again breaking v_soundqueue2
	endif
		move.w	#((v_music_track_ram_end-v_startofvariables)/4)-1,d0	; Clear $220 bytes: all variables and music track data
; loc_725E4:
.clearramloop:
		clr.l	(a0)+
		dbf	d0,.clearramloop

		; Restore the values saved above
		move.b	d1,v_sndprio(a6)
		move.b	d2,f_1up_playing(a6)
		move.b	d3,f_speedup(a6)
		move.b	d4,v_fadein_counter(a6)
		move.w	d5,v_soundqueue0(a6)
	if FixBugs
		move.b	d6,v_soundqueue2(a6)
	else
		; DANGER! Only v_soundqueue0 and v_soundqueue1 are restored, once again breaking v_soundqueue2
	endif
		move.b	#$80,v_sound_id(a6)	; set music to $80 (silence)
	if FixBugs
		lea	v_music_track_ram+TrackVoiceControl(a6),a1
		lea	FMDACInitBytes(pc),a2
		moveq	#((v_music_fmdac_tracks_end-v_music_fmdac_tracks)/TrackSz)-1,d1		; 7 DAC/FM tracks
		bsr.s	.writeloop
		lea	PSGInitBytes(pc),a2
		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d1	; 3 PSG tracks

.writeloop:
		move.b	(a2)+,(a1)		; Write track's channel byte
		lea	TrackSz(a1),a1		; Next track
		dbf	d1,.writeloop		; Loop for all DAC/FM/PSG tracks

		rts
	else
		; DANGER! This silences ALL channels, even the ones being used
		; by SFX, and not music! .sendfmnoteoff does this already, and
		; doesn't affect SFX channels, either.
		; DANGER! InitMusicPlayback, and Sound_PlayBGM for that matter,
		; don't do a very good job of setting up the music tracks.
		; Tracks that aren't defined in a music file's header don't have
		; their channels defined, meaning .sendfmnoteoff won't silence
		; hardware properly. In combination with removing the above
		; calls to FMSilenceAll/PSGSilenceAll, this will cause hanging
		; notes.
		jsr	FMSilenceAll(pc)
		bra.w	PSGSilenceAll
	endif
	
; End of function InitMusicPlayback


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_7260C:
TempoWait:
		move.b	v_main_tempo(a6),v_main_tempo_timeout(a6)	; Reset main tempo timeout
		lea	v_music_track_ram+TrackDurationTimeout(a6),a0	; note timeout
		moveq	#TrackSz,d0
		moveq	#((v_music_track_ram_end-v_music_track_ram)/TrackSz)-1,d1		; 1 DAC + 6 FM + 3 PSG tracks
; loc_7261A:
.tempoloop:
		addq.b	#1,(a0)	; Delay note by 1 frame
		adda.w	d0,a0	; Advance to next track
		dbf	d1,.tempoloop

		rts	
; End of function TempoWait

; ===========================================================================
; ---------------------------------------------------------------------------
; Speed	up music
; ---------------------------------------------------------------------------
; Sound_E2:
SpeedUpMusic:
		tst.b	f_1up_playing(a6)
		bne.s	.speedup_1up
		move.b	v_speeduptempo(a6),v_main_tempo(a6)
		move.b	v_speeduptempo(a6),v_main_tempo_timeout(a6)
		move.b	#$80,f_speedup(a6)
		rts	
; ===========================================================================
; loc_7263E:
.speedup_1up:
		move.b	v_1up_ram_copy+v_speeduptempo(a6),v_1up_ram_copy+v_main_tempo(a6)
		move.b	v_1up_ram_copy+v_speeduptempo(a6),v_1up_ram_copy+v_main_tempo_timeout(a6)
		move.b	#$80,v_1up_ram_copy+f_speedup(a6)
		rts	
; ===========================================================================
; ---------------------------------------------------------------------------
; Change music back to normal speed
; ---------------------------------------------------------------------------
; Sound_E3:
SlowDownMusic:
		tst.b	f_1up_playing(a6)
		bne.s	.slowdown_1up
		move.b	v_tempo_mod(a6),v_main_tempo(a6)
		move.b	v_tempo_mod(a6),v_main_tempo_timeout(a6)
		clr.b	f_speedup(a6)
		rts	
; ===========================================================================
; loc_7266A:
.slowdown_1up:
		move.b	v_1up_ram_copy+v_tempo_mod(a6),v_1up_ram_copy+v_main_tempo(a6)
		move.b	v_1up_ram_copy+v_tempo_mod(a6),v_1up_ram_copy+v_main_tempo_timeout(a6)
		clr.b	v_1up_ram_copy+f_speedup(a6)
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_7267C:
DoFadeIn:
		tst.b	v_fadein_delay(a6)	; Has fadein delay expired?
		beq.s	.continuefade		; Branch if yes
		subq.b	#1,v_fadein_delay(a6)
		rts	
; ===========================================================================
; loc_72688:
.continuefade:
		tst.b	v_fadein_counter(a6)	; Is fade done?
		beq	.fadedone		; Branch if yes
		subq.b	#1,v_fadein_counter(a6)	; Update fade counter
		move.b	#2,v_fadein_delay(a6)	; Reset fade delay

		; Fade in DAC
		lea	v_music_dac_track(a6),a5
		tst.b	(a5)				; is DAC playing?
		bpl.s	.dac_done			; if yes, branch
		subq.b	#4, TrackVolume(a5)		; Increase volume attenuation
		bcc.s	.dac_update_volume
		move.b	#0, TrackVolume(a5)
		bra.s	.dac_done

.dac_update_volume:
		move.b	TrackVolume(a5), d0
		lsr.b	#3, d0
		MPCM_stopZ80
		move.b	d0, Z80_RAM+Z_MPCM_VolumeInput
		MPCM_startZ80
.dac_done:

		lea	v_music_fm_tracks(a6),a5
		moveq	#((v_music_fm_tracks_end-v_music_fm_tracks)/TrackSz)-1,d7	; 6 FM tracks
; loc_7269E:
.fmloop:
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.nextfm			; Branch if not
		subq.b	#1,TrackVolume(a5)	; Reduce volume attenuation
		jsr	SendVoiceTL(pc)
; loc_726AA:
.nextfm:
		adda.w	#TrackSz,a5
		dbf	d7,.fmloop
		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d7		; 3 PSG tracks
; loc_726B4:
.psgloop:
		tst.b	TrackPlaybackControl(a5) ; Is track playing?
		bpl.s	.nextpsg		; Branch if not
		subq.b	#1,TrackVolume(a5)	; Reduce volume attenuation
		move.b	TrackVolume(a5),d6	; Get value
		cmpi.b	#$10,d6			; Is it is < $10?
		blo.s	.sendpsgvol		; Branch if yes
		moveq	#$F,d6			; Limit to $F (maximum attenuation)
; loc_726C8:
.sendpsgvol:
		jsr	SetPSGVolume(pc)
; loc_726CC:
.nextpsg:
		adda.w	#TrackSz,a5
		dbf	d7,.psgloop
		rts	
; ===========================================================================
; loc_726D6:
.fadedone:
		clr.b	f_fadein_flag(a6)				; Stop fadein
		rts	
; End of function DoFadeIn

; ===========================================================================
; loc_726E2:
FMNoteOn:
		btst	#1,TrackPlaybackControl(a5)	; Is track resting?
		bne.s	.locret				; Return if so
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.locret				; Return if so
		moveq	#$28,d0				; Note on/off register
		move.b	TrackVoiceControl(a5),d1	; Get channel bits
		ori.b	#$F0,d1				; Note on on all operators
		bra.w	WriteFMI
; ===========================================================================
; locret_726FC:
.locret:
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_726FE:
FMNoteOff:
		btst	#4,TrackPlaybackControl(a5)	; Is 'do not attack next note' set?
		bne.s	locret_72714			; Return if yes
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	locret_72714			; Return if yes
; loc_7270A:
SendFMNoteOff:
		moveq	#$28,d0				; Note on/off register
		move.b	TrackVoiceControl(a5),d1	; Note off to this channel
		bra.w	WriteFMI
; ===========================================================================

locret_72714:
		rts	
; End of function FMNoteOff

; ===========================================================================
; loc_72716:
WriteFMIorIIMain:
		btst	#2,TrackPlaybackControl(a5)	; Is track being overriden by sfx?
		bne.s	.locret				; Return if yes
		bra.w	WriteFMIorII
; ===========================================================================
; locret_72720:
.locret:
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72722:
WriteFMIorII:
		move.b	TrackVoiceControl(a5), d2
		subq.b	#4, d2				; Is this bound for part I or II?
		bcc.s	WriteFMIIPart			; If yes, branch
		addq.b	#4, d2				; Add in voice control bits
		add.b	d2, d0				;

; ---------------------------------------------------------------------------
WriteFMI:
		MPCM_stopZ80
		move.b	d0, (ym2612_a0).l
		move.b	d1, (ym2612_d0).l
.waitLoop:	tst.b	(ym2612_d0).l		; is FM busy?
		bmi.s	.waitLoop		; branch if yes
		move.b	#$2A, (ym2612_a0).l	; restore DAC output for Mega PCM
		MPCM_startZ80
		rts
; End of function WriteFMI

; ===========================================================================
; loc_7275A:
WriteFMIIPart:
		add.b	d2,d0			; Add in to destination register

; ---------------------------------------------------------------------------
WriteFMII:
		MPCM_stopZ80
		move.b	d0, (ym2612_a1).l
		move.b	d1, (ym2612_d1).l
.waitLoop:	tst.b	(ym2612_d0).l		; is FM busy?
		bmi.s	.waitLoop		; branch if yes
		move.b	#$2A, (ym2612_a0).l	; restore DAC output for Mega PCM
		MPCM_startZ80		
		rts
; End of function WriteFMII

; ---------------------------------------------------------------------------
FastWriteFMIChannel:
		add.b	d6, d0			; Add in to destination register

; ---------------------------------------------------------------------------
FastWriteFMI:
		move.b	d0, (ym2612_a0).l
		move.b	d1, (ym2612_d0).l
.waitLoop:	tst.b	(ym2612_d0).l		; is FM busy?
		bmi.s	.waitLoop		; branch if yes		
		rts

; ---------------------------------------------------------------------------
FastWriteFMIIChannel:
		add.b	d6, d0			; Add in to destination register

; ---------------------------------------------------------------------------
FastWriteFMII:
		move.b	d0, (ym2612_a1).l
		move.b	d1, (ym2612_d1).l
.waitLoop:	tst.b	(ym2612_d0).l		; is FM busy?
		bmi.s	.waitLoop		; branch if yes		
		rts

; ===========================================================================
; ---------------------------------------------------------------------------
; FM Note Values: b-0 to a#8
;
; Each row is an octave, starting with B and ending with A-sharp/B-flat.
; Notably, this differs from the PSG frequency table, which starts with C and
; ends with B. This is caused by 'FMSetFreq' subtracting $80 from the note
; instead of $81, meaning that the first frequency in the table ironically
; corresponds to the 'rest' note. The only way to use this frequency in a
; real note is to transpose the channel to a lower semitone.
;
; Rather than use a complete lookup table, other SMPS drivers such as
; Sonic 3's compute the octave, and only store a single octave's worth of
; notes in the table.
;
; Invalid transposition values will cause this table to be overflowed,
; resulting in garbage data being used as frequency values. In drivers that
; compute the octave instead, invalid transposition values merely cause the
; notes to wrap-around (the note below the lowest note will be the highest
; note). It's important to keep this in mind when porting buggy songs.
; ---------------------------------------------------------------------------
; word_72790: FM_Notes:
FMFrequencies:
		dc.w $025E,$0284,$02AB,$02D3,$02FE,$032D,$035C,$038F,$03C5,$03FF,$043C,$047C
		dc.w $0A5E,$0A84,$0AAB,$0AD3,$0AFE,$0B2D,$0B5C,$0B8F,$0BC5,$0BFF,$0C3C,$0C7C
		dc.w $125E,$1284,$12AB,$12D3,$12FE,$132D,$135C,$138F,$13C5,$13FF,$143C,$147C
		dc.w $1A5E,$1A84,$1AAB,$1AD3,$1AFE,$1B2D,$1B5C,$1B8F,$1BC5,$1BFF,$1C3C,$1C7C
		dc.w $225E,$2284,$22AB,$22D3,$22FE,$232D,$235C,$238F,$23C5,$23FF,$243C,$247C
		dc.w $2A5E,$2A84,$2AAB,$2AD3,$2AFE,$2B2D,$2B5C,$2B8F,$2BC5,$2BFF,$2C3C,$2C7C
		dc.w $325E,$3284,$32AB,$32D3,$32FE,$332D,$335C,$338F,$33C5,$33FF,$343C,$347C
		dc.w $3A5E,$3A84,$3AAB,$3AD3,$3AFE,$3B2D,$3B5C,$3B8F,$3BC5,$3BFF,$3C3C,$3C7C

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72850:
PSGUpdateTrack:
		subq.b	#1,TrackDurationTimeout(a5)	; Update note timeout
		bne.s	.notegoing
		bclr	#4,TrackPlaybackControl(a5)	; Clear 'do not attack note' bit
		jsr	PSGDoNext(pc)
		jsr	PSGDoNoteOn(pc)
		bra.w	PSGDoVolFX
; ===========================================================================
; loc_72866:
.notegoing:
		jsr	NoteTimeoutUpdate(pc)
		jsr	PSGUpdateVolFX(pc)
		jsr	DoModulation(pc)
		jsr	PSGUpdateFreq(pc)	; It would be better if this were a jmp and the rts was removed
		rts
; End of function PSGUpdateTrack


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72878:
PSGDoNext:
		bclr	#1,TrackPlaybackControl(a5)	; Clear 'track at rest' bit
		movea.l	TrackDataPointer(a5),a4		; Get track data pointer
; loc_72880:
.noteloop:
		moveq	#0,d5
		move.b	(a4)+,d5	; Get byte from track
		cmpi.b	#$E0,d5		; Is it a coord. flag?
		blo.s	.gotnote	; Branch if not
		jsr	CoordFlag(pc)
		bra.s	.noteloop
; ===========================================================================
; loc_72890:
.gotnote:
		tst.b	d5		; Is it a note?
		bpl.s	.gotduration	; Branch if not
		jsr	PSGSetFreq(pc)
		move.b	(a4)+,d5	; Get another byte
		tst.b	d5		; Is it a duration?
		bpl.s	.gotduration	; Branch if yes
		subq.w	#1,a4		; Put byte back
		bra.w	FinishTrackUpdate
; ===========================================================================
; loc_728A4:
.gotduration:
		jsr	SetDuration(pc)
		bra.w	FinishTrackUpdate
; End of function PSGDoNext


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_728AC:
PSGSetFreq:
		subi.b	#$81,d5		; Convert to 0-based index
		bcs.s	.restpsg	; If $80, put track at rest
		add.b	TrackTranspose(a5),d5 ; Add in channel transposition
		andi.w	#$7F,d5		; Clear high byte and sign bit
		lsl.w	#1,d5
		lea	PSGFrequencies(pc),a0
		move.w	(a0,d5.w),TrackFreq(a5)	; Set new frequency
		bra.w	FinishTrackUpdate
; ===========================================================================
; loc_728CA:
.restpsg:
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		move.w	#-1,TrackFreq(a5)		; Invalidate note frequency
		jsr	FinishTrackUpdate(pc)
		bra.w	PSGNoteOff
; End of function PSGSetFreq


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_728DC:
PSGDoNoteOn:
		move.w	TrackFreq(a5),d6	; Get note frequency
		bmi.s	PSGSetRest		; If invalid, branch
; End of function PSGDoNoteOn


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_728E2:
PSGUpdateFreq:
		move.b	TrackDetune(a5),d0	; Get detune value
		ext.w	d0
		add.w	d0,d6				; Add to frequency
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.locret				; Return if yes
		btst	#1,TrackPlaybackControl(a5)	; Is track at rest?
		bne.s	.locret				; Return if yes
		move.b	TrackVoiceControl(a5),d0 ; Get channel bits
		cmpi.b	#$E0,d0		; Is it a noise channel?
		bne.s	.notnoise	; Branch if not
		move.b	#$C0,d0		; Use PSG 3 channel bits
; loc_72904:
.notnoise:
		move.w	d6,d1
		andi.b	#$F,d1		; Low nibble of frequency
		or.b	d1,d0		; Latch tone data to channel
		lsr.w	#4,d6		; Get upper 6 bits of frequency
		andi.b	#$3F,d6		; Send to latched channel
		move.b	d0,(psg_input).l
		move.b	d6,(psg_input).l
; locret_7291E:
.locret:
		rts	
; End of function PSGUpdateFreq

; ===========================================================================
; loc_72920:
PSGSetRest:
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72926:
PSGUpdateVolFX:
		tst.b	TrackVoiceIndex(a5)	; Test PSG tone
		beq.w	locret_7298A		; Return if it is zero
; loc_7292E:
PSGDoVolFX:	; This can actually be made a bit more efficient, see the comments for more
		move.b	TrackVolume(a5),d6	; Get volume
		moveq	#0,d0
		move.b	TrackVoiceIndex(a5),d0	; Get PSG tone
		beq.s	SetPSGVolume
		movea.l	(Go_PSGIndex).l,a0
		subq.w	#1,d0
		lsl.w	#2,d0
		movea.l	(a0,d0.w),a0
		move.b	TrackVolEnvIndex(a5),d0	; Get volume envelope index		; move.b	TrackVolEnvIndex(a5),d0
		move.b	(a0,d0.w),d0			; Volume envelope value			; addq.b	#1,TrackVolEnvIndex(a5)
		addq.b	#1,TrackVolEnvIndex(a5)	; Increment volume envelope index	; move.b	(a0,d0.w),d0
		btst	#7,d0				; Is volume envelope value negative?	; <-- makes this line redundant
		beq.s	.gotflutter			; Branch if not				; but you gotta make this one a bpl
		cmpi.b	#$80,d0				; Is it the terminator?			; Since this is the only check, you can take the optimisation a step further:
		beq.s	VolEnvHold			; If so, branch				; Change the previous beq (bpl) to a bmi and make it branch to VolEnvHold to make these last two lines redundant
; loc_72960:
.gotflutter:
		add.w	d0,d6		; Add volume envelope value to volume
		cmpi.b	#$10,d6		; Is volume $10 or higher?
		blo.s	SetPSGVolume	; Branch if not
		moveq	#$F,d6		; Limit to silence and fall through
; End of function PSGUpdateVolFX


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_7296A:
SetPSGVolume:
		btst	#1,TrackPlaybackControl(a5)	; Is track at rest?
		bne.s	locret_7298A			; Return if so
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	locret_7298A			; Return if so
		btst	#4,TrackPlaybackControl(a5)	; Is track set to not attack next note?
		bne.s	PSGCheckNoteTimeout ; Branch if yes
; loc_7297C:
PSGSendVolume:
		or.b	TrackVoiceControl(a5),d6 ; Add in track selector bits
		addi.b	#$10,d6			; Mark it as a volume command
		move.b	d6,(psg_input).l

locret_7298A:
		rts	
; ===========================================================================
; loc_7298C: PSGCheckNoteFill:
PSGCheckNoteTimeout:
		tst.b	TrackNoteTimeoutMaster(a5)	; Is note timeout on?
		beq.s	PSGSendVolume			; Branch if not
		tst.b	TrackNoteTimeout(a5)		; Has note timeout expired?
		bne.s	PSGSendVolume			; Branch if not
		rts	
; End of function SetPSGVolume

; ===========================================================================
; loc_7299A: FlutterDone:
VolEnvHold:
		subq.b	#1,TrackVolEnvIndex(a5)	; Decrement volume envelope index
		rts	

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_729A0:
PSGNoteOff:
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	locret_729B4			; Return if so
; loc_729A6:
SendPSGNoteOff:
		move.b	TrackVoiceControl(a5),d0	; PSG channel to change
		ori.b	#$1F,d0				; Maximum volume attenuation
		move.b	d0,(psg_input).l
	if FixBugs
		; This is the same fix that S&K's driver uses:
		cmpi.b	#$DF,d0				; Are stopping PSG3?
		bne.s	locret_729B4
		move.b	#$FF,(psg_input).l		; If so, stop noise channel while we're at it
	else
		; DANGER! If InitMusicPlayback doesn't silence all channels, there's the
		; risk of music accidentally playing noise because it can't detect if
		; the PSG4/noise channel needs muting on track initialisation.
	endif

locret_729B4:
		rts	
; End of function PSGNoteOff


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_729B6:
PSGSilenceAll:
		lea	(psg_input).l,a0
		move.b	#$9F,(a0)	; Silence PSG 1
		move.b	#$BF,(a0)	; Silence PSG 2
		move.b	#$DF,(a0)	; Silence PSG 3
		move.b	#$FF,(a0)	; Silence noise channel
		rts	
; End of function PSGSilenceAll

; ===========================================================================
; ---------------------------------------------------------------------------
; PSG Note Values: c-1 to a-6
;
; Each row is an octave, starting with C and ending with B. Sonic 3's driver
; adds another octave at the start, as well as two more notes and the end to
; complete the last octave. Notably, a-6 is changed from 0 to $10. These
; changes need to be applied here in order for ports of songs from Sonic 3
; and later to sound correct.
;
; Here is what Sonic 3's version of this table looks like:
;	dc.w $3FF, $3FF, $3FF, $3FF, $3FF, $3FF, $3FF, $3FF, $3FF, $3F7, $3BE, $388
;	dc.w $356, $326, $2F9, $2CE, $2A5, $280, $25C, $23A, $21A, $1FB, $1DF, $1C4
;	dc.w $1AB, $193, $17D, $167, $153, $140, $12E, $11D, $10D,  $FE,  $EF,  $E2
;	dc.w  $D6,  $C9,  $BE,  $B4,  $A9,  $A0,  $97,  $8F,  $87,  $7F,  $78,  $71
;	dc.w  $6B,  $65,  $5F,  $5A,  $55,  $50,  $4B,  $47,  $43,  $40,  $3C,  $39
;	dc.w  $36,  $33,  $30,  $2D,  $2B,  $28,  $26,  $24,  $22,  $20,  $1F,  $1D
;	dc.w  $1B,  $1A,  $18,  $17,  $16,  $15,  $13,  $12,  $11,  $10,    0,    0
; ---------------------------------------------------------------------------
; word_729CE:
PSGFrequencies:
		dc.w $356, $326, $2F9, $2CE, $2A5, $280, $25C, $23A, $21A, $1FB, $1DF, $1C4
		dc.w $1AB, $193, $17D, $167, $153, $140, $12E, $11D, $10D,  $FE,  $EF,  $E2
		dc.w  $D6,  $C9,  $BE,  $B4,  $A9,  $A0,  $97,  $8F,  $87,  $7F,  $78,  $71
		dc.w  $6B,  $65,  $5F,  $5A,  $55,  $50,  $4B,  $47,  $43,  $40,  $3C,  $39
		dc.w  $36,  $33,  $30,  $2D,  $2B,  $28,  $26,  $24,  $22,  $20,  $1F,  $1D
		dc.w  $1B,  $1A,  $18,  $17,  $16,  $15,  $13,  $12,  $11,    0

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72A5A:
CoordFlag:
		subi.w	#$E0,d5
		lsl.w	#2,d5
		jmp	coordflagLookup(pc,d5.w)
; End of function CoordFlag

; ===========================================================================
; loc_72A64:
coordflagLookup:
		bra.w	cfPanningAMSFMS		; $E0
; ===========================================================================
		bra.w	cfDetune		; $E1
; ===========================================================================
		bra.w	cfSetCommunication	; $E2
; ===========================================================================
		bra.w	cfJumpReturn		; $E3
; ===========================================================================
		bra.w	cfFadeInToPrevious	; $E4
; ===========================================================================
		bra.w	cfSetTempoDivider	; $E5
; ===========================================================================
		bra.w	cfChangeFMVolume	; $E6
; ===========================================================================
		bra.w	cfHoldNote		; $E7
; ===========================================================================
		bra.w	cfNoteTimeout		; $E8
; ===========================================================================
		bra.w	cfChangeTransposition	; $E9
; ===========================================================================
		bra.w	cfSetTempo		; $EA
; ===========================================================================
		bra.w	cfSetTempoDividerAll	; $EB
; ===========================================================================
		bra.w	cfChangePSGVolume	; $EC
; ===========================================================================
		bra.w	cfClearPush		; $ED
; ===========================================================================
		bra.w	cfStopSpecialFM4	; $EE
; ===========================================================================
		bra.w	cfSetVoice		; $EF
; ===========================================================================
		bra.w	cfModulation		; $F0
; ===========================================================================
		bra.w	cfEnableModulation	; $F1
; ===========================================================================
		bra.w	cfStopTrack		; $F2
; ===========================================================================
		bra.w	cfSetPSGNoise		; $F3
; ===========================================================================
		bra.w	cfDisableModulation	; $F4
; ===========================================================================
		bra.w	cfSetPSGTone		; $F5
; ===========================================================================
		bra.w	cfJumpTo		; $F6
; ===========================================================================
		bra.w	cfRepeatAtPos		; $F7
; ===========================================================================
		bra.w	cfJumpToGosub		; $F8
; ===========================================================================
		bra.w	cfOpF9			; $F9
; ===========================================================================
; loc_72ACC:
cfPanningAMSFMS:
		move.b	(a4)+,d1			; New AMS/FMS/panning value
		move.b	TrackVoiceControl(a5),d2	; Is this a PSG track?
		bmi.s	locret_72AEA			; Return if yes
		moveq	#$37, d0
		and.b	TrackAMSFMSPan(a5),d0		; Get current AMS/FMS
		or.b	d0,d1				; Add new panning bits
		move.b	d1,TrackAMSFMSPan(a5)		; Store value
		subq.b	#6, d2				; is channel DAC or FM6?
		bne.s	.not_DAC_or_FM6			; if not, branch
		MPCM_stopZ80
		; Send to DAC/FM6 panning Mega PCM
		; Even though we apply it now anyways, Mega PCM needs to track
		; actual panning bits to restore them in case normal sample is
		; interrupted by an SFX sample
		and.b	#$C0, d1
		move.b	d1, Z80_RAM+Z_MPCM_PanInput
		MPCM_startZ80
	.not_DAC_or_FM6:

		moveq	#$FFFFFFB4,d0			; Command to set AMS/FMS/panning
		bra.w	WriteFMIorIIMain
; ===========================================================================

locret_72AEA:
		rts	
; ===========================================================================
; loc_72AEC: cfAlterNotes:
cfDetune:
		move.b	(a4)+,TrackDetune(a5)	; Set detune value
		rts	
; ===========================================================================
; loc_72AF2: cfUnknown1:
cfSetCommunication:
		move.b	(a4)+,v_communication_byte(a6)	; Set otherwise unused communication byte to parameter
		rts	
; ===========================================================================
; loc_72AF8:
cfJumpReturn:
		moveq	#0,d0
		move.b	TrackStackPointer(a5),d0 ; Track stack pointer
		movea.l	(a5,d0.w),a4		; Set track return address
		move.l	#0,(a5,d0.w)		; Set 'popped' value to zero
		addq.w	#2,a4			; Skip jump target address from gosub flag
		addq.b	#4,d0			; Actually 'pop' value
		move.b	d0,TrackStackPointer(a5) ; Set new stack pointer
		rts	
; ===========================================================================
; loc_72B14:
cfFadeInToPrevious:
		movea.l	a6,a0
		lea	v_1up_ram_copy(a6),a1
		move.w	#((v_music_track_ram_end-v_startofvariables)/4)-1,d0	; $220 bytes to restore: all variables and music track data
; loc_72B1E:
.restoreramloop:
		move.l	(a1)+,(a0)+
		dbf	d0,.restoreramloop

		movea.l	a5,a3
		moveq	#$28,d6
		sub.b	v_fadein_counter(a6),d6			; If fade already in progress, this adjusts track volume accordingly
		
		tst.b	v_music_dac_track(a6)			; is DAC playing?
		bpl.s	.dacdone				; if not, branch
		move.b	#$7F, v_music_dac_track+TrackVolume(a6)	; set initial DAC volume
.dacdone:

		moveq	#((v_music_fm_tracks_end-v_music_fm_tracks)/TrackSz)-1,d7	; 6 FM tracks
		lea	v_music_fm_tracks(a6),a5
; loc_72B3A:
.fmloop:
		btst	#7,TrackPlaybackControl(a5)	; Is track playing?
		beq.s	.nextfm				; Branch if not
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		add.b	d6,TrackVolume(a5)		; Apply current volume fade-in
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	.nextfm				; Branch if yes
		moveq	#0,d0
		move.b	TrackVoiceIndex(a5),d0	; Get voice
		movea.l	v_voice_ptr(a6),a1	; Voice pointer
		jsr	SetVoice(pc)
; loc_72B5C:
.nextfm:
		adda.w	#TrackSz,a5
		dbf	d7,.fmloop

		moveq	#((v_music_psg_tracks_end-v_music_psg_tracks)/TrackSz)-1,d7	; 3 PSG tracks
; loc_72B66:
.psgloop:
		btst	#7,TrackPlaybackControl(a5)	; Is track playing?
		beq.s	.nextpsg			; Branch if not
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		jsr	PSGNoteOff(pc)
		add.b	d6,TrackVolume(a5)	; Apply current volume fade-in
; loc_72B78:
.nextpsg:
		adda.w	#TrackSz,a5
		dbf	d7,.psgloop
		
		movea.l	a3,a5
		move.b	#$80,f_fadein_flag(a6)		; Trigger fade-in
		move.b	#$28,v_fadein_counter(a6)	; Fade-in delay
		clr.b	f_1up_playing(a6)
		MPCM_startZ80
		addq.w	#8,sp		; Tamper return value so we don't return to caller
		rts	
; ===========================================================================
; loc_72B9E:
cfSetTempoDivider:
		move.b	(a4)+,TrackTempoDivider(a5)	; Set tempo divider on current track
		rts	
; ===========================================================================
; loc_72BA4: cfSetVolume:
cfChangeFMVolume:
		move.b	(a4)+,d0		; Get parameter
		add.b	d0,TrackVolume(a5)	; Add to current volume
		bra.w	SendVoiceTL
; ===========================================================================
; loc_72BAE: cfPreventAttack:
cfHoldNote:
		bset	#4,TrackPlaybackControl(a5)	; Set 'do not attack next note' bit
		rts	
; ===========================================================================
; loc_72BB4: cfNoteFill
cfNoteTimeout:
		move.b	(a4),TrackNoteTimeout(a5)		; Note fill timeout
		move.b	(a4)+,TrackNoteTimeoutMaster(a5)	; Note fill master
		rts	
; ===========================================================================
; loc_72BBE: cfAddKey:
cfChangeTransposition:
		move.b	(a4)+,d0		; Get parameter
		add.b	d0,TrackTranspose(a5)	; Add to transpose value
		rts	
; ===========================================================================
; loc_72BC6:
cfSetTempo:
		move.b	(a4),v_main_tempo(a6)		; Set main tempo
		move.b	(a4)+,v_main_tempo_timeout(a6)	; And reset timeout (!)
		rts	
; ===========================================================================
; loc_72BD0: cfSetTempoMod:
cfSetTempoDividerAll:
		lea	v_music_track_ram(a6),a0
		move.b	(a4)+,d0			; Get new tempo divider
		moveq	#TrackSz,d1
		moveq	#((v_music_track_ram_end-v_music_track_ram)/TrackSz)-1,d2	; 1 DAC + 6 FM + 3 PSG tracks
; loc_72BDA:
.trackloop:
		move.b	d0,TrackTempoDivider(a0)	; Set track's tempo divider
		adda.w	d1,a0
		dbf	d2,.trackloop

		rts	
; ===========================================================================
; loc_72BE6: cfChangeVolume:
cfChangePSGVolume:
		move.b	(a4)+,d0		; Get volume change
		add.b	d0,TrackVolume(a5)	; Apply it
		rts	
; ===========================================================================
; loc_72BEE:
cfClearPush:
		clr.b	f_push_playing(a6)	; Allow push sound to be played once more
		rts	
; ===========================================================================
; loc_72BF4:
cfStopSpecialFM4:
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		bclr	#4,TrackPlaybackControl(a5)	; Clear 'do not attack next note' bit
		jsr	FMNoteOff(pc)
		tst.b	v_sfx_fm4_track+TrackPlaybackControl(a6) ; Is SFX using FM4?
		bmi.s	.locexit			; Branch if yes
		movea.l	a5,a3
		lea	v_music_fm4_track(a6),a5
		movea.l	v_voice_ptr(a6),a1		; Voice pointer
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX is overriding' bit
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		move.b	TrackVoiceIndex(a5),d0		; Current voice
		jsr	SetVoice(pc)
		movea.l	a3,a5
; loc_72C22:
.locexit:
		addq.w	#8,sp		; Tamper with return value so we don't return to caller
		rts	
; ===========================================================================
; loc_72C26:
cfSetVoice:
		moveq	#0,d0
		move.b	(a4)+,d0		; Get new voice
		move.b	d0,TrackVoiceIndex(a5)	; Store it
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding this track?
		bne.w	locret_72CAA		; Return if yes
		movea.l	v_voice_ptr(a6),a1	; Music voice pointer
		tst.b	f_voice_selector(a6)	; Are we updating a music track?
		beq.s	SetVoice		; If yes, branch
		movea.l	TrackVoicePtr(a5),a1	; SFX track voice pointer
		tst.b	f_voice_selector(a6)	; Are we updating a SFX track?
		bmi.s	SetVoice		; If yes, branch
		movea.l	v_special_voice_ptr(a6),a1 ; Special SFX voice pointer

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72C4E:
SetVoice:
		move.w	d0, d1
		bmi.s	.havevoiceptr
		add.w	d0,d0			; d0 = 2x
		add.w	d1,d0			; d0 = 3x
		lsl.w	#3,d0			; d0 = 24x
		add.w	d1,d0			; d0 = 25x
		adda.w	d0,a1			; add to voice pointer
; loc_72C5C:
.havevoiceptr:
		move.b	(a1)+,d1		; feedback/algorithm
		move.b	d1,TrackFeedbackAlgo(a5) ; Save it to track RAM
		move.b	d1,d4

		move.l	a3, -(sp)
		move.w	d6, -(sp)
		lea	FastWriteFMIIChannel(pc), a3
		move.b	TrackVoiceControl(a5), d6	; d6 = voice control bits
		subq.b	#4, d6				; Is this bound for part I or II?
		bcc.s	.gotfmroutine			; If yes, branch
		addq.b	#4, d6
		lea	FastWriteFMIChannel(pc), a3
.gotfmroutine:

		MPCM_stopZ80
		moveq	#$FFFFFFB0,d0		; Command to write feedback/algorithm
		jsr	(a3)
		lea	FMInstrumentOperatorTable(pc),a2
		moveq	#(FMInstrumentOperatorTable_End-FMInstrumentOperatorTable)-1,d3		; Don't want to send TL yet
; loc_72C72:
.sendvoiceloop:
		move.b	(a2)+,d0
		move.b	(a1)+,d1
		jsr	(a3)
		dbf	d3,.sendvoiceloop

		moveq	#(FMInstrumentTLTable_End-FMInstrumentTLTable)-1,d5
		andi.w	#7,d4			; Get algorithm
		move.b	FMSlotMask(pc,d4.w),d4	; Get slot mask for algorithm
		move.b	TrackVolume(a5),d3	; Track volume attenuation
; loc_72C8C:
.sendtlloop:
		move.b	(a2)+,d0
		move.b	(a1)+,d1
		lsr.b	#1,d4		; Is bit set for this operator in the mask?
		bcc.s	.sendtl		; Branch if not
		add.b	d3,d1		; Include additional attenuation
; loc_72C96:
.sendtl:
		jsr	(a3)
		dbf	d5,.sendtlloop
		
		moveq	#$FFFFFFB4,d0		; Register for AMS/FMS/Panning
		move.b	TrackAMSFMSPan(a5),d1	; Value to send
		jsr	(a3)

		move.b	#$2A, (ym2612_a0).l	; restore DAC output for Mega PCM
		MPCM_startZ80
		move.w	(sp)+, d6
		move.l	(sp)+, a3

locret_72CAA:
		rts	
; End of function SetVoice

; ===========================================================================
; byte_72CAC:
FMSlotMask:	dc.b 8,	8, 8, 8, $A, $E, $E, $F

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; sub_72CB4:
SendVoiceTL:
		btst	#2,TrackPlaybackControl(a5)	; Is SFX overriding?
		bne.s	.locret				; Return if so
		moveq	#0,d0
		move.b	TrackVoiceIndex(a5),d0	; Current voice
		movea.l	v_voice_ptr(a6),a1	; Voice pointer
		tst.b	f_voice_selector(a6)
		beq.s	.gotvoiceptr
	if FixBugs
		movea.l	TrackVoicePtr(a5),a1
	else
		; DANGER! This uploads the wrong voice! It should have been a5 instead of a6!
		; In Sonic 1's prototype, TrackVoicePtr was a global variable instead of a
		; per-track variable, explaining why this uses a6 instead of a5.
		movea.l	TrackVoicePtr(a6),a1
	endif
		tst.b	f_voice_selector(a6)
		bmi.s	.gotvoiceptr
		movea.l	v_special_voice_ptr(a6),a1
; loc_72CD8:
.gotvoiceptr:
		move.w	d0, d1
		bmi.s	.gotvoice
		add.w	d0,d0			; d0 = 2x
		add.w	d1,d0			; d0 = 3x
		lsl.w	#3,d0			; d0 = 24x
		add.w	d1,d0			; d0 = 25x
		adda.w	d0,a1			; add to voice pointer
; loc_72CE6:
.gotvoice:
		lea	21(a1), a1			; Want TL
		lea	FMInstrumentTLTable(pc),a2
		move.b	TrackFeedbackAlgo(a5),d0	; Get feedback/algorithm
		andi.w	#7,d0				; Want only algorithm
		move.b	FMSlotMask(pc,d0.w),d4		; Get slot mask
		move.b	TrackVolume(a5),d3		; Get track volume attenuation
		bmi.s	.locret				; If negative, stop	
		moveq	#(FMInstrumentTLTable_End-FMInstrumentTLTable)-1,d5
; loc_72D02:
.sendtlloop:
		move.b	(a2)+,d0
		move.b	(a1)+,d1
		lsr.b	#1,d4		; Is bit set for this operator in the mask?
		bcc.s	.senttl		; Branch if not
		add.b	d3,d1		; Include additional attenuation
		bcs.s	.senttl		; Branch on overflow
		jsr	WriteFMIorII(pc)
; loc_72D12:
.senttl:
		dbf	d5,.sendtlloop
; locret_72D16:
.locret:
		rts	
; End of function SendVoiceTL

; ===========================================================================
; byte_72D18:
FMInstrumentOperatorTable:
		dc.b  $30		; Detune/multiple operator 1
		dc.b  $38		; Detune/multiple operator 3
		dc.b  $34		; Detune/multiple operator 2
		dc.b  $3C		; Detune/multiple operator 4
		dc.b  $50		; Rate scalling/attack rate operator 1
		dc.b  $58		; Rate scalling/attack rate operator 3
		dc.b  $54		; Rate scalling/attack rate operator 2
		dc.b  $5C		; Rate scalling/attack rate operator 4
		dc.b  $60		; Amplitude modulation/first decay rate operator 1
		dc.b  $68		; Amplitude modulation/first decay rate operator 3
		dc.b  $64		; Amplitude modulation/first decay rate operator 2
		dc.b  $6C		; Amplitude modulation/first decay rate operator 4
		dc.b  $70		; Secondary decay rate operator 1
		dc.b  $78		; Secondary decay rate operator 3
		dc.b  $74		; Secondary decay rate operator 2
		dc.b  $7C		; Secondary decay rate operator 4
		dc.b  $80		; Secondary amplitude/release rate operator 1
		dc.b  $88		; Secondary amplitude/release rate operator 3
		dc.b  $84		; Secondary amplitude/release rate operator 2
		dc.b  $8C		; Secondary amplitude/release rate operator 4
FMInstrumentOperatorTable_End
; byte_72D2C:
FMInstrumentTLTable:
		dc.b  $40		; Total level operator 1
		dc.b  $48		; Total level operator 3
		dc.b  $44		; Total level operator 2
		dc.b  $4C		; Total level operator 4
FMInstrumentTLTable_End
; ===========================================================================
; loc_72D30:
cfModulation:
		bset	#3,TrackPlaybackControl(a5)	; Turn on modulation
		move.l	a4,TrackModulationPtr(a5)	; Save pointer to modulation data
		move.b	(a4)+,TrackModulationWait(a5)	; Modulation delay
		move.b	(a4)+,TrackModulationSpeed(a5)	; Modulation speed
		move.b	(a4)+,TrackModulationDelta(a5)	; Modulation delta
		move.b	(a4)+,d0			; Modulation steps...
		lsr.b	#1,d0				; ... divided by 2...
		move.b	d0,TrackModulationSteps(a5)	; ... before being stored
		clr.w	TrackModulationVal(a5)		; Total accumulated modulation frequency change
		rts	
; ===========================================================================
; loc_72D52:
cfEnableModulation:
		bset	#3,TrackPlaybackControl(a5)	; Turn on modulation
		rts	
; ===========================================================================
; loc_72D58:
cfStopTrack:
		bclr	#7,TrackPlaybackControl(a5)	; Stop track
		bclr	#4,TrackPlaybackControl(a5)	; Clear 'do not attack next note' bit
		tst.b	TrackVoiceControl(a5)		; Is this a PSG track?
		bmi.s	.stoppsg			; Branch if yes
		tst.b	f_updating_dac(a6)		; Is this the DAC we are updating?
		bmi.w	.locexit			; Exit if yes
		jsr	FMNoteOff(pc)
		bra.s	.stoppedchannel
; ===========================================================================
; loc_72D74:
.stoppsg:
		jsr	PSGNoteOff(pc)
; loc_72D78:
.stoppedchannel:
		tst.b	f_voice_selector(a6)	; Are we updating SFX?
		bpl.w	.locexit		; Exit if not
		clr.b	v_sndprio(a6)		; Clear priority
		moveq	#0,d0
		move.b	TrackVoiceControl(a5),d0 ; Get voice control bits
		bmi.s	.getpsgptr		; Branch if PSG
		lea	SFX_BGMChannelRAM(pc),a0
		movea.l	a5,a3
		cmpi.b	#4,d0			; Is this FM4?
		bne.s	.getpointer		; Branch if not
		tst.b	v_spcsfx_fm4_track+TrackPlaybackControl(a6)	; Is special SFX playing?
		bpl.s	.getpointer		; Branch if not
		lea	v_spcsfx_fm4_track(a6),a5
		movea.l	v_special_voice_ptr(a6),a1	; Get voice pointer
		bra.s	.gotpointer
; ===========================================================================
; loc_72DA8:
.getpointer:
		subq.b	#2,d0		; SFX can only use FM3 and up
		lsl.b	#2,d0
		movea.l	(a0,d0.w),a5
		tst.b	TrackPlaybackControl(a5)	; Is track playing?
		bpl.s	.novoiceupd			; Branch if not
		movea.l	v_voice_ptr(a6),a1		; Get voice pointer
; loc_72DB8:
.gotpointer:
		bclr	#2,TrackPlaybackControl(a5)	; Clear 'SFX overriding' bit
		bset	#1,TrackPlaybackControl(a5)	; Set 'track at rest' bit
		move.b	TrackVoiceIndex(a5),d0		; Current voice
		jsr	SetVoice(pc)
; loc_72DC8:
.novoiceupd:
		movea.l	a3,a5
		bra.s	.locexit
; ===========================================================================
; loc_72DCC:
.getpsgptr:
		lea	v_spcsfx_psg3_track(a6),a0
		tst.b	TrackPlaybackControl(a0)	; Is track playing?
		bpl.s	.getchannelptr	; Branch if not
		cmpi.b	#$E0,d0		; Is it the noise channel?
		beq.s	.gotchannelptr	; Branch if yes
		cmpi.b	#$C0,d0		; Is it PSG 3?
		beq.s	.gotchannelptr	; Branch if yes
; loc_72DE0:
.getchannelptr:
		lea	SFX_BGMChannelRAM(pc),a0
		lsr.b	#3,d0
		movea.l	(a0,d0.w),a0
; loc_72DEA:
.gotchannelptr:
		bclr	#2,TrackPlaybackControl(a0)	; Clear 'SFX overriding' bit
		bset	#1,TrackPlaybackControl(a0)	; Set 'track at rest' bit
		cmpi.b	#$E0,TrackVoiceControl(a0)	; Is this a noise pointer?
		bne.s	.locexit			; Branch if not
		move.b	TrackPSGNoise(a0),(psg_input).l ; Set noise tone
; loc_72E02:
.locexit:
		addq.w	#8,sp		; Tamper with return value so we don't go back to caller
		rts	
; ===========================================================================
; loc_72E06:
cfSetPSGNoise:
		move.b	#$E0,TrackVoiceControl(a5)	; Turn channel into noise channel
		move.b	(a4)+,TrackPSGNoise(a5)		; Save noise tone
		btst	#2,TrackPlaybackControl(a5)	; Is track being overridden?
		bne.s	.locret				; Return if yes
		move.b	-1(a4),(psg_input).l		; Set tone
; locret_72E1E:
.locret:
		rts	
; ===========================================================================
; loc_72E20:
cfDisableModulation:
		bclr	#3,TrackPlaybackControl(a5)	; Disable modulation
		rts	
; ===========================================================================
; loc_72E26:
cfSetPSGTone:
		move.b	(a4)+,TrackVoiceIndex(a5)	; Set current PSG tone
		rts	
; ===========================================================================
; loc_72E2C:
cfJumpTo:
		move.b	(a4)+,d0	; High byte of offset
		lsl.w	#8,d0		; Shift it into place
		move.b	(a4)+,d0	; Low byte of offset
		adda.w	d0,a4		; Add to current position
		subq.w	#1,a4		; Put back one byte
		rts	
; ===========================================================================
; loc_72E38:
cfRepeatAtPos:
		moveq	#0,d0
		move.b	(a4)+,d0			; Loop index
		move.b	(a4)+,d1			; Repeat count
		tst.b	TrackLoopCounters(a5,d0.w)	; Has this loop already started?
		bne.s	.loopexists			; Branch if yes
		move.b	d1,TrackLoopCounters(a5,d0.w)	; Initialize repeat count
; loc_72E48:
.loopexists:
		subq.b	#1,TrackLoopCounters(a5,d0.w)	; Decrease loop's repeat count
		bne.s	cfJumpTo			; If nonzero, branch to target
		addq.w	#2,a4				; Skip target address
		rts	
; ===========================================================================
; loc_72E52:
cfJumpToGosub:
		moveq	#0,d0
		move.b	TrackStackPointer(a5),d0	; Current stack pointer
		subq.b	#4,d0				; Add space for another target
		move.l	a4,(a5,d0.w)			; Put in current address (*before* target for jump!)
		move.b	d0,TrackStackPointer(a5)	; Store new stack pointer
		bra.s	cfJumpTo
; ===========================================================================
; loc_72E64:
cfOpF9:
		move.b	#$88,d0		; D1L/RR of Operator 3
		move.b	#$F,d1		; Loaded with fixed value (max RR, 1TL)
		jsr	WriteFMI(pc)
		move.b	#$8C,d0		; D1L/RR of Operator 4
		move.b	#$F,d1		; Loaded with fixed value (max RR, 1TL)
		bra.w	WriteFMI

; ---------------------------------------------------------------------------
; Music data
; ---------------------------------------------------------------------------

Music81:	incbin	"s1-smps-integration/music/music81.bin"
		even
Music82:	incbin	"s1-smps-integration/music/music82.bin"
		even
Music83:	incbin	"s1-smps-integration/music/music83.bin"
		even
Music84:	incbin	"s1-smps-integration/music/music84.bin"
		even
Music85:	incbin	"s1-smps-integration/music/music85.bin"
		even
Music86:	incbin	"s1-smps-integration/music/music86.bin"
		even
Music87:	incbin	"s1-smps-integration/music/music87.bin"
		even
Music88:	incbin	"s1-smps-integration/music/music88.bin"
		even
Music89:	incbin	"s1-smps-integration/music/music89.bin"
		even
Music8A:	incbin	"s1-smps-integration/music/music8A.bin"
		even
Music8B:	incbin	"s1-smps-integration/music/music8B.bin"
		even
Music8C:	incbin	"s1-smps-integration/music/music8C.bin"
		even
Music8D:	incbin	"s1-smps-integration/music/music8D.bin"
		even
Music8E:	incbin	"s1-smps-integration/music/music8E.bin"
		even
Music8F:	incbin	"s1-smps-integration/music/music8F.bin"
		even
Music90:	incbin	"s1-smps-integration/music/music90.bin"
		even
Music91:	incbin	"s1-smps-integration/music/music91.bin"
		even
Music92:	incbin	"s1-smps-integration/music/music92.bin"
		even
Music93:	incbin	"s1-smps-integration/music/music93.bin"
		even

; ---------------------------------------------------------------------------
; Sound	effect pointers
; ---------------------------------------------------------------------------
SoundIndex:
ptr_sndA0:	dc.l SoundA0
ptr_sndA1:	dc.l SoundA1
ptr_sndA2:	dc.l SoundA2
ptr_sndA3:	dc.l SoundA3
ptr_sndA4:	dc.l SoundA4
ptr_sndA5:	dc.l SoundA5
ptr_sndA6:	dc.l SoundA6
ptr_sndA7:	dc.l SoundA7
ptr_sndA8:	dc.l SoundA8
ptr_sndA9:	dc.l SoundA9
ptr_sndAA:	dc.l SoundAA
ptr_sndAB:	dc.l SoundAB
ptr_sndAC:	dc.l SoundAC
ptr_sndAD:	dc.l SoundAD
ptr_sndAE:	dc.l SoundAE
ptr_sndAF:	dc.l SoundAF
ptr_sndB0:	dc.l SoundB0
ptr_sndB1:	dc.l SoundB1
ptr_sndB2:	dc.l SoundB2
ptr_sndB3:	dc.l SoundB3
ptr_sndB4:	dc.l SoundB4
ptr_sndB5:	dc.l SoundB5
ptr_sndB6:	dc.l SoundB6
ptr_sndB7:	dc.l SoundB7
ptr_sndB8:	dc.l SoundB8
ptr_sndB9:	dc.l SoundB9
ptr_sndBA:	dc.l SoundBA
ptr_sndBB:	dc.l SoundBB
ptr_sndBC:	dc.l SoundBC
ptr_sndBD:	dc.l SoundBD
ptr_sndBE:	dc.l SoundBE
ptr_sndBF:	dc.l SoundBF
ptr_sndC0:	dc.l SoundC0
ptr_sndC1:	dc.l SoundC1
ptr_sndC2:	dc.l SoundC2
ptr_sndC3:	dc.l SoundC3
ptr_sndC4:	dc.l SoundC4
ptr_sndC5:	dc.l SoundC5
ptr_sndC6:	dc.l SoundC6
ptr_sndC7:	dc.l SoundC7
ptr_sndC8:	dc.l SoundC8
ptr_sndC9:	dc.l SoundC9
ptr_sndCA:	dc.l SoundCA
ptr_sndCB:	dc.l SoundCB
ptr_sndCC:	dc.l SoundCC
ptr_sndCD:	dc.l SoundCD
ptr_sndCE:	dc.l SoundCE
ptr_sndCF:	dc.l SoundCF
ptr_sndend

; ---------------------------------------------------------------------------
; Special sound effect pointers
; ---------------------------------------------------------------------------
SpecSoundIndex:
ptr_sndD0:	dc.l SoundD0
ptr_specend

; ---------------------------------------------------------------------------
; Sound effect data
; ---------------------------------------------------------------------------
SoundA0:	incbin	"s1-smps-integration/sfx/soundA0.bin"
		even
SoundA1:	incbin	"s1-smps-integration/sfx/soundA1.bin"
		even
SoundA2:	incbin	"s1-smps-integration/sfx/soundA2.bin"
		even
SoundA3:	incbin	"s1-smps-integration/sfx/soundA3.bin"
		even
SoundA4:	incbin	"s1-smps-integration/sfx/soundA4.bin"
		even
SoundA5:	incbin	"s1-smps-integration/sfx/soundA5.bin"
		even
SoundA6:	incbin	"s1-smps-integration/sfx/soundA6.bin"
		even
SoundA7:	incbin	"s1-smps-integration/sfx/soundA7.bin"
		even
SoundA8:	incbin	"s1-smps-integration/sfx/soundA8.bin"
		even
SoundA9:	incbin	"s1-smps-integration/sfx/soundA9.bin"
		even
SoundAA:	incbin	"s1-smps-integration/sfx/soundAA.bin"
		even
SoundAB:	incbin	"s1-smps-integration/sfx/soundAB.bin"
		even
SoundAC:	incbin	"s1-smps-integration/sfx/soundAC.bin"
		even
SoundAD:	incbin	"s1-smps-integration/sfx/soundAD.bin"
		even
SoundAE:	incbin	"s1-smps-integration/sfx/soundAE.bin"
		even
SoundAF:	incbin	"s1-smps-integration/sfx/soundAF.bin"
		even
SoundB0:	incbin	"s1-smps-integration/sfx/soundB0.bin"
		even
SoundB1:	incbin	"s1-smps-integration/sfx/soundB1.bin"
		even
SoundB2:	incbin	"s1-smps-integration/sfx/soundB2.bin"
		even
SoundB3:	incbin	"s1-smps-integration/sfx/soundB3.bin"
		even
SoundB4:	incbin	"s1-smps-integration/sfx/soundB4.bin"
		even
SoundB5:	incbin	"s1-smps-integration/sfx/soundB5.bin"
		even
SoundB6:	incbin	"s1-smps-integration/sfx/soundB6.bin"
		even
SoundB7:	incbin	"s1-smps-integration/sfx/soundB7.bin"
		even
SoundB8:	incbin	"s1-smps-integration/sfx/soundB8.bin"
		even
SoundB9:	incbin	"s1-smps-integration/sfx/soundB9.bin"
		even
SoundBA:	incbin	"s1-smps-integration/sfx/soundBA.bin"
		even
SoundBB:	incbin	"s1-smps-integration/sfx/soundBB.bin"
		even
SoundBC:	incbin	"s1-smps-integration/sfx/soundBC.bin"
		even
SoundBD:	incbin	"s1-smps-integration/sfx/soundBD.bin"
		even
SoundBE:	incbin	"s1-smps-integration/sfx/soundBE.bin"
		even
SoundBF:	incbin	"s1-smps-integration/sfx/soundBF.bin"
		even
SoundC0:	incbin	"s1-smps-integration/sfx/soundC0.bin"
		even
SoundC1:	incbin	"s1-smps-integration/sfx/soundC1.bin"
		even
SoundC2:	incbin	"s1-smps-integration/sfx/soundC2.bin"
		even
SoundC3:	incbin	"s1-smps-integration/sfx/soundC3.bin"
		even
SoundC4:	incbin	"s1-smps-integration/sfx/soundC4.bin"
		even
SoundC5:	incbin	"s1-smps-integration/sfx/soundC5.bin"
		even
SoundC6:	incbin	"s1-smps-integration/sfx/soundC6.bin"
		even
SoundC7:	incbin	"s1-smps-integration/sfx/soundC7.bin"
		even
SoundC8:	incbin	"s1-smps-integration/sfx/soundC8.bin"
		even
SoundC9:	incbin	"s1-smps-integration/sfx/soundC9.bin"
		even
SoundCA:	incbin	"s1-smps-integration/sfx/soundCA.bin"
		even
SoundCB:	incbin	"s1-smps-integration/sfx/soundCB.bin"
		even
SoundCC:	incbin	"s1-smps-integration/sfx/soundCC.bin"
		even
SoundCD:	incbin	"s1-smps-integration/sfx/soundCD.bin"
		even
SoundCE:	incbin	"s1-smps-integration/sfx/soundCE.bin"
		even
SoundCF:	incbin	"s1-smps-integration/sfx/soundCF.bin"
		even
SoundD0:	incbin	"s1-smps-integration/sfx/soundD0.bin"
		even
