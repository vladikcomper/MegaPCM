
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.0
;
; Inline functions for turbo PCM playback
; -----------------------------------------------------------------------------
; (c) 2023, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initializes pitched playback registers
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	readaheadPtr	- Initial readahead buffer pointer
; 
; OUTPUT:
;	de'	= YM Port 0 data
;	hl'	= Playback position (in SampleBuffer)
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_Init_DI readaheadPtr
	exx
	ld	hl, readaheadPtr		; hl = readaheadPtr
	ld	de, YM_Port0_Data
	exx
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "normal" mode (playback + readahead)
;
; WARNING! This doesn't check if playback and readhead pointers clash!
; Make sure to buffer at least 2 samples ahead of time before calling this!
; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_Run_DI
	exx					; 4
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	inc	l				; 4	advance playback pointer
	ld	a, l				; 4	a = buffer position
	exx					; 4
	; Cycles: 30 (playback)
	endm

; -----------------------------------------------------------------------------
; Checks whether readahead buffer can accept more samples
; Should be used after `PlaybackTurbo_Run_DI`
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;	regValue04h - register that contains value of 04h
;	locReadaheadOk - location to jump if readahead isn't full
;
; INPUT:
;	af	= buffer position
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_ChkReadaheadOk	regReadAheadPtrLow, regValue04h, locReadaheadOk
	sub	regReadAheadPtrLow		; 4	a = buffer position - regReadAheadPtrLow
	sub	regValue04h			; 4	a = buffer position - regReadAheadPtrLow - 4
	jp	nc, locReadaheadOk 		; 10	if (buffer position - regReadAheadPtrLow <= 4), then read ahead is ok
	; Cycles: 18
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;	locDrained_EXX - location to jump if drained (exx in effect!)
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_Run_Draining	regReadAheadPtrLow, locDrained_EXX
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, locDrained_EXX		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	inc	l				; 4	advance playback pointer
	exx					; 4
	; Total cycles: 41 (playback), 20 (drained)
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode (no-sync version)
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_Run_Draining_NoSync	regReadAheadPtrLow
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Drained		; 7/12
	ld	a, (hl)				; 7	load sample
	ld	(de), a				; 7	send it to YM
	inc	l				; 4	advance playback pointer
.playback_Drained:
	exx					; 4
	; Total cycles: 41 (playback), 24 (drained)
	endm


; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	PlaybackTurbo_VBlank_ReportBufferHealth	regReadAheadPtrLow, opHealthDst
	exx					; 4
	ld	a, l				; 4
	exx					; 4
	sub	regReadAheadPtrLow		; 4
	ld	opHealthDst, a			; 13 - if `opHealthDst` is (nnn)
	; Total cycles: 29
	endm
