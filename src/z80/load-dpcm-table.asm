
; --------------------------------------------------------------
; Generates fast DPCM decode tables
; --------------------------------------------------------------
; INPUT:
;	hl	Source deltas array
;
; USES:
;	af, bc, de, hl, bc', de', hl', ix, iy, Blast processing
; --------------------------------------------------------------

LoadDPCMTable_DI:
	; TODO: Catch nested attempts to use `(StackCopy)`
	ld	(StackCopy), sp			; 20

	; Generate nibble 0 table
	ld	sp, DPCMTables+0100h		; 10	start filling from the end of the table 0
	ld	bc, 16				; 10	bc = deltas length
	add	hl, bc				; 11	skip to the end of the table
	ld	b, c				; 4	b = 16 -- repeat the following block 16 times

.GenerateNibble0Table_Loop:
	dec	hl				; 6	previous delta entry
	ld	e, (hl)				; 7	e = delta
	ld	d, e				; 4	d = delta
	rept	16/2
		push	de			; 11	fill table row with repeated delta
	endr					; =88
	djnz	.GenerateNibble0Table_Loop	; 13/8
	; Cycles: 10+10+11+4 + (6+7+4+88+13) * 16 - (13-8) = 1918

	; Generate nibble 1 table
	ld	sp, hl				; 6
	pop	af				; 10	af = bytes 00..01
	pop	de				; 10	de = bytes 02..03
	pop	hl				; 10	hl = bytes 04..05
	exx					; 4
	pop	bc				; 10	bc' = bytes 06..07
	pop	de				; 10	de' = bytes 08..09
	pop	hl				; 10	hl' = bytes 0A..0B
	exx					; 4
	pop	ix				; 14	ix = bytes 0C..0D
	pop	iy				; 14	iy = bytes 0E..0F
	ld	sp, DPCMTables+0200h		; 10	start filling from the end of the table 1
	ld	b, 16				; 7	repeat the following block 16 times

.GenerateNibble1Table_Loop:
	push	iy				; 15	bytes 0E..0F
	push	ix				; 15	bytes 0C..0D
	exx					; 4
	push	hl				; 11	bytes 0A..0B
	push	de				; 11	bytes 08..09
	push	bc				; 11	bytes 06..07
	exx					; 4
	push	hl				; 11	bytes 04..05
	push	de				; 11	bytes 02..03
	push	af				; 11	bytes 00..01
	djnz	.GenerateNibble1Table_Loop	; 13/8	repeat 16 more times
	; Cycles: 7+6+10+10+10+4+10+10+10+4+14+14+10 + (15+15+4+11+11+11+4+11+11+11+13) * 16 - (13-8) = 1986

	ld	sp, (StackCopy)			; 20	restore stack
	ret					; 10
	; Total cycles: 20 + 1918 + 1986 + 20 + 10 = 3954 (~7.72 cycles per byte)

; --------------------------------------------------------------
DPCM_DeltaTable_0:	; standard DPCM table / DPCM-HQ table #0
	db	000h, 001h, 002h, 004h, 008h, 010h, 020h, 040h
	db	080h, 0FFh, 0FEh, 0FCh, 0F8h, 0F0h, 0E0h, 0C0h

DPCM_DeltaTable_1:	; DPCM-HQ table #1
	db	0DEh, 0EBh, 0F3h, 0F8h, 0FBh, 0FDh, 0FEh, 0FFh
	db	000h, 001h, 002h, 003h, 005h, 008h, 00Dh, 015h
