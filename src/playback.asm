
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.0
;
; Inline functions for sample playback
; -----------------------------------------------------------------------------
; (c) 2023, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initializes sample playback registers
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadaheadPtr	- Register with readahead position (bc, de, hl)
;	locVolumeTables - Volume tables location
;	opPitchSource - pitch source register (ix+NN)
; 
; OUTPUT:
;	iyl	= Pitch
;	a'	= Pitch counter
;	bc'	= Volume table
;	de'	= YM Port 0 data
;	hl'	= Playback position (in SampleBuffer)
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_Init regReadaheadPtr, locVolumeTables, opPitchSource
	push	regReadaheadPtr
	exx
	ex	af, af'
	xor	a				; a' = 0
	ex	af, af'
	ld	b, locVolumeTables>>8		; bc = volume table ###
	ld	c, opPitchSource		; c can be trashed
	ld	iyl, c				; iyl = pitch
	pop	hl				; hl = regReadaheadPtr
	ld	de, YM_Port0_Data
	exx
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "normal" mode (playback + readahead)
; -----------------------------------------------------------------------------
; INPUT:
;	iyl	= Pitch value
;
; OUTPUT:
;	af	= buffer position - 3
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_Run
	exx					; 4
	ld	c, (hl)				; 7	load sample
	ld	a, (bc)				; 7	apply volume
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	iyl				; 8	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7/12	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	ld	a, l				; 4	a = buffer position
	sub	3h				; 7	a = buffer position - 3
	exx					; 4
	; Cycles: 67-68 (playback)
	endm

; -----------------------------------------------------------------------------
; Checks whether readahead buffer can accept more samples
; Should be used after `Playback_Run`
; -----------------------------------------------------------------------------
; INPUT:
;	af	= buffer position - 3
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_ChkReadaheadOk	regReadAheadPtrLow, procReadaheadOk
	sub	regReadAheadPtrLow		; 4	a = buffer position - regReadAheadPtrLow - 3
	jp	m, procReadaheadOk 		; 10	if (buffer position - regReadAheadPtrLow - 3 <= 0), then read ahead is full
	; Cycles: 14
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;	locDrained_EXX - location to jump if drained (exx in effect!)
;
; INPUT:
;	iyl	= Pitch value
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_Run_Draining	regReadAheadPtrLow, locDrained_EXX
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, locDrained_EXX		; 7/12
	ld	c, (hl)				; 7	load sample
	ld	a, (bc)				; 7	apply volume
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	iyl				; 8	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
	exx					; 4
	; Total cycles: 71-72 (playback), 24 (drained)

	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "draining" mode (no-sync version)
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;
; OUTPUT:
;	iyl	= Pitch value
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_Run_Draining_NoSync	regReadAheadPtrLow
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, .playback_Drained		; 7/12
	ld	c, (hl)				; 7	load sample
	ld	a, (bc)				; 7	apply volume
	ld	(de), a				; 7	send it to YM
	ex	af, af'				; 4
	add	iyl				; 8	should we apply pitch?
	jr	nc, .playback_NoPitch		; 7	if not, branch
	inc	l				; 4	advance playback pointer
.playback_NoPitch:
	ex	af, af'				; 4
.playback_Drained:
	exx					; 4
	; Total cycles: 71-72 (playback), 28 (drained)

	endm

; -----------------------------------------------------------------------------
;
; -----------------------------------------------------------------------------
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	Playback_VBlank_ReportBufferHealth	regReadAheadPtrLow, opHealthDst
	exx					; 4
	ld	a, l				; 4
	exx					; 4
	sub	regReadAheadPtrLow		; 4
	ld	opHealthDst, a			; 13 - if `opHealthDst` is (nnn)
	; Total cycles: 29
	endm
