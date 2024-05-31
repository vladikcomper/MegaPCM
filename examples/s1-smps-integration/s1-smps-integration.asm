
	include	'../lib-68k/mdshell.asm'
	include	'../build/bundle/asm68k-linkable/MegaPCM.asm'

; ------------------------------------------------------------------------------

	section rom

	xdef	Main

; ------------------------------------------------------------------------------

						rsset	$FFFF8000

Joypad:					rs.w	1
JoypadHeldTimers:		rs.b	8

Menu.SelectedItem:		rs.b	1
Menu.SelectedBGM:		rs.b	1
Menu.SelectedSFX:		rs.b	1
Menu.SelectedCMD:		rs.b	1
Menu.RedrawFlag:		rs.b	1
						rs.b	1

v_snddriver_ram:		rs.b	$600

; ------------------------------------------------------------------------------
Main:
	Console.SetXY #1, #1
	Console.WriteLine "%<pal1>Sonic 1 SMPS + Mega PCM 2 Example"
	Console.WriteLine "(c) 2024, Vladikcomper"

	; Display header
	Console.SetXY #1, #6
	Console.WriteLine "%<pal1>Sound select:"

	; Display controls
	Console.SetXY #1, #21
	Console.Write "%<pal1>Controls:%<endl>%<endl>"
	Console.WriteLine "%<pal2>   [Up/Down] %<pal0>Change selection"
	Console.WriteLine "%<pal2>[Left/Right] %<pal0>Change value (Hold)"
	Console.Write "%<pal2>[A] %<pal0>Play SFX, %<pal2>[B] %<pal0>Fade out, %<pal2>[C] %<pal0>Play"

	jsr		MegaPCM_LoadDriver

	lea		SampleTable(pc), a0
	jsr		MegaPCM_LoadSampleTable
	tst.w	d0
	bne		@SampleTableError

	moveq	#$FFFFFFE4, d0
	jsr		PlaySound
	jsr		UpdateMusic

	jsr		Menu.Init
	move.b	Menu.SelectedBGM, d0
	jsr		PlaySound

	@MainLoop:
		jsr		MDDBG__VSync
		jsr		ReadJoypads
		jsr		Menu.Update
		jsr		UpdateMusic
		bra.s	@MainLoop

; ------------------------------------------------------------------------------
@SampleTableError:
	Console.WriteLine "ERROR: MegaPCM_LoadSampleTable returned %<.b d0>"
	rts

; ------------------------------------------------------------------------------

	include	'dma-survival-test/input.asm'

; ------------------------------------------------------------------------------
; Menu subsystem
; ------------------------------------------------------------------------------

Menu.Init:
	move.b	#0, Menu.SelectedItem

	lea		Menu.Items(pc), a0

	@ItemLoop:
		move.w	(a0)+, d0			; get variable address
		beq.s	@ItemsDone			; if NULL, quit
		move.w	d0, a1
		move.b	(a0)+, (a1)			; value = min
		lea		9(a0), a0			; skip max, draw and execute functions
		bra.s	@ItemLoop
	@ItemsDone:
	; fallthrough

Menu.Redraw:
	; Render menu items
	Console.SetXY #1, #8
	lea		Menu.Items(pc), a0

	@ItemLoop:
		move.w	(a0)+, d0			; get variable address
		beq.s	@ItemsDone			; if NULL, quit
		addq.w	#2, a0				; skip min, max
		move.l	(a0)+, a1
		jsr		(a1)				; call draw function
		addq.w	#4, a0				; skip execute function
		bra.s	@ItemLoop

	@ItemsDone:

	; Render cursor
	moveq	#8, d0
	add.b	Menu.SelectedItem, d0
	Console.SetXY #1, d0
	Console.Write "%<pal2>>"

	; Mark menu redrawn
	clr.b	Menu.RedrawFlag			
	rts

; ------------------------------------------------------------------------------
Menu.Update:
	lea		Menu.InputConfig(pc), a0
	jsr		ProcessJoypadInput

	tst.b	Menu.RedrawFlag
	bne.s	Menu.Redraw
	rts

; ------------------------------------------------------------------------------
Menu.GetItemData:
	moveq	#0, d0
	move.b	Menu.SelectedItem, d0
	mulu.w	#12, d0
	lea		Menu.Items(pc, d0), a0	; a0 = item data
	movea.w	(a0), a1				; a1 = address
	move.b	(a1), d0				; d0 = value
	rts

; ------------------------------------------------------------------------------
Menu.Items:
	dc.w	Menu.SelectedBGM		; address
	dc.b	$81, $93				; min, max
	dc.l	@Draw_SelectedBGM		; draw function
	dc.l	PlaySound				; execute function

	dc.w	Menu.SelectedSFX		; address
	dc.b	$A0, $D1				; min, max
	dc.l	@Draw_SelectedSFX		; draw function
	dc.l	PlaySound				; execute function

	dc.w	Menu.SelectedCMD		; address
	dc.b	$E0, $E4				; min, max
	dc.l	@Draw_SelectedCMD		; draw function
	dc.l	PlaySound				; execute function
@Items_End:
	dc.w	0						; end of list

@Draw_SelectedBGM:
	Console.WriteLine "  %<pal2>BGM: %<pal0>%<.b Menu.SelectedBGM>"
	rts

@Draw_SelectedSFX:
	Console.WriteLine "  %<pal2>SFX: %<pal0>%<.b Menu.SelectedSFX>"
	rts

@Draw_SelectedCMD:
	Console.WriteLine "  %<pal2>CMD: %<pal0>%<.b Menu.SelectedCMD>"
	rts

; ------------------------------------------------------------------------------
Menu.NumItems:	equ	(@Items_End-Menu.Items)/12

; ------------------------------------------------------------------------------
Menu.InputConfig:
	;		Start		A			C			B
	dc.l	0,			@PlayVoice,	@ValueApply,@FadeOut
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

	;		Start		A			C			B
	dc.l	0,			0,			0,			0
	;		Right		Left		Down		Up
	dc.l	@ValueInc,	@ValueDec,	@NextItem,	@PrevItem

; ------------------------------------------------------------------------------
@NextItem:
	cmp.b	#Menu.NumItems-1, Menu.SelectedItem
	beq.s	@done
	addq.b	#1, Menu.SelectedItem
	bra.s	@setRedraw
	
@PrevItem:
	tst.b	Menu.SelectedItem
	beq.s	@done
	subq.b	#1, Menu.SelectedItem

@setRedraw:
	st.b	Menu.RedrawFlag
@done:
	rts

; ------------------------------------------------------------------------------
@ValueInc:
	bsr		Menu.GetItemData		; a0 = item data, a1 = address, d0 = value
	cmp.b	3(a0), d0				; value == max?
	beq.s	@done					; if yes, branch
	addq.b	#1, (a1)
	bra.s	@setRedraw

; ------------------------------------------------------------------------------
@ValueDec:
	bsr		Menu.GetItemData		; a0 = item data, a1 = address, d0 = value
	cmp.b	2(a0), d0				; value == min?
	beq.s	@done					; if yes, branch
	subq.b	#1, (a1)
	bra.s	@setRedraw

; ------------------------------------------------------------------------------
@ValueApply:
	bsr		Menu.GetItemData		; a0 = item data, a1 = address, d0 = value
	move.l	8(a0), a1				; a1 = execute function
	jmp		(a1)

; ------------------------------------------------------------------------------
@FadeOut:
	moveq	#$FFFFFFE0, d0
	jmp		PlaySound

; ------------------------------------------------------------------------------
@PlayVoice:
	moveq	#$FFFFFF8C, d0
	jmp		MegaPCM_PlaySample

; ------------------------------------------------------------------------------

	include	's1-smps-integration/sample-table.asm'

; ------------------------------------------------------------------------------

	pusho			; save previous options
	opt		l+		; use "." for local labels (AS compatibility)

FixBugs:	equ	1	; want to fix bugs

	include	's1-smps-integration/s1.sounddriver.defs.asm'
	include	's1-smps-integration/s1.sounddriver.asm'

PlaySound:
	move.b	d0,(v_snddriver_ram+v_soundqueue0).w
	rts

	popo			; restore previous options
