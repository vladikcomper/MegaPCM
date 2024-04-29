
	include	"load-sample-table.defs.asm"

; ==============================================================================
; ------------------------------------------------------------------------------
; Loads a given sample table to Mega PCM
; ------------------------------------------------------------------------------

MegaPCM_LoadSampleTable:

	; ----------------------------------------------------------------------
	; INPUT:
	@sample_tbl:		equr	a0	;		sample table pointer
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; OUTPUT:
	@error_code:		equr	d0	; .w	WARNING! Clashes with @var0
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; USES:
	@var0:				equr	d0	;		generic varible #1
	@var1:				equr	d1	;		generic varible #2
	@z80_sample_tbl:	equr	a1	;		position in Z80 sample table
	; ----------------------------------------------------------------------

	; ----------------------------------------------------------------------
	; INTERNAL REGISTERS:
	movem.l	d2-d5/a2-a4, -(sp)

	@sample_start:		equr	a2	;		sample start pointer
	@z80_busreq:		equr	a3	;		= Z80_BUSREQ (optimization)
	@sample_end:		equr	a4	;		sample end pointer

	@sample_cnt:		equr	d2	;		keeps track of number of samples
	@sample_pitch:		equr	d3	;		sample pitch
	@sample_flags:		equr	d4	;		sample flags
	@sample_type:		equr	d5	;		sample type
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
			move.l	(sp), \dest
		else
			inform 0, "Unsupported size: \0"
		endif
		endm
	; ----------------------------------------------------------------------

	lea		Z80_BUSREQ, @z80_busreq

	lea		Z80_RAM+Z_MPCM_SampleTable, @z80_sample_tbl
	subq.w	#4, sp						; used for fast LE->BE conversion
	moveq	#$7F-1, @sample_cnt			; load at most $7F samples (but table should have an end marker anyways!)

	@ProcessSampleLoop:
		; Fetch sample record data ...
		move.b	(@sample_tbl)+, @sample_type
		beq.w	@WriteEmptyRecord			; if type is TYPE_NONE, fill everything with zeroes
		bmi.w	@SampleTableDone			; if type is $FF, quit load loop
		move.b	(@sample_tbl)+, @sample_flags
		move.b	(@sample_tbl)+, @sample_pitch
		addq.w	#1, @sample_tbl				; skip a reserved byte
		move.l	(@sample_tbl)+, @sample_start
		move.l	(@sample_tbl)+, @sample_end

		KDebug.WriteLine "Sample: type=%<.b @sample_type>, flags=%<.b @sample_flags>, pitch=%<.b @sample_pitch>, start=%<.l @sample_start sym>, end=%<.l @sample_end sym>"

		; If sample type is DPCM, we don't have to check if it's a WAVE file
		cmp.b	#TYPE_DPCM, @sample_type
		beq.w	@WriteSampleData

		; Here, make sure sample is PCM or PCM Turbo
		cmp.b	#TYPE_PCM, @sample_type
		beq.s	@Sample_PCM_or_DPCM
		cmp.b	#TYPE_PCM_TURBO, @sample_type
		bne.w	@Err_UnknownSampleType
	@Sample_PCM_or_DPCM:

		; For TYPE_PCM and TYPE_PCM_TURBO, detect RIFF header if present
		; TODO: AIFF support?
		cmp.l	#'RIFF', (@sample_start)
		bne.w	@PCM_AlignOffsets				; if not RIFF container, assume it's raw data

		; Validate WAVE file format ...
		cmp.l	#'WAVE', 8(@sample_start)		; for RIFF containers, we only accept WAVE type
		bne.w	@Err_WAVE_InvalidHeaderFormat

		KDebug.WriteLine "Detected WAVE header"

		lea		$C(@sample_start), @sample_start; locate "fmt" chunk
		cmp.l	#'fmt ', (@sample_start)
		bne.w	@Err_WAVE_InvalidHeaderFormat
		cmp.w	#$0100, 8(@sample_start)		; is sample type uncompressed PCM ($0001 Little-endian)?
		bne.w	@Err_WAVE_BadAudioFormat		; if not, branch
		cmp.w	#$0100, $A(@sample_start)		; is number of channels 1 ($0001 Little-endian)?
		bne.w	@Err_WAVE_NotMono				; if not, branch
		cmp.w	#$0800, $16(@sample_start)		; is bits per sample 8 ($0008 Little-endian)?
		bne.w	@Err_WAVE_Not8Bit				; if not, branch

		; If pitch isn't set, auto-calucate based on WAVE sample rate ...
		tst.b	@sample_pitch					; is pitch set in the sample table?
		bne.s	@WAVE_SeekDataChunk				; if yes, don't calculate it
		@moveLE.w $C(@sample_start), @var0		; @var0 = sample rate (e.g. 22050)
		cmp.b	#TYPE_PCM_TURBO, @sample_type	; is sample TYPE_PCM_TURBO?
		bne.s	@WAVE_CalcPitch					; if not, branch
		cmp.w	#TYPE_PCM_TURBO_MAX_RATE, @var0	; TYPE_PCM_TURBO should use rate of TYPE_PCM_TURBO_MAX_RATE
		bne.w	@Err_WAVE_BadSampleRate			; if it doesn't, raise an error
		moveq	#-1, @sample_pitch				; set pitch to $FF (max)
		bra.s	@WAVE_SeekDataChunk

	@WAVE_CalcPitch:
		cmp.w	#TYPE_PCM_MAX_RATE, @var0		; TYPE_PCM should use rate <= TYPE_PCM_MAX_RATE
		bhi.w	@Err_WAVE_BadSampleRate			; if it doesn't, raise an error
		ext.l	@var0
		lsl.l	#8, @var0
		divu.w	#TYPE_PCM_BASE_RATE, @var0
		move.b	@var0, @sample_pitch

		; Locate "data" chunk ...
		@WAVE_SeekDataChunk:
			cmpa.l	@sample_end, @sample_start					; if we went outside of WAVE file
			bhs.w	@Err_WAVE_MissingDataChunk					; ... raise an exception
			@moveLE.l 4(@sample_start), @var0					; @var0 = chunk size
			KDebug.WriteLine "Seeking data chunk: Skipping %<.l @var0> bytes"
			lea		8(@sample_start, @var0.l), @sample_start	; load next chunk
			KDebug.WriteLine "Checking data chunk at %<.l @sample_start sym>"
			cmp.l	#'data', (@sample_start)					; is this a "data" chunk?
			bne		@WAVE_SeekDataChunk							; if not, repeat ...

		; Accurately detect `@sample_end` offset based on "data" chunk length ...
		@moveLE.l 4(@sample_start), @var0					; @var0 = data size
		lea		8(@sample_start, @var0.l), @sample_end		; we can now acurately detect sample's end offset
		addq.w	#8, @sample_start

		KDebug.WriteLine "WAVE data offsets: start=%<.l @sample_start sym>, end=%<.l @sample_end sym>"

	@PCM_AlignOffsets:
		; Round end offset to even address boundary if needed ...
		move.w	@sample_end, @var0
		and.w	#1, @var0
		suba.w	@var0, @sample_end					; this subtracts 1 if address was ODD, so it gets EVEN

	@WriteSampleData:
		tst.b	@sample_pitch
		beq.w	@Err_PitchNotSet					; pitch can't be zero

		; Convert absolute start/end offsets to Z80 banks and window addresses ...
		move.l	@sample_start, @var0
		add.l	@var0, @var0
		addq.w	#1, @var0							; bit 0 is always zero, so we just set it
		ror.w	#1, @var0							; @var0 LOW  = start offset | $8000
		move.w	@var0, (sp)							; stack @00  = start offset | $8000
		swap	@var0								; @var0 HIGH = start bank

		move.l	@sample_end, @var1
		add.l	@var1, @var1
		addq.w	#1, @var1							; bit 0 is always zero, so we just set it
		ror.w	#1, @var1							; @var1 LOW  = end offset | $8000
		move.w	@var1, 2(sp)						; stack @02  = end offset | $8000
		swap	@var1								; @var1 HIGH = end bank

		; We can send processed data to Mega PCM's sample table now ...
		move.w	sr, -(sp)
		move.w	#$2700, sr							; disable interrupts
		stopZ80	(@z80_busreq)
		move.b	@sample_type, (@z80_sample_tbl)+	; 00h	- sample type
		move.b	@sample_flags, (@z80_sample_tbl)+	; 01h	- sample flags
		move.b	@sample_pitch, (@z80_sample_tbl)+	; 02h	- pitch
		move.b	@var0, (@z80_sample_tbl)+			; 03h	- start bank
		move.b	@var1, (@z80_sample_tbl)+			; 04h	- end bank
		move.b	2+1(sp), (@z80_sample_tbl)+			; 05h	- start offset LOW
		move.b	2+0(sp), (@z80_sample_tbl)+			; 06h	- start offset HIGH
		move.b	2+3(sp), (@z80_sample_tbl)+			; 07h	- end offset LOW
		move.b	2+2(sp), (@z80_sample_tbl)+			; 08h	- end offset HIGH
		startZ80 (@z80_busreq)
		move.w	(sp)+, sr							; restore interrupts		

		dbf		@sample_cnt, @ProcessSampleLoop
		bra.s	@Err_TooManySamples

; ----------------------------------------------------------------------
@SampleTableDone:
	subq.w	#1, @sample_tbl					; seek the end of previous record
	moveq	#0, @error_code					; no errors to report

@Quit:
	lea		-$C(@sample_tbl), @sample_tbl	; seek the start of sample record (helps to investiage erros, if any)
	addq.w	#4, sp							; release stack variables
	movem.l	(sp)+, d2-d5/a2-a4				; release additional registers
	rts

	; ----------------------------------------------------------------------
	@WriteEmptyRecord:
		KDebug.WriteLine "Sample: <None>"
		move.w	sr, -(sp)
		move.w	#$2700, sr							; disable interrupts
		stopZ80	(@z80_busreq)
		rept 9
			move.b	@sample_type, (@z80_sample_tbl)+
		endr
		startZ80 (@z80_busreq)
		move.w	(sp)+, sr							; restore interrupts

		lea		11(@sample_tbl), @sample_tbl		; skip the remaining bytes
		dbf		@sample_cnt, @ProcessSampleLoop

	;bra.s	@Err_TooManySamples
	; fallthrough
; ------------------------------------------------------------------------------
@Err_TooManySamples:
	moveq	#MPCM_ST_TOO_MANY_SAMPLES, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_UnknownSampleType:
	moveq	#MPCM_ST_UNKNOWN_SAMPLE_TYPE, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_InvalidHeaderFormat:
	moveq	#MPCM_ST_WAVE_INVALID_HEADER, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_BadAudioFormat:
	moveq	#MPCM_ST_WAVE_BAD_AUDIO_FORMAT, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_NotMono:
	moveq	#MPCM_ST_WAVE_NOT_MONO, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_Not8Bit:
	moveq	#MPCM_ST_WAVE_NOT_8BIT, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_BadSampleRate:
	moveq	#MPCM_ST_WAVE_BAD_SAMPLE_RATE, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_WAVE_MissingDataChunk:
	moveq	#MPCM_ST_WAVE_MISSING_DATA_CHUNK, @error_code
	bra		@Quit
; ------------------------------------------------------------------------------
@Err_PitchNotSet:
	moveq	#MPCM_ST_PITCH_NOT_SET, @error_code
	bra		@Quit
