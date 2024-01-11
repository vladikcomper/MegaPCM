
; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM 2.0
;
; M68K bindings for Mega PCM
; ------------------------------------------------------------------------------
; (c) 2023-2024, Vladikcomper
; ------------------------------------------------------------------------------

	section	rom

; ------------------------------------------------------------------------------

	xdef	MegaPCM_LoadDriver
	xdef	MegaPCM_LoadSampleTable

	public	on
	include	'../build/megapcm.symbols.asm'
	public	off

; ------------------------------------------------------------------------------

	include	'../lib-68k/debugger.asm'

	include	'vars.asm'
	include	'macros.asm'

	include	'sample-table.asm'


; ==============================================================================
; ------------------------------------------------------------------------------
; Loads Mega PCM driver and waits for its initialization
; ------------------------------------------------------------------------------

MegaPCM_LoadDriver:

	; ----------------------------------------------------------------------
	; USES:
	@var0:		equr	d0	;	generic variable #1
	@var1:		equr	d1	;	generic variable #2
	@src:		equr	a0	;	generic source pointer
	@dest:		equr	a1	;	generic destination pointer
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; INTERNAL REGISTERS:
	move.l	a3, -(sp)
	@z80_busreq:	equr	a3	;	= Z80_BUSREQ (optimization)
	; ----------------------------------------------------------------------

	lea	Z80_BUSREQ, @z80_busreq
	@op_z80_reset:	equs	'Z80_RESET-Z80_BUSREQ(@z80_busreq)'

	move.w	#$100, @var0
	move.w	@var0, (@z80_busreq)		; request Z80 bus (stop Z80)
	move.w	@var0, \@op_z80_reset		; release Z80 reset

	; Loads Mega PCM program into Z80 memory ...
	KDebug.WriteLine "Loading Mega PCM 2.0 driver..."
	lea	MegaPCM(pc), @src
	lea	Z80_RAM, @dest
	move.w	#(MegaPCM_End-MegaPCM)-1, @var1

	@LoadLoop:
		move.b	(@src)+, (@dest)+
		dbf	@var1, @LoadLoop

	; Starts Z80 and prepares for "wait Mega PCM ready" cycle
	moveq	#0, @var1
	move.w	@var1, \@op_z80_reset		; reset Z80
	lea	Z80_RAM+Z_MPCM_DriverReady, @src; @src = Z_MPCM_DriverReady
	nop
	nop
	move.w	@var0, \@op_z80_reset		; release Z80 reset
	move.w	@var1, (@z80_busreq)		; release Z80 bus (start Z80)

	; Waits until Mega PCM reports that it's ready
	KDebug.WriteLine "Waiting for Mega PCM initialization..."
	bra.s	@Wait

	@WaitReadyLoop:
		stopZ80 (@z80_busreq)
		move.b	(@src), @var1		; d1 = Z_MPCM_DriverReady
		startZ80 (@z80_busreq)
		cmp.b	#'R', @var1		; is driver ready?
		beq.s	@Done			; if yes, branch

	@Wait:	; WARNING! Mega PCM performs ROM/RAM benchmarks during boot to
		; calibrate playback for inaccurate emulators.
		; It's highly recommended not to interrupt Z80 too often during
		; this phase, so benchmark is accurate.
		; Calibration takes roughly 3 frames, so don't worry about
		; wasting too many cycles.
		move.w	#$FFF, @var0
		dbf	@var0, *		; waste 40k+ cycles
		bra.s	@WaitReadyLoop

@Done:	; ----------------------------------------------------------------------
	; Release additional registers and quit
	move.l	(sp)+, a3
	rts


; ==============================================================================
; ------------------------------------------------------------------------------
; Loads a give sample table to Mega PCM
; ------------------------------------------------------------------------------

MegaPCM_LoadSampleTable:

	; ----------------------------------------------------------------------
	; INPUT:
	@sample_tbl:	equr	a0	;	sample table pointer
	@sample_cnt:	equr	d0	; .w	samples in table minus one
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; OUTPUT:
	; TODO: Implement
	@error_code:	equr	d0	; .w	WARNING! Clashes with @sample_cnt
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; USES:
	@var0:		equr	d1	;	generic varible #1
	@z80_sample_tbl:equr	a1	;	position in Z80 sample table
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; INTERNAL REGISTERS:
	movem.l	d2-d5/a2-a4, -(sp)
	@sample_start:	equr	a2	;	sample start pointer
	@z80_busreq:	equr	a3	;	= Z80_BUSREQ (optimization)
	@sample_end:	equr	a4	;	sample end pointer

	@var1:		equr	d2	;	generic varible #2
	@sample_pitch:	equr	d3	;	sample pitch
	@sample_flags:	equr	d4	;	sample flags
	@sample_type:	equr	d5	;	sample type
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; LOCAL MACROS:
	@moveLE: macro	src, dest
		if "\0"="w"
			move.b	1+\src, (sp)
			move.b	\src, 1(sp)
			move.w	(sp), \dest
		elseif "\0"="l"
			move.b	3+\src, (sp)
			move.b	2+\src, 1(sp)
			move.b	1+\src, 2(sp)
			move.b	\src, 3(sp)
			move.w	(sp), \dest
		else
			inform 0, "Unsupported size: \0"
		endc
		endm
	; ----------------------------------------------------------------------

	lea	Z80_BUSREQ, @z80_busreq


	lea	Z80_RAM+Z_MPCM_SampleTable, @z80_sample_tbl
	subq.w	#4, sp					; used for fast LE->BE conversion

	@ProcessSample:
		; Fetch sample record data ...
		move.b	(@sample_tbl)+, @sample_type
		beq.w	@WriteEmptyRecord			; if type is TYPE_NONE, fill everything with zeroes
		move.b	(@sample_tbl)+, @sample_flags
		move.b	(@sample_tbl)+, @sample_pitch
		addq.w	#1, @sample_tbl				; skip a reserved byte
		move.l	(@sample_tbl)+, @sample_start
		move.l	(@sample_tbl)+, @sample_end

		KDebug.WriteLine "Sample: type=%<.b @sample_type>, flags=%<.b @sample_flags>, pitch=%<.b @sample_pitch>, start=%<.l @sample_start sym>, end=%<.l @sample_end sym>"

		; If sample type is DPCM, we don't have to check if it's a WAVE file
		cmp.b	#TYPE_DPCM, @sample_type
		beq.w	@WriteSampleData

		; For TYPE_PCM and TYPE_PCM_TURBO, detect RIFF header if present
		; TODO: AIFF support?
		cmp.l	#'RIFF', (@sample_start)
		bne.w	@PCM_AlignOffsets			; if not RIFF container, assume it's raw data

		; Validate WAVE file format ...
		cmp.l	#'WAVE', 8(@sample_start)		; for RIFF containers, we only accept WAVE type
		bne.w	@Err_WAVE_InvalidHeaderFormat

		KDebug.WriteLine "Detected WAVE header"

		lea	$C(@sample_start), @sample_start	; locate "fmt" chunk
		cmp.l	#'fmt ', (@sample_start)
		bne.w	@Err_WAVE_InvalidHeaderFormat
		cmp.w	#$0100, 8(@sample_start)		; is sample type uncompressed PCM ($0001 Little-endian)?
		bne.w	@Err_WAVE_UnsupportedAudioFormat	; if not, branch
		cmp.w	#$0100, $A(@sample_start)		; is number of channels 1 ($0001 Little-endian)?
		bne.w	@Err_WAVE_TooManyChannels		; if not, branch
		cmp.w	#$0800, $16(@sample_start)		; is bits per sample 8 ($0008 Little-endian)?
		bne.w	@Err_WAVE_TooBitsPerSample		; if not, branch

		; If pitch isn't set, auto-calucate based on WAVE sample rate ...
		tst.b	@sample_pitch					; is pitch set in the sample table?
		beq.s	@WAVE_SeekDataChunk			; if yes, don't calculate it
		@moveLE.w $C(@sample_start), @var0		; @var0 = sample rate (e.g. 22050)
		cmp.b	#'T', @sample_type			; is sample TYPE_PCM_TURBO?
		bne.s	@WAVE_CalcPitch				; if not, branch
		cmp.w	#32000, @var0				; TYPE_PCM_TURBO should use rate of 32000
		bne.w	@Err_WAVE_InvalidSampleRateForTurbo	; if it doesn't raise an error
		moveq	#-1, @sample_pitch			; set pitch to $FF (max)
		bra.s	@WAVE_SeekDataChunk

	@WAVE_CalcPitch:
		cmp.w	#24500, @var0		; TODO: Replace with a named constant
		bhi.w	@Err_WAVE_UnsupportedSampleRate
		ext.l	@var0
		lsl.l	#8, @var0
		divu.w	#24686, @var0		; TODO: Replace with a named constant
		move.b	@var0, @sample_pitch

		; Locate "data" chunk ...
	@WAVE_SeekDataChunk:
		cmpa.l	@sample_start, @sample_end			; if we went outside of WAVE file
		bhs.w	@Err_WAVE_UnableToLocateDataChunk		; ... raise an exception
		@moveLE.l 4(@sample_start), @var0			; @var0 = chunk size
		lea	8(@sample_start, @var0.l), @sample_start	; load next chunk
		cmp.l	#'data', (@sample_start)			; is this a "data" chunk?
		bne.s	@WAVE_SeekDataChunk				; if not, repeat ...

		; Accurately detect `@sample_end` offset based on "data" chunk length ...
		@moveLE.l 4(@sample_start), @var0			; @var0 = data size
		lea	8(@sample_start, @var0.l), @sample_end		; we can now acurately detect sample's end offset
		addq.w	#8, @sample_start

		KDebug.WriteLine "WAVE data offsets: start=%<.l @sample_start sym>, end=%<.l @sample_end sym>"

	@PCM_AlignOffsets:
		; Round end offset to even address boundary if needed ...
		move.w	@sample_end, @var0
		and.w	#1, @var0
		suba.w	@var0, @sample_end				; this subtracts 1 if address was ODD, so it gets EVEN

	@WriteSampleData:
		tst.b	@sample_pitch
		beq.w	@Err_PitchNotSet				; pitch can't be zero

		; Convert absolute start/end offsets to Z80 banks and window addresses ...
		move.l	@sample_start, @var0
		add.l	@var0, @var0
		addq.w	#1, @var0					; bit 0 is always zero, so we just set it
		ror.w	#1, @var0					; @var0 LOW  = start offset | $8000
		move.w	@var0, (sp)					; stack @00  = start offset | $8000
		swap	@var0						; @var0 HIGH = start bank

		move.l	@sample_end, @var1
		add.l	@var1, @var1
		addq.w	#1, @var1					; bit 0 is always zero, so we just set it
		ror.w	#1, @var1					; @var1 LOW  = end offset | $8000
		move.w	@var1, 2(sp)					; stack @02  = end offset | $8000
		swap	@var1						; @var1 HIGH = end bank

		; We can send processed data to Mega PCM's sample table now ...
		stopZ80	(@z80_busreq)
		move.b	@sample_type, (@z80_sample_tbl)+		; 00h	- sample type
		move.b	@sample_flags, (@z80_sample_tbl)+		; 01h	- sample flags
		move.b	@sample_pitch, (@z80_sample_tbl)+		; 02h	- pitch
		move.b	@var0, (@z80_sample_tbl)+			; 03h	- start bank
		move.b	@var1, (@z80_sample_tbl)+			; 04h	- end bank
		move.b	1(sp), (@z80_sample_tbl)+			; 05h	- start offset LOW
		move.b	(sp), (@z80_sample_tbl)+			; 06h	- start offset HIGH
		move.b	3(sp), (@z80_sample_tbl)+			; 07h	- end offset LOW
		move.b	2(sp), (@z80_sample_tbl)+			; 08h	- end offset HIGH
		startZ80 (@z80_busreq)

		dbf	@sample_cnt, @ProcessSample

@Done:	; ----------------------------------------------------------------------
	; Release additional variables, registers and quit
	addq.w	#4, sp
	movem.l	(sp)+, d2-d5/a2-a4
	rts

	; ----------------------------------------------------------------------
	@WriteEmptyRecord:
		KDebug.WriteLine "Sample: <None>"
		stopZ80	(@z80_busreq)
		rept 9
			move.b	@sample_type, (@z80_sample_tbl)+
		endr
		startZ80 (@z80_busreq)

		lea	11(@sample_tbl), @sample_tbl		; skip the remaining bytes
		dbf	@sample_cnt, @ProcessSample
		bra	@Done

; ------------------------------------------------------------------------------
@Err_WAVE_InvalidHeaderFormat:
	bra	@Done

@Err_WAVE_UnsupportedAudioFormat:
	bra	@Done

@Err_WAVE_TooManyChannels:
	bra	@Done

@Err_WAVE_TooBitsPerSample:
	bra	@Done

@Err_WAVE_InvalidSampleRateForTurbo:
	bra	@Done

@Err_WAVE_UnsupportedSampleRate:
	bra	@Done

@Err_WAVE_UnableToLocateDataChunk:
	bra	@Done

@Err_PitchNotSet:
	bra	@Done

; ==============================================================================
; ------------------------------------------------------------------------------
; Mega PCM driver blob
; ------------------------------------------------------------------------------

MegaPCM:
	incbin	"../build/megapcm.bin"
MegaPCM_End:
	even
