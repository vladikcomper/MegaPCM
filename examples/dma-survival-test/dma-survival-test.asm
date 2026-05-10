
	include	'../lib-68k/mdshell.asm'

	include	'../build/z80/megapcm.symbols.asm'	; import Mega PCM debug symbols for tricks

	include	'../src/68k/macros.asm'		; for MPCM_startZ80, MPCM_stopZ80
	include	'../src/68k/equates.asm'	; for MPCM_Z80_RAM etc
	include	'../src/68k/sample-table.defs.asm'	; for sample table constants

; ------------------------------------------------------------------------------
	xref	MegaPCM_LoadDriver
	xref	MegaPCM_LoadSampleTable
	xref	MegaPCM_PlaySample
	xref	MegaPCM_StopPlayback
; ------------------------------------------------------------------------------
	section rom

	xdef	Main

	; Sanity checks to allow for some optimizations
	static_assert TYPE_NONE=0
	static_assert TYPE_PCM=2
	static_assert TYPE_PCM_TURBO=4
	static_assert TYPE_DPCM=6
	static_assert TYPE_DPCM_TURBO=8
; ------------------------------------------------------------------------------
SampleTable:
	;			type			pointer		 Hz		flags			  id
	dcSample	TYPE_PCM_TURBO, BGM1,		 0,		FLAGS_LOOP		; $81
	dcSample	TYPE_PCM_TURBO, BGM2,		 0,		FLAGS_LOOP		; $82
	dcSample	TYPE_DPCM,		BGM3,		 20500,	FLAGS_LOOP		; $83
	dcSample	TYPE_PCM_TURBO, Voice,		 0						; $84
SampleTable_End:	; this label exists solely to track number of samples
	dc.w	-1	; end marker
; ------------------------------------------------------------------------------
CStr_UIBase:
	dc.b	pal1
	dc.b	'Mega PCM 2.1 - DMA Test', endl
	dc.b	'(c) 2024-2026, Vladikcomper', endl, endl, endl
	dc.b	pal1
	dc.b	'Sample Info:', endl, endl, pal2
	dc.b	'   Desc:', endl
	dc.b	'   Rate:', endl
	dc.b	'  Start:', endl
	dc.b	'    End:', endl, endl, endl
	dc.b	pal1
	dc.b	'Test settings:', endl, endl, pal2
	dc.b	'  Current Sample: ', endl
	dc.b	'  DMA Protection: ', endl
	dc.b	'      DMA Length: ', pal0, '     bytes', pal2, endl
	dc.b	'  VBlank Samples: ', pal0, '   (default:   )', endl, endl, endl
	dc.b	pal1
	dc.b	'Controls:', endl, endl, pal2
	dc.b	'   [Up/Down] ', pal0 ,'Change selection', endl, pal2
	dc.b	'[Left/Right] ', pal0 ,'Change value (Hold)', endl, pal2
	dc.b	'[A] ', pal0, 'Play  ', pal2, '[B] ', pal0, 'Stop  ', pal2, '[C] ', pal0, 'Pause'
	dc.b	0
	even
; ------------------------------------------------------------------------------
	include	'common/input.asm'	; for `ProcessJoypadInput`
; ------------------------------------------------------------------------------
						rsset	$FFFF8000
Joypad:					rs.w	1
JoypadHeldTimers:		rs.b	8
DMA_Length:				rs.w	1
DMA_Length.high:		equ		DMA_Length
DMA_Length.low:			equ		DMA_Length+1
DMA_Protection:			rs.b	1
VBlank_PCM_Samples:		rs.b	1
VBlank_PCM_SamplesLoc:	rs.l	1
VBlank_PCM_SamplesDefs:	rs.b	4		; default values
SelectedMenuItem:		rs.w	1
CurrentSample:			rs.b	1

VDP_Data:				equ 	$C00000
VDP_Ctrl:				equ 	$C00004

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	lea		CStr_UIBase(pc), a0
	jsr		MDDBG__Console_Write

	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable
	assert.w d0, eq		; `MegaPCM_LoadSampleTable` must return 00

	jsr		InitMenuRAM
	jsr		PlayAndRenderCurrentSampleInfo
	jsr		RenderTestSettings.Cursor
	jsr		RenderTestSettings.Values

	@MainLoop:
		jsr		MDDBG__VSync
		bsr		EmulateDMA
		bsr		ReadJoypads
		lea		InputConfig(pc), a0
		bsr		ProcessJoypadInput
		bra		@MainLoop

; ------------------------------------------------------------------------------
InitMenuRAM:
	moveq	#0, d0
	move.w	d0, Joypad
	move.l	d0, JoypadHeldTimers
	move.l	d0, JoypadHeldTimers+4
	move.w	d0, SelectedMenuItem
	move.b	#$81, CurrentSample

	; Dump default values for VBlank samples for each loop type
	lea		VBlankSamplesLocation+2(pc), a0
	lea		VBlank_PCM_SamplesDefs, a1
	lea		MPCM_Z80_RAM, a2
	MPCM_stopZ80
	rept 4
		move.w	(a0)+, d0
		move.b	(a2,d0.w), (a1)+
	endr
	MPCM_startZ80

	st.b	DMA_Protection				; DMA protection is on
	move.w	#$0A00, DMA_Length			; initial DMA length
	rts

; ------------------------------------------------------------------------------
EmulateDMA:
	move.b	DMA_Protection, d1
	bne.s	@dma_ok
	MPCM_stopZ80								; some emulators don't stop Z80 on ROM access during DMA
@dma_ok:
	lea		VDP_Ctrl, a0
	lea		VDP_Data-VDP_Ctrl(a0), a1
	move.w	#$8134, (a0)				; VDP => disable display
	move.l	#$C0000000, (a0)
	move.w	#$000E, (a1)				; VDP => make BG red
	move.l	#$94009300, d0
	move.b	DMA_Length.low, d0
	swap	d0
	move.b	DMA_Length.high, d0
	move.l	d0, (a0)					; VDP => Send DMA length
	move.l	#$95009600, (a0)
	move.w	#$9700, (a0)				; VDP => Send DMA source (ROM $000000)
	move.l	#$50000080, (a0)			; VDP => Start DMA at VRAM $4000 (I think)
	move.w	#$8174, (a0)				; VDP => enable display
	move.l	#$C0000000, (a0)
	move.w	#$0000, (a1)				; VDP => make BG black
	tst.b	d1
	bne.s	@dma_ok2
	MPCM_startZ80
@dma_ok2:
	rts

; ------------------------------------------------------------------------------
PlayAndRenderCurrentSampleInfo:
	; Enable DMA protection, because Mega PCM won't accept samples otherwise
	tst.b	DMA_Protection
	bne.s	@protection_ok
	bsr		EnableDMAProtection
	bsr		RenderTestSettings.Values
@protection_ok:

	moveq	#0, d0
	move.b	CurrentSample, d0
	MPCM_play d0

	; Update `VBlank_PCM_Samples` and `VBlank_PCM_SamplesLoc`
	sub.b	#$81, d0
	mulu.w	#10, d0
	lea		SampleTable(pc), a0
	adda.w	d0, a0							; a0 = sample

	moveq	#%1110, d1
	and.b	(a0), d1
	lea		MPCM_Z80_RAM, a2
	adda.w	VBlankSamplesLocation(pc, d1), a2
	move.l	a2, VBlank_PCM_SamplesLoc

	lsr.b	d1
	lea		VBlank_PCM_SamplesDefs, a2
	move.b	-1(a2, d1), d0
	move.b	d0, VBlank_PCM_Samples
	bsr		RenderTestSettings.VBlankSamplesSpecial
	; fallthrough

*RenderSampleInfo:	; a0 = sample
	jsr		GetSampleRate					; d0 = rate
	Console.SetXY #10, #7
	Console.Write "%<pal0>%<.b (a0)>%<endl>%<.w d0 dec> Hz      %<endl>%<.l 2(a0) sym>        %<endl>%<.l 6(a0) sym>        "
	rts	

; ------------------------------------------------------------------------------
VBlankSamplesLocation:
	dc.w	0								; $00 - TYPE_NONE
	dc.w	Z_MPCM_PCMLoop_VBlank+3			; $02 - TYPE_PCM
	dc.w	Z_MPCM_PCMTurboLoop_VBlank+3	; $04 - TYPE_PCM_TURBO
	dc.w	Z_MPCM_DPCMLoop_VBlank+4		; $06 - TYPE_DPCM
	dc.w	Z_MPCM_DPCMTurboLoop_VBlank+4	; $08 - TYPE_DPCM_TURBO
	dc.w	0								; $0A - <invalid>
	dc.w	0								; $0C - <invalid>
	dc.w	0								; $0E - <invalid>

; ------------------------------------------------------------------------------
GetSampleRate:
	moveq	#%1110, d0
	and.b	(a0), d0
	move.w	@BaseSampleRate(pc,d0), d0
	bgt.s	@CalcRate					; branch if not zero and positive
	neg.w	d0
	rts

@CalcRate:
	moveq	#0, d1
	move.b	1(a0), d1
	mulu.w	d0, d1
	lsr.l	#8, d1
	move.w	d1, d0
	rts

; ------------------------------------------------------------------------------
@BaseSampleRate:	; negative values indicate fixed rate
	dc.w	 0								; $00 - TYPE_NONE
	dc.w	 TYPE_PCM_BASE_RATE				; $02 - TYPE_PCM
	dc.w	-TYPE_PCM_TURBO_MAX_RATE		; $04 - TYPE_PCM_TURBO
	dc.w	 TYPE_DPCM_BASE_RATE			; $06 - TYPE_DPCM
	dc.w	-TYPE_DPCM_TURBO_MAX_RATE		; $08 - TYPE_DPCM_TURBO
	dc.w	 0								; $0A - <invalid>
	dc.w	 0								; $0C - <invalid>
	dc.w	 0								; $0E - <invalid>

; ------------------------------------------------------------------------------
InputConfig:
	;		Start		A			C			B
	dc.l	0,			@Play,		@Pause,		@Stop
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

	;		Start		A			C			B
	dc.l	0,			0,			0,			0
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

; ------------------------------------------------------------------------------
@Pause:
	lea		MPCM_Z80_RAM+Z_MPCM_CommandInput, a0
	MPCM_stopZ80
	move.b	(a0), d0
	subq.b	#Z_MPCM_COMMAND_PAUSE, d0
	beq.s	@0
	moveq	#Z_MPCM_COMMAND_PAUSE, d0
@0:	move.b	d0, (a0)
	MPCM_startZ80
	rts
; ------------------------------------------------------------------------------
@Play:	equ	PlayAndRenderCurrentSampleInfo
; ------------------------------------------------------------------------------
@Stop:	equ	MegaPCM_StopPlayback

; ------------------------------------------------------------------------------
@NextItem:
	addq.w	#1, SelectedMenuItem
	and.w	#3, SelectedMenuItem
	bra		RenderTestSettings.Cursor
; ------------------------------------------------------------------------------
@PrevItem:
	subq.w	#1, SelectedMenuItem
	and.w	#3, SelectedMenuItem
	bra		RenderTestSettings.Cursor
; ------------------------------------------------------------------------------
@ValueInc:
	move.w	SelectedMenuItem, d0
	lsl.w	#3, d0
	addq.w	#4, d0
	bra.s	@1
; ------------------------------------------------------------------------------
@ValueDec:
	move.w	SelectedMenuItem, d0
	lsl.w	#3, d0
@1:	movea.l	@ValueConfig(pc, d0), a0
	jsr		(a0)
	bra		RenderTestSettings.Values
; ------------------------------------------------------------------------------
@CancelValuesRedraw:
	addq.w	#4, sp
	rts

; ------------------------------------------------------------------------------
@ValueConfig:
	dc.l	@CurrentSampleDec,	@CurrentSampleInc
	dc.l	@DMAProtectionOff,	@DMAProtectionOn
	dc.l	@DMALengthDec,		@DMALengthInc
	dc.l	@VBlankSamplesDec,	@VBlankSamplesInc

; ------------------------------------------------------------------------------
@CurrentSampleDec:
	cmp.b	#$81, CurrentSample
	beq.s	@CancelValuesRedraw
	subq.b	#1, CurrentSample
	rts
; ------------------------------------------------------------------------------
@CurrentSampleInc:
	cmp.b	#$80+(SampleTable_End-SampleTable)/10, CurrentSample
	beq.s	@CancelValuesRedraw
	add.b	#1, CurrentSample
	rts
; ------------------------------------------------------------------------------
@DMAProtectionOff:
	sf.b	DMA_Protection
	MPCM_stopZ80
	move.b	#$C9, MPCM_Z80_RAM+Z_MPCM_VBlank		; `RET`
	MPCM_startZ80
	rts
; ------------------------------------------------------------------------------
@DMAProtectionOn:
	st.b	DMA_Protection
	MPCM_stopZ80
	move.b	#$C3, MPCM_Z80_RAM+Z_MPCM_VBlank		; `JP (nnn)`
	MPCM_startZ80
	rts
; ------------------------------------------------------------------------------
@DMALengthDec:
	cmp.w	#$80, DMA_Length
	beq		@CancelValuesRedraw
	sub.w	#$80, DMA_Length
	rts
; ------------------------------------------------------------------------------
@DMALengthInc:
	cmp.w	#$3000, DMA_Length
	beq		@CancelValuesRedraw
	add.w	#$80, DMA_Length
	rts
; ------------------------------------------------------------------------------
@VBlankSamplesDec:
	cmp.b	#1, VBlank_PCM_Samples
	beq		@CancelValuesRedraw
	subq.b	#1, VBlank_PCM_Samples

@setsamples:
	movea.l	VBlank_PCM_SamplesLoc, a0
	MPCM_stopZ80
	move.b	VBlank_PCM_Samples, (a0)
	MPCM_startZ80
	rts
; ------------------------------------------------------------------------------
@VBlankSamplesInc:
	cmp.b	#$FF, VBlank_PCM_Samples
	beq		@CancelValuesRedraw
	add.b	#1, VBlank_PCM_Samples
	bra.s	@setsamples

; ------------------------------------------------------------------------------
EnableDMAProtection: equ	@DMAProtectionOn

; ------------------------------------------------------------------------------
CStr_MenuCursors:
	dc.b	'>', endl, ' ', endl, ' ', endl, ' ', 0	; $00
	dc.b	' ', endl, '>', endl, ' ', endl, ' ', 0	; $08
	dc.b	' ', endl, ' ', endl, '>', endl, ' ', 0	; $10
	dc.b	' ', endl, ' ', endl, ' ', endl, '>', 0	; $18
; ------------------------------------------------------------------------------
CStr_MenuBooleanLabels:
	dc.b	'OFF',0
	dc.b	'ON ',0
; ------------------------------------------------------------------------------
RenderTestSettings.Cursor:
	Console.SetXY #1, #15
	moveq	#3, d0
	and.w	SelectedMenuItem, d0
	lsl.w	#3, d0
	lea		CStr_MenuCursors(pc,d0), a0
	Console.Write "%<pal2>%<.l a0 str>"
	rts

; ------------------------------------------------------------------------------
RenderTestSettings.Values:
	Console.SetXY #19, #15
	move.w	DMA_Length, d0
	add.w	d0, d0
	moveq	#4, d1
	and.b	DMA_Protection, d1
	lea		CStr_MenuBooleanLabels(pc, d1), a1
	Console.Write "%<pal0>%<.b CurrentSample>%<endl>%<.l a1 str>%<endl>%<.w d0>%<endl>%<.b VBlank_PCM_Samples>"
	rts

; ------------------------------------------------------------------------------
RenderTestSettings.VBlankSamplesSpecial:	; d0 = default VBlank samples
	Console.SetXY #19, #18
	Console.Write "%<pal0>%<.b VBlank_PCM_Samples>%<setx,32>%<.b d0>"
	rts

; ------------------------------------------------------------------------------
	incdac	BGM1, 'common/bgm1.wav'
	dc.b	0	; padding for debug purposes: so start/end symbols won't collide
	incdac	BGM2, 'common/bgm2.wav'
	dc.b	0
	incdac	BGM3, 'common/bgm3.dpcmq'
	dc.b	0
	incdac	Voice, 'common/voice.wav'
	dc.b	0