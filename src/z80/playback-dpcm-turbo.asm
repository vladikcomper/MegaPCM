
; =============================================================================
; -----------------------------------------------------------------------------
; Mega PCM 2.2
;
; Inline functions for turbo DPCM playback
; -----------------------------------------------------------------------------
; (c) 2023-2026, Vladikcomper
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initializes playback registers
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	readaheadPtr - Initial readahead buffer pointer
;	dpcmDecodeTablesPtr - DPCM decode tables pointer
; 
; OUTPUT:
;	af'	= Initial sample
;	bc'	= YM Port 0 data
;	de'	= DPCM decode tables pointer
;	hl'	= Playback position (in SampleBuffer)
; -----------------------------------------------------------------------------

	macro	PlaybackDPCMTurbo_Init_DI readaheadPtr, dpcmDecodeTablesPtr
	exx
	ex	af, af'
	ld	a, 80h				; a' = initial sample
	ex	af, af'
	ld	bc, YM_Port0_Data
	ld	de, dpcmDecodeTablesPtr		; de' = dpcmDecodeTablesPtr
	ld	hl, readaheadPtr		; hl' = readaheadPtr
	exx
	endm

; -----------------------------------------------------------------------------
; Executes playback tick/iteration in "normal" mode (playback + readahead)
;
; WARNING! This doesn't check if playback and readhead pointers clash!
; Make sure to buffer at least 2 samples ahead of time before calling this!
;
; WARNING! These macros are designed for unrolled loop (2 nibbles per loop).
; In the same loop, you must call `PlaybackDPCMTurbo_Run_Nibble0_DI`, then
; `PlaybackDPCMTurbo_Run_Nibble1_DI`.
; You cannot touch `a` register in-between calls!
; -----------------------------------------------------------------------------

	macro	PlaybackDPCMTurbo_Run_Nibble0_DI
	exx					; 4
	ld	e, (hl)				; 7	e' = DPCM byte
	ex	de, hl				; 4
	ex	af, af'				; 4	get previous sample
	add	a, (hl)				; 7	a' = current sample
	ld	(bc), a				; 7	send to YM
	inc	h				; 4	use nibble 1 decode table next
	exx					; 4
	; Cycles: 41 (playback)
	endm

; -----------------------------------------------------------------------------

	macro	PlaybackDPCMTurbo_Run_Nibble1_EXAF_DI
	; Set by `PlaybackDPCMTurbo_Run_Nibble0_DI`:
	; a'	= previous sample
	; de'	= sample buffer pointer
	; hl'	= DPCM decode table for nibble 1
	exx					; 4
	add	a, (hl)				; 7	a' = current sample
	dec	h				; 4	use nibble 0 decode table next
	ex	de, hl				; 4
	inc	l				; 4	next buffer pos
	ld	(bc), a				; 7	send to YM
	ex	af, af'				; 4	remember as previous sample
	ld	a, l				; 4	a = buffer pos
	;FIXME: ei here
	exx					; 4
	; Cycles: 42 (playback)
	endm


; -----------------------------------------------------------------------------
; Checks whether readahead buffer can accept more samples
; Should be used after `PlaybackDPCMTurbo_Run_DI`
; -----------------------------------------------------------------------------
; ARGUMENTS:
;	regReadAheadPtrLow - Low byte of readahead position (c, e, l)
;	regValue05h - register that contains value of 05h
;	locReadaheadOk - location to jump if readahead isn't full
;
; INPUT:
;	af	= buffer position
;
; USES:
;	af, Shadow registers
; -----------------------------------------------------------------------------

	macro	PlaybackDPCMTurbo_ChkReadaheadOk	regReadAheadPtrLow, regValue05h, locReadaheadOk
	sub	regReadAheadPtrLow		; 4	a = buffer position - regReadAheadPtrLow
	sub	regValue05h			; 4	a = buffer position - regReadAheadPtrLow - 5
@.chkReadahead_sm1:		; points to self-modifying code (allows to overwrite `locReadaheadOk` for cycle calibration)
	jp	nc, locReadaheadOk 		; 10	if (buffer position - regReadAheadPtrLow <= 5), then read ahead is ok
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

	macro	PlaybackDPCMTurbo_Run_Draining_Nibble0	regReadAheadPtrLow, locDrained_EXX
	ld	a, regReadAheadPtrLow		; 4	a = read ahead position
	exx					; 4
	cp	l				; 4
	jr	z, locDrained_EXX		; 7/12
	ex	af, af'				; 4
	ld	e, (hl)				; 7	e = DPCM byte
	ex	de, hl				; 4
	add	a, (hl)				; 7	a' = current sample
	inc	h				; 4	use nibble 1 decode table next
	ld	(bc), a				; 7	send to YM
	ex	af, af'				; 4	get previous sample
	exx					; 4
	; Total cycles: 60 (playback), 24 (drained)
	endm

; -----------------------------------------------------------------------------

	; Decoding the second nibble from the same buffer doesn't need a drained check
	macro	PlaybackDPCMTurbo_Run_Draining_Nibble1
	exx					; 4
	ex	af, af'				; 4
	add	a, (hl)				; 7	a' = current sample
	dec	h				; 4	use nibble 0 decode table next
	ex	de, hl				; 4
	inc	l				; 4	next buffer pos
	ld	(bc), a				; 7	send to YM
	ex	af, af'				; 4
	exx					; 4
	; Cycles: 42 (playback)
	endm
