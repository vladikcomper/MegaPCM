
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.0
;
; Inline functions for pitched playback
; -----------------------------------------------------------------------------
; (c) 2023, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initializes pitched playback registers
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadaheadPtr	- Register with readahead position (bc, de, hl)
;	readaheadCount - Number or readahead samples per iteration
; 
; INPUT:
;	ix	= Sample pointer
; 
; OUTPUT:
;	a'	= Pitch counter
;	b'	= Pitch value
;	c'	= `03h`
;	de'	= YM Port 0 data
;	hl'	= Playback position (in SampleBuffer)
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Init regReadaheadPtr, readaheadCount
	push	regReadaheadPtr
	exx
	ex	af, af'
	xor	a				; a' = 0
	ex	af, af'
	ld	b, (ix+sSample.pitch)
	ld	c, readaheadCount+1		; c = readaheadCount + 1 (constant)
	pop	hl				; hl = regReadaheadPtr
	ld	de, YM_Port0_Data
	exx
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "normal" mode (playback + readahead)
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_Normal	regReadAheadPtrLow, procReadaheadFull
	di					; 4
	ld	a, regReadAheadPtrLow		; 4	a = "read-ahead" position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Skip		; 7/12	if buffer is drained, branch
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7/12	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
.playback_Skip:
	ld	a, l				; 4	a = buffer position
	sub	c				; 4	a = buffer position - 3
	exx					; 4
	ei					; 4
	; Cycles: 44 (drained), 76 (playback, pitched), 77 (playback, didn't pitch)

	sub	regReadAheadPtrLow		; 4	a = buffer position - regReadAheadPtrLow - 3
	jp	p, procReadaheadFull 		; 10	if (buffer position - regReadAheadPtrLow - 3 <= 0), then read ahead is full
	; Cycles: 14

	; Total cycles:
	; - 58 cycles (playback drained)
	; - 90-91 cycles (playback ok)

	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_Draining	regReadAheadPtrLow, procDrainDone_EXX_DI
	di					; 4
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, procDrainDone_EXX_DI		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	exx					; 4
	ei					; 4
	; Total cycles: 72 (pitch), 73 (no pitch), 28 (drain done)

	endm


; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode (interrupt version)
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_DrainingVBlank	regReadAheadPtrLow, procDrainDone_EXX
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, procDrainDone_EXX		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	exx					; 4
	; Total cycles: 64 (pitch), 65 (no pitch), 24 (drain done)

	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode (no sync version)
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackPitched_Run_DrainingVBlank_ReloadPitch_NoSync	regReadAheadPtrLow, opPitchSource
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Done		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	a, b				; 4	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ld	b, opPitchSource		; 19	reloads pitch
	ex	af, af'				; 4
.playback_Done:
	exx					; 4
	; Total cycles: 83 (pitch), 84 (no pitch), 28 (drain done)

	endm

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
; USES:
;	af
; -----------------------------------------------------------------------------

; UNUSED
	macro	PlaybackPitched_VBlank_ReportBufferHealth	regReadAheadPtrLow
	exx					; 4
	ld	a, l				; 4
	exx					; 4
	sub	regReadAheadPtrLow		; 4
	ld	(DriverIO_RAM+sDriverIO.???), a	; 13
	; Total cycles: 29
	endm
