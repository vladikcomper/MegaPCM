
	include	'../lib-68k/mdshell.asm'

	include	'../build/z80/megapcm.symbols.asm'	; import Mega PCM debug symbols for tricks

	include	'../src/68k/macros.asm'		; for startZ80, stopZ80
	include	'../src/68k/vars.asm'		; for Z80_RAM etc

; ------------------------------------------------------------------------------

	xref	MegaPCM_LoadDriver
	xref	MegaPCM_LoadSampleTable
	xref	MegaPCM_PlaySample
	xref	MegaPCM_StopPlayback

; ------------------------------------------------------------------------------

	section rom

	xdef	Main

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
SelectedMenuItem:		rs.w	1
FrameCounter:			rs.w	1
MenuRedrawFlag:			rs.b	1

VDP_Data:				equ 	$C00000
VDP_Ctrl:				equ 	$C00004

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Mega PCM 2.0 - DMA Test"
	Console.WriteLine "(c) 2024, Vladikcomper"

	jsr		MegaPCM_LoadDriver
	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable

	assert.w d0, eq		; `MegaPCM_LoadSampleTable` must return 00

	jsr		InitConfig

	; Display sample info
	lea		SampleTable+0(pc), a0
	jsr		GetSampleRate					; d0 = rate
	Console.SetXY #1, #5
	Console.Write "%<pal1>Sample Info:%<endl>%<endl>"
	Console.WriteLine "%<pal2>   Type: %<pal0>%<.b (a0)>"
	Console.WriteLine "%<pal2>  Flags: %<pal0>%<.b 1(a0)>"
	Console.WriteLine "%<pal2>   Rate: %<pal0>%<.w d0 dec> Hz"
	Console.WriteLine "%<pal2>  Start: %<pal0>%<.l 4(a0) sym>"
	Console.WriteLine "%<pal2>    End: %<pal0>%<.l 8(a0) sym>%<endl>"

	; Display controls
	Console.SetXY #1, #21
	Console.Write "%<pal1>Controls:%<endl>%<endl>"
	Console.WriteLine "%<pal2>   [Up/Down] %<pal0>Change selection"
	Console.WriteLine "%<pal2>[Left/Right] %<pal0>Change value (Hold)"
	Console.Write "%<pal2>[A] %<pal0>Restart, %<pal2>[B] %<pal0>Pause, %<pal2>[C] %<pal0>Stop"

	; Start playback
	move.b	#$81, d0
	jsr		MegaPCM_PlaySample

	jsr		RenderMenu

	@MainLoop:
		jsr		MDDBG__VSync
		addq.w	#1, FrameCounter

		; Execute DMA
		move.b	DMA_Protection, d1
		bne.s	@dma_ok
		stopZ80								; some emulators don't stop Z80 on ROM access during DMA
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
		startZ80
	@dma_ok2:

		; Update menu logic
		jsr		ReadJoypads
		lea		InputConfig(pc), a0
		jsr		ProcessJoypadInput

		tst.b	MenuRedrawFlag
		beq.s	@skip_redraw
		jsr		UpdateMenu(pc)
	@skip_redraw:

		bra		@MainLoop

; ------------------------------------------------------------------------------
InitConfig:
	moveq	#0, d0
	move.w	d0, Joypad
	move.l	d0, JoypadHeldTimers
	move.l	d0, JoypadHeldTimers+4
	move.w	d0, FrameCounter
	move.w	d0, SelectedMenuItem

	st.b	DMA_Protection				; DMA protection is on
	move.w	#$0A00, DMA_Length			; initial DMA length
	
	moveq	#0, d0
	move.b	SampleTable+0(pc), d0		; d0 = sample type
	lea		@VBlankSamplesLocation, a0

	@getVBlankSamplesLocation:
		cmp.w	(a0)+, d0
		bne.s	@getVBlankSamplesLocation

	addq.w	#6-2, a0
	lea		Z80_RAM, a1
	adda.w	(a0), a1
	move.l	a1, VBlank_PCM_SamplesLoc

	stopZ80
	move.b	(a1), VBlank_PCM_Samples
	startZ80
	rts

; ------------------------------------------------------------------------------
@VBlankSamplesLocation:
	dc.w	TYPE_PCM						; type 1
	dc.w	TYPE_DPCM						; type 2
	dc.w	TYPE_PCM_TURBO					; type 3
	dc.w	Z_MPCM_PCMLoop_VBlank+3			; location for type 1
	dc.w	Z_MPCM_DPCMLoop_VBlank+3		; location for type 2
	dc.w	Z_MPCM_PCMTurboLoop_VBlank+3	; location for type 3

; ------------------------------------------------------------------------------
GetSampleRate:
	cmp.b	#TYPE_PCM_TURBO, (a0)
	bne.s	@chk_pcm
	move.w	#32000, d0
	rts

@chk_pcm:
	cmp.b	#TYPE_PCM, (a0)
	bne.s	@chk_dpcm
	moveq	#0, d0
	move.b	2(a0), d0						; d0 = pitch (00..FF)
	mulu.w	#TYPE_PCM_BASE_RATE, d0			; d0 = pitch * base_rate
	lsr.l	#8, d0
	rts

@chk_dpcm:
	cmp.b	#TYPE_DPCM, (a0)
	bne.s	@unknown
	moveq	#0, d0
	move.b	2(a0), d0						; d0 = pitch (00..FF)
	mulu.w	#TYPE_DPCM_BASE_RATE, d0		; d0 = pitch * base_rate
	lsr.l	#8, d0
	rts

@unknown:
	moveq	#0, d0			; NOT SUPPORTED
	rts


; ------------------------------------------------------------------------------

	include	'dma-survival-test/input.asm'

; ------------------------------------------------------------------------------
InputConfig:
	;		Start		A			C			B
	dc.l	0,			@Play,		@Stop,		@PauseToggle
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

	;		Start		A			C			B
	dc.l	0,			0,			0,			0
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

; ------------------------------------------------------------------------------
@PauseToggle:
	lea		Z80_RAM+Z_MPCM_CommandInput, a0
	stopZ80
	move.b	(a0), d0
	subq.b	#Z_MPCM_COMMAND_PAUSE, d0
	beq.s	@unpause
	moveq	#Z_MPCM_COMMAND_PAUSE, d0

@unpause:
	move.b	d0, (a0)
	startZ80
	KDebug.WriteLine "Pause state = %<.b d0>"
	rts

; ------------------------------------------------------------------------------
@Play:
	move.b	#$81, d0
	jmp		MegaPCM_PlaySample

; ------------------------------------------------------------------------------
@Stop:
	jmp		MegaPCM_StopPlayback

; ------------------------------------------------------------------------------
@NextItem:
	cmp.w	#2, SelectedMenuItem
	beq.s	@done
	addq.w	#1, SelectedMenuItem
	bra.s	@setredraw
	
@PrevItem:
	tst.w	SelectedMenuItem
	beq.s	@done
	subq.w	#1, SelectedMenuItem

@setredraw:
	st.b	MenuRedrawFlag
@done:
	rts

@ValueInc:
	move.w	SelectedMenuItem, d0
	lsl.w	#3, d0
	addq.w	#4, d0
	bra.s	@run

@ValueDec:
	move.w	SelectedMenuItem, d0
	lsl.w	#3, d0

@run:
	move.l	@ValueConfig(pc, d0), a0
	jmp		(a0)

@ValueConfig:
	dc.l	@DMAProtectionOff,	@DMAProtectionOn
	dc.l	@DMALengthDec,		@DMALengthInc
	dc.l	@VBlankSamplesDec,	@VBlankSamplesInc

@DMAProtectionOff:
	sf.b	DMA_Protection
	stopZ80
	move.b	#$C9, Z80_RAM+Z_MPCM_VBlank		; `RET`
	startZ80
	bra.s	@setredraw

@DMAProtectionOn:
	st.b	DMA_Protection
	stopZ80
	move.b	#$C3, Z80_RAM+Z_MPCM_VBlank		; `JP (nnn)`
	startZ80
	bra		@setredraw

@DMALengthDec:
	cmp.w	#$80, DMA_Length
	beq		@done
	sub.w	#$80, DMA_Length
	bra		@setredraw

@DMALengthInc:
	cmp.w	#$3000, DMA_Length
	beq		@done
	add.w	#$80, DMA_Length
	bra		@setredraw

@VBlankSamplesDec:
	cmp.b	#1, VBlank_PCM_Samples
	beq		@done
	subq.b	#1, VBlank_PCM_Samples

@setsamples:
	movea.l	VBlank_PCM_SamplesLoc, a0
	stopZ80
	move.b	VBlank_PCM_Samples, (a0)
	startZ80
	bra		@setredraw

@VBlankSamplesInc:
	cmp.b	#$FF, VBlank_PCM_Samples
	beq		@done
	add.b	#1, VBlank_PCM_Samples
	bra.s	@setsamples

; ------------------------------------------------------------------------------
MenuBase:
	dc.b	pal1, 'Test settings:', endl, endl
	dc.b	pal2, '  DMA Protection: ', endl
	dc.b	pal2, '      DMA Length: ', pal0, '     bytes', endl
	dc.b	pal2, '  VBlank Samples: ', endl
	dc.b	0

MenuCursors:
	dc.b	pal2, '>', endl, ' ', endl, ' ', pal0, 0	; $00
	dc.b	pal2, ' ', endl, '>', endl, ' ', pal0, 0	; $08
	dc.b	pal2, ' ', endl, ' ', endl, '>', pal0, 0	; $10
	even

; ------------------------------------------------------------------------------
RenderMenu:
	Console.SetXY #1, #14
	lea		MenuBase(pc), a0
	jsr		MDDBG__Console_Write
	;fallthrough

; ------------------------------------------------------------------------------
UpdateMenu:
	sf.b	MenuRedrawFlag

	; Draw selected menu item
	Console.SetXY #1, #16
	moveq	#3, d0
	and.w	SelectedMenuItem, d0
	lsl.w	#3, d0
	lea		MenuCursors(pc,d0), a0
	jsr		MDDBG__Console_Write

	; Redraw "VBlank PCM Samples:" value
	Console.SetXY #3+16, #18
	Console.Write "%<.b VBlank_PCM_Samples>"

	; Redraw "DMA Length:" value (convert words to bytes)
	Console.SetXY #3+16, #17
	move.w	DMA_Length, d0
	add.w	d0, d0
	Console.Write "%<.w d0>"

	; Redraw "DMA protection:" value
	Console.SetXY #3+16, #16
	tst.b	DMA_Protection
	beq.s	@DMA_Protection_Off
	Console.Write "ON "
	rts

@DMA_Protection_Off:
	Console.Write "OFF"
	rts

; ------------------------------------------------------------------------------
; Default sample table
; ------------------------------------------------------------------------------

	include	'../src/68k/sample-table.defs.asm'	; for constants
	include	'../src/Macros.ASM68K.asm'			; for dcSample, incdac

SampleTable:
	;			type			pointer		 Hz		flags			  id
	dcSample	TYPE_PCM_TURBO, MusicSample, 32000,	FLAGS_LOOP		; $81
	dc.w	-1	; end marker

; ------------------------------------------------------------------------------

	incdac	MusicSample, 'dma-survival-test/music.wav'
