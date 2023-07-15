
; ===============================================================
; ---------------------------------------------------------------
; Routines to control sound playback (stop/pause/interrupt)
; ---------------------------------------------------------------
; NOTICE:
;	The following routines are 'Interrupt' event handlers,
;	they must't use any registers except A. If they does, 
;	it will break sample playback code.
;	You may do push/pop from stack though.
;	'StopDAC' is expection, as it breaks playback anyway.
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; DAC Interrupt: Normal Priority
; ---------------------------------------------------------------
; INPUT:
;	a	= Ctrl byte
; ---------------------------------------------------------------

Int_Normal:
	cp	80h			; stop flag?
	jp	z, StopDAC		; if yes, branch
	jp	m, PauseDAC		; if < 80h, branch
	ld	hl, DAC_Number
	jp	LoadDAC

; ---------------------------------------------------------------
; DAC Interrupt: High Priority
; ---------------------------------------------------------------
; INPUT:
;	a	= Ctrl byte
; ---------------------------------------------------------------

Int_NoOverride:
	cp	80h					; stop flag?
	jp	z,StopDAC			; if yes, branch
	jp	m,PauseDAC			; if < 80h, branch
	xor	a					; a = 0
	ld	(DAC_Number),a		; clear DAC number to prevent later ints
	jp	Event_SoundProc

; ---------------------------------------------------------------
; Code to wait while playback is paused
; ---------------------------------------------------------------

PauseDAC:
	ld	(iy+1), 80h			; stop sound

.loop:
	ld	a,(DAC_Number)		; load ctrl byte
	or	a					; is byte zero?
	jr	nz, .loop			; if not, branch

	call	SetupDAC			; setup YM for playback
	jp	Event_SoundProc		; go on playing

; ---------------------------------------------------------------
; Stop DAC playback and get back to idle loop
; ---------------------------------------------------------------

StopDAC:
	ld	(iy+1),80h			; stop sound
	jp	Idle_Loop
