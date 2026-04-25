; ===============================================================
; ---------------------------------------------------------------
; MD Shell v.2.6
;
; (c) 2023-2024, Vladikcomper
; ---------------------------------------------------------------


; ---------------------------------------------------------------
; Debugger customization
; ---------------------------------------------------------------

; VBlank interrupt handler (default is "IdleInt", which returns immediately)
MDSHELL__VBLANK_HANDLER:				equ		MDDBG__IdleInt

; HBlank interrupt handler (default is "IdleInt", which returns immediately)
MDSHELL__HBLANK_HANDLER:				equ		MDDBG__IdleInt

; Enable debugger extensions
; Pressing A/B/C on the exception screen can open other debuggers
; Pressing Start or unmapped button returns to the exception
DEBUGGER__EXTENSIONS__ENABLE:			equ		1		; 0 = OFF, 1 = ON (default)

; Whether to show SR and USP registers in exception handler
DEBUGGER__SHOW_SR_USP:					equ		0		; 0 = OFF (default), 1 = ON

; Debuggers mapped to pressing A/B/C on the exception screen
; Use 0 to disable button, use debugger's entry point otherwise.
DEBUGGER__EXTENSIONS__BTN_A_DEBUGGER:	equ		MDDBG__Debugger_AddressRegisters	; display address register symbols
DEBUGGER__EXTENSIONS__BTN_B_DEBUGGER:	equ		MDDBG__Debugger_Backtrace			; display exception backtrace
DEBUGGER__EXTENSIONS__BTN_C_DEBUGGER:	equ		0		; disabled

; Selects between 24-bit (compact) and 32-bit (full) offset format.
; This affects offset format next to the symbols in the exception screen header.
; M68K bus is limited to 24 bits anyways, so not displaying unused bits saves screen space.
; Possible values:
; - MDDBG__Str_OffsetLocation_24bit (example: 001C04 SomeLoc+4)
; - MDDBG__Str_OffsetLocation_32bit (example: 00001C04 SomeLoc+4)
DEBUGGER__STR_OFFSET_SELECTOR:			equ		MDDBG__Str_OffsetLocation_24bit



; ===============================================================
; ---------------------------------------------------------------
; Constants
; ---------------------------------------------------------------

; ----------------------------
; Arguments formatting flags
; ----------------------------

; General arguments format flags
hex		equ		$80				; flag to display as hexadecimal number
dec		equ		$90				; flag to display as decimal number
bin		equ		$A0				; flag to display as binary number
sym		equ		$B0				; flag to display as symbol (treat as offset, decode into symbol +displacement, if present)
symdisp	equ		$C0				; flag to display as symbol's displacement alone (DO NOT USE, unless complex formatting is required, see notes below)
str		equ		$D0				; flag to display as string (treat as offset, insert string from that offset)

; NOTES:
;	* By default, the "sym" flag displays both symbol and displacement (e.g.: "Map_Sonic+$2E")
;		In case, you need a different formatting for the displacement part (different text color and such),
;		use "sym|split", so the displacement won't be displayed until symdisp is met
;	* The "symdisp" can only be used after the "sym|split" instance, which decodes offset, otherwise, it'll
;		display a garbage offset.
;	* No other argument format flags (hex, dec, bin, str) are allowed between "sym|split" and "symdisp",
;		otherwise, the "symdisp" results are undefined.
;	* When using "str" flag, the argument should point to string offset that will be inserted.
;		Arguments format flags CAN NOT be used in the string (as no arguments are meant to be here),
;		only console control flags (see below).


; Additional flags ...
; ... for number formatters (hex, dec, bin)
signed	equ		8				; treat number as signed (display + or - before the number depending on sign)

; ... for symbol formatter (sym)
split	equ		8				; DO NOT write displacement (if present), skip and wait for "symdisp" flag to write it later (optional)
forced	equ		4				; display "<unknown>" if symbol was not found, otherwise, plain offset is displayed by the displacement formatter

; ... for symbol displacement formatter (symdisp)
weak	equ		8				; DO NOT write plain offset if symbol is displayed as "<unknown>"

; Argument type flags:
; - DO NOT USE in formatted strings processed by macros, as these are included automatically
; - ONLY USE when writting down strings manually with DC.B
byte	equ		0
word	equ		1
long	equ		3

; -----------------------
; Console control flags
; -----------------------

; Plain control flags: no arguments following
endl	equ		$E0				; "End of line": flag for line break
cr		equ		$E6				; "Carriage return": jump to the beginning of the line
pal0	equ		$E8				; use palette line #0
pal1	equ		$EA				; use palette line #1
pal2	equ		$EC				; use palette line #2
pal3	equ		$EE				; use palette line #3

; Parametrized control flags: followed by 1-byte argument
setw	equ		$F0				; set line width: number of characters before automatic line break
setoff	equ		$F4				; set tile offset: lower byte of base pattern, which points to tile index of ASCII character 00
setpat	equ		$F8				; set tile pattern: high byte of base pattern, which determines palette flags and $100-tile section id
setx	equ		$FA				; set x-position

; -----------------------------
; Error handler control flags
; -----------------------------

; Screen appearence flags
_eh_address_error	equ	$01		; use for address and bus errors only (tells error handler to display additional "Address" field)
_eh_show_sr_usp		equ	$02		; displays SR and USP registers content on error screen
_eh_hide_caller		equ	$04		; don't guess and print caller in the header (in SGDK and C/C++ projects naive caller detection isn't reliable)

; Advanced execution flags
; WARNING! For experts only, DO NOT USE them unless you know what you're doing
_eh_return			equ	$20
_eh_enter_console	equ	$40
_eh_align_offset	equ	$80



; ---------------------------------------------------------------
; Macros
; ---------------------------------------------------------------


; ---------------------------------------------------------------
; WARNING! This disables automatic padding in order to combine DC.B's correctly
;	Make sure your code doesn't rely on padding (enabled by default)!
; ---------------------------------------------------------------

	padding off
	supmode on				; bypass warnings on privileged instructions

; ---------------------------------------------------------------
; Creates compile-time assertions
; ---------------------------------------------------------------
; EXAMPLES:
;	static_assert def(__DEBUG__)
;	static_assert MY_CONST=42
; ---------------------------------------------------------------

static_assert:	macro EXPR
	if VAL(EXPR)
	else
		!error "Assertion failed: EXPR"
	endif
	endm


; ---------------------------------------------------------------
; Creates run-time assertions for debugging
; ---------------------------------------------------------------
; NOTE:
;	Run-time asserts only work if `__DEBUG__` is defined.
;
; EXAMPLES:
;	assert.b	d0, eq, #1		; d0 must be $01, or else crash
;	assert.w	d5, pl			; d5 must be positive
;	assert.l	a1, hi, a0		; assert a1 > a0, or else crash
;	assert.b	(MemFlag).w, ne	; MemFlag must be set (non-zero)
;	assert.l	a0, eq, #Obj_Player, MyObjectsDebugger
;
; NOTICE:
;	All "assert" saves and restores CCR so it's fully safe
;	to use in-between any instructions.
;	Use "_assert" instead if you deliberatly want to disbale
;	this behavior and safe a few cycles.
; ---------------------------------------------------------------

assert:	macro	src, cond, dest, consoleprogram
		move.w	sr, -(sp)
		_assert.ATTRIBUTE	src, cond, dest, consoleprogram
		move.w	(sp)+, sr
		endm

; Same as "assert", but doesn't save/restore CCR (can be used to save a few cycles)
_assert:	macro	src, cond, dest, consoleprogram
		if "dest"<>""
			cmp.ATTRIBUTE	dest, src
		else
			tst.ATTRIBUTE	src
		endif

		switch lowstring("cond")
		case "eq"
			beq	.skip
		case "ne"
			bne	.skip
		case "cs"
			bcs	.skip
		case "cc"
			bcc	.skip
		case "pl"
			bpl	.skip
		case "mi"
			bmi	.skip
		case "hi"
			bhi	.skip
		case "hs"
			bhs	.skip
		case "ls"
			bls	.skip
		case "lo"
			blo	.skip
		case "gt"
			bgt	.skip
		case "ge"
			bge	.skip
		case "le"
			ble	.skip
		case "lt"
			blt	.skip
		case "vs"
			bvs	.skip
		case "vc"
			bvc	.skip
		elsecase
			!error "Unknown condition cond"
		endcase

	if "dest"<>""
		RaiseError	"Assertion failed:%<endl>%<pal2>> assert.ATTRIBUTE %<pal0>src,%<pal2>cond%<pal0>,dest%<endl>%<pal1>Got: %<.ATTRIBUTE src>", consoleprogram
	else
		RaiseError	"Assertion failed:%<endl>%<pal2>> assert.ATTRIBUTE %<pal0>src,%<pal2>cond%<endl>%<pal1>Got: %<.ATTRIBUTE src>", consoleprogram
	endif

	.skip:
    endm

; ---------------------------------------------------------------
; Raises an error with the given message
; ---------------------------------------------------------------
; EXAMPLES:
;	RaiseError	"Something is wrong"
;	RaiseError	"Your D0 value is BAD: %<.w d0>"
;	RaiseError	"Module crashed! Extra info:", YourMod_Debugger
; ---------------------------------------------------------------

RaiseError:	macro	string, consoleprogram, opts
	pea		*(pc)
	move.w	sr, -(sp)
	__FSTRING_GenerateArgumentsCode string
	jsr		MDDBG__ErrorHandler
	__FSTRING_GenerateDecodedString string, 0 ; 0 = no automatic newline
	if ("consoleprogram"<>"")			; if console program offset is specified ...
		.__align_flag:	set	((((*)&1)!1)*_eh_align_offset)
		if "opts"<>""
			dc.b	opts+_eh_enter_console|.__align_flag					; add flag "_eh_align_offset" if the next byte is at odd offset ...
		else
			dc.b	_eh_enter_console|.__align_flag						; ''
		endif
		!align	2													; ... to tell Error handler to skip this byte, so it'll jump to ...
		if DEBUGGER__EXTENSIONS__ENABLE
			jsr		consoleprogram										; ... an aligned "jsr" instruction that calls console program itself
			jmp		MDDBG__ErrorHandler_PagesController
		else
			jmp		consoleprogram										; ... an aligned "jmp" instruction that calls console program itself
		endif
	else
		if DEBUGGER__EXTENSIONS__ENABLE
			.__align_flag:	set	((((*)&1)!1)*_eh_align_offset)
			if "opts"<>""
				dc.b	opts+_eh_return|.__align_flag					; add flag "_eh_align_offset" if the next byte is at odd offset ...
			else
				dc.b	_eh_return|.__align_flag							; add flag "_eh_align_offset" if the next byte is at odd offset ...
			endif
			!align	2													; ... to tell Error handler to skip this byte, so it'll jump to ...
			jmp		MDDBG__ErrorHandler_PagesController
		else
			dc.b	opts+0						; otherwise, just specify \opts for error handler, +0 will generate dc.b 0 ...
			!align	2							; ... in case \opts argument is empty or skipped
		endif
	endif
	!align	2
	endm


; ---------------------------------------------------------------
; Console interface
; ---------------------------------------------------------------
; EXAMPLES:
;	Console.Write "Hello "
;	Console.WriteLine "...world!"
;	Console.WriteLine "Your data is %<.b d0>"
;	Console.WriteLine "%<pal0>Your code pointer: %<.l a0 sym>"
;	Console.SetXY #1, #4
;	Console.SetXY d0, d1
;	Console.Sleep #60 ; sleep for 1 second
;	Console.Pause
;
; NOTICE:
;	All "Console.*" calls save and restore CCR so they are fully
;	safe to use in-between any instructions.
;	Use "_Console.*" instead if you deliberatly want to disbale
;	this behavior and safe a few cycles.
; ---------------------------------------------------------------

Console:	macro	argument1, argument2
	switch lowstring("ATTRIBUTE")
	; "Console.Run" doesn't have to save/restore CCR, because it's a no-return
	case "run"
		_Console.ATTRIBUTE	argument1, argument2

	; Other Console calls do save/restore CCR
	elsecase
		move.w	sr, -(sp)
		_Console.ATTRIBUTE	argument1, argument2
		move.w	(sp)+, sr
	endcase
	endm

; Same as "Console", but doesn't save/restore CCR (can be used to save a few cycles)
_Console:	macro	argument1, argument2
	switch lowstring("ATTRIBUTE")
	case "write"
		__FSTRING_GenerateArgumentsCode argument1

		; If we have any arguments in string, use formatted string function ...
		if (.__sp>0)
			movem.l	a0-a2/d7, -(sp)
			lea		4*4(sp), a2
			lea		.__data(pc), a1
			jsr		MDDBG__Console_Write_Formatted
			movem.l	(sp)+, a0-a2/d7
			if (.__sp>8)
				lea		.__sp(sp), sp
			elseif (.__sp>0)
				addq.w	#.__sp, sp
			endif

		; ... Otherwise, use direct write as an optimization
		else
			move.l	a0, -(sp)
			lea		.__data(pc), a0
			jsr		MDDBG__Console_Write
			move.l	(sp)+, a0
		endif

		bra.w	.__leave
	.__data:
		__FSTRING_GenerateDecodedString argument1, 0 ; 0 = no automatic newline
		!align	2
	.__leave:

	case "writeline"
		__FSTRING_GenerateArgumentsCode argument1

		; If we have any arguments in string, use formatted string function ...
		if (.__sp>0)
			movem.l	a0-a2/d7, -(sp)
			lea		4*4(sp), a2
			lea		.__data(pc), a1
			jsr		MDDBG__Console_Write_Formatted
			movem.l	(sp)+, a0-a2/d7
			if (.__sp>8)
				lea		.__sp(sp), sp
			elseif (.__sp>0)
				addq.w	#.__sp, sp
			endif
		; ... Otherwise, use direct write as an optimization
		else
			move.l	a0, -(sp)
			lea		.__data(pc), a0
			jsr		MDDBG__Console_Write
			move.l	(sp)+, a0
		endif
		bra.w	.__leave
	.__data:
		__FSTRING_GenerateDecodedString argument1, 1 ; 1 = automatic newline at the end
		!align	2
	.__leave:

	case "clear"
		jsr		MDDBG__ErrorHandler_ClearConsole

	case "pause"
		jsr		MDDBG__ErrorHandler_PauseConsole

	case "sleep"
		move.w	d0, -(sp)
		move.l	a0, -(sp)
		move.w	argument1, d0
		subq.w	#1, d0
		bcs.s	.__sleep_done
		.__sleep_loop:
			jsr		MDDBG__VSync
			dbf		d0, .__sleep_loop

	.__sleep_done:
		move.l	(sp)+, a0
		move.w	(sp)+, d0

	case "setxy"
		movem.l	d0-d1, -(sp)
		move.w	argument2, -(sp)
		move.w	argument1, -(sp)
		jsr		MDDBG__Console_SetPosAsXY_Stack
		addq.w	#4, sp
		movem.l	(sp)+, d0-d1

	case "breakline"
		jsr		MDDBG__Console_StartNewLine

	elsecase
		!error	"ATTRIBUTE isn't a member of Console"

	endcase
	endm

; ---------------------------------------------------------------
; KDebug integration interface
; ---------------------------------------------------------------
; EXAMPLES:
;	KDebug.WriteLine "Look in your debug console!"
;	KDebug.WriteLine "Your D0 is %<.w d0>"
;	KDebug.BreakPoint
;	KDebug.StartTimer
;	KDebug.EndTimer
;
; NOTICE:
;	All "KDebug.*" calls save and restore CCR so they are fully
;	safe to use in-between any instructions.
;	Use "_KDebug.*" instead if you deliberatly want to disbale
;	this behavior and safe a few cycles.
; ---------------------------------------------------------------

KDebug:	macro	argument1
		move.w	sr, -(sp)
		_KDebug.ATTRIBUTE	argument1
		move.w	(sp)+, sr
	endm

; Same as "KDebug", but doesn't save/restore CCR (can be used to save a few cycles)
_KDebug	macro	argument1
	switch lowstring("ATTRIBUTE")
	case "write"
		__FSTRING_GenerateArgumentsCode argument1

		; If we have any arguments in string, use formatted string function ...
		if (.__sp>0)
			movem.l	a0-a2/d7, -(sp)
			lea		4*4(sp), a2
			lea		.__data(pc), a1
			jsr		MDDBG__KDebug_Write_Formatted
			movem.l	(sp)+, a0-a2/d7
			if (.__sp>8)
				lea		.__sp(sp), sp
			elseif (.__sp>0)
				addq.w	#.__sp, sp
			endif

		; ... Otherwise, use direct write as an optimization
		else
			move.l	a0, -(sp)
			lea		.__data(pc), a0
			jsr		MDDBG__KDebug_Write
			move.l	(sp)+, a0
		endif

		bra.w	.__leave
	.__data:
		__FSTRING_GenerateDecodedString argument1, 0 ; 0 = no automatic newline
		!align	2
	.__leave:

	case "writeline"
		__FSTRING_GenerateArgumentsCode argument1

		; If we have any arguments in string, use formatted string function ...
		if (.__sp>0)
			movem.l	a0-a2/d7, -(sp)
			lea		4*4(sp), a2
			lea		.__data(pc), a1
			jsr		MDDBG__KDebug_WriteLine_Formatted
			movem.l	(sp)+, a0-a2/d7
			if (.__sp>8)
				lea		.__sp(sp), sp
			elseif (.__sp>0)
				addq.w	#.__sp, sp
			endif

		; ... Otherwise, use direct write as an optimization
		else
			move.l	a0, -(sp)
			lea		.__data(pc), a0
			jsr		MDDBG__KDebug_WriteLine
			move.l	(sp)+, a0
		endif

		bra.w	.__leave
	.__data:
		__FSTRING_GenerateDecodedString argument1, 0 ; 0 = no automatic newline
		!align	2
	.__leave:

	case "breakline"
		move.w	#$9E00, ($C00004).l

	case "starttimer"
		move.w	#$9FC0, ($C00004).l

	case "endtimer"
		move.w	#$9F00, ($C00004).l

	case "breakpoint"
		move.w	#$9D00, ($C00004).l

	elsecase
		!error	"ATTRIBUTE isn't a member of KDebug"

	endcase
	endm

; ---------------------------------------------------------------
__ErrorMessage:	macro string, opts
		__FSTRING_GenerateArgumentsCode string
		jsr		MDDBG__ErrorHandler
		__FSTRING_GenerateDecodedString string, 0 ; 0 = no automatic newline

		if DEBUGGER__EXTENSIONS__ENABLE
		.__align_flag: set (((*)&1)!1)*_eh_align_offset
			dc.b	(opts)+_eh_return|.__align_flag	; add flag "_eh_align_offset" if the next byte is at odd offset ...
			!align	2												; ... to tell Error handler to skip this byte, so it'll jump to ...
			jmp		MDDBG__ErrorHandler_PagesController	; ... extensions controller
		else
			dc.b	(opts)+0
			!align	2
		endif
	endm

; ---------------------------------------------------------------
; WARNING: Since AS cannot compile instructions out of strings
;	we have to do lots of switch-case bullshit down here..

__FSTRING_PushArgument: macro OPERAND,DEST

	.__operand:		set	OPERAND
	.__dval:		set	0

	; If OPERAND starts with "#", simulate "#immediate" mode by splitting OPERAND string
	if (substr(OPERAND, 0, 1)="#")
		.__dval:	set	VAL(substr(OPERAND, 1, 0))
		.__operand:	set	"#"

	; If OPERAND ends with ".w", simulate "XXX.w" mode
	elseif (substr(OPERAND, strlen(OPERAND)-2, 2)=".w")
		.__dval:	set VAL(substr(OPERAND, 0, strlen(OPERAND)-2))
		.__operand:	set	"x.w"

	; If OPERAND ends with ".l", simulate "XXX.l" mode
	elseif (substr(OPERAND, strlen(OPERAND)-2, 2)=".l")
		.__dval:	set VAL(substr(OPERAND, 0, strlen(OPERAND)-2))
		.__operand:	set	"x.l"

	; If OPERAND ends with "(pc)", simulate "d16(pc)" mode by splitting OPERAND string
	elseif (strlen(OPERAND)>4)&&(substr(OPERAND, strlen(OPERAND)-4, 4)="(pc)")
		.__dval:	set	VAL(substr(OPERAND, 0, strlen(OPERAND)-4))
		.__operand:	set substr(OPERAND, strlen(OPERAND)-4, 0)

	; If OPERAND ends with "(an)", simulate "d16(an)" mode by splitting OPERAND string
	elseif (strlen(OPERAND)>4)&&(substr(OPERAND, strlen(OPERAND)-4, 2)="(a")&&(substr(OPERAND, strlen(OPERAND)-1, 1)=")")
		.__dval:	set	VAL(substr(OPERAND, 0, strlen(OPERAND)-4))
		.__operand:	set substr(OPERAND, strlen(OPERAND)-4, 0)

	endif

	switch lowstring(.__operand)
	case "d0"
		move.ATTRIBUTE	d0,DEST
	case "d1"
		move.ATTRIBUTE	d1,DEST
	case "d2"
		move.ATTRIBUTE	d2,DEST
	case "d3"
		move.ATTRIBUTE	d3,DEST
	case "d4"
		move.ATTRIBUTE	d4,DEST
	case "d5"
		move.ATTRIBUTE	d5,DEST
	case "d6"
		move.ATTRIBUTE	d6,DEST
	case "d7"
		move.ATTRIBUTE	d7,DEST
	
	case "a0"
		move.ATTRIBUTE	a0,DEST
	case "a1"
		move.ATTRIBUTE	a1,DEST
	case "a2"
		move.ATTRIBUTE	a2,DEST
	case "a3"
		move.ATTRIBUTE	a3,DEST
	case "a4"
		move.ATTRIBUTE	a4,DEST
	case "a5"
		move.ATTRIBUTE	a5,DEST
	case "a6"
		move.ATTRIBUTE	a6,DEST

	case "(a0)"
		move.ATTRIBUTE	.__dval(a0),DEST
	case "(a1)"
		move.ATTRIBUTE	.__dval(a1),DEST
	case "(a2)"
		move.ATTRIBUTE	.__dval(a2),DEST
	case "(a3)"
		move.ATTRIBUTE	.__dval(a3),DEST
	case "(a4)"
		move.ATTRIBUTE	.__dval(a4),DEST
	case "(a5)"
		move.ATTRIBUTE	.__dval(a5),DEST
	case "(a6)"
		move.ATTRIBUTE	.__dval(a6),DEST

	case "x.w"
		move.ATTRIBUTE	(.__dval).w,DEST

	case "x.l"
		move.ATTRIBUTE	(.__dval).l,DEST

	case "(pc)"
		move.ATTRIBUTE	.__dval(pc),DEST

	case "#"
		move.ATTRIBUTE	#.__dval,DEST

	elsecase
	.__evaluated_operand: set VAL(OPERAND)
		move.ATTRIBUTE	.__evaluated_operand,DEST

	endcase
	endm

; ---------------------------------------------------------------
; WARNING! Incomplete!
__FSTRING_GenerateArgumentsCode: macro string

	.__pos:	set 	strstr(string,"%<")		; token position
	.__sp:	set		0						; stack displacement
	.__str:	set		string

	; Parse string itself
	while (.__pos>=0)

    	; Find the last occurance "%<" in the string
    	while ( strstr(substr(.__str,.__pos+2,0),"%<")>=0 )
			.__pos: 	set		strstr(substr(.__str,.__pos+2,0),"%<")+.__pos+2
		endm
		.__substr:	set		substr(.__str,.__pos,0)

		; Retrive expression in brackets following % char
    	.__endpos:	set		strstr(.__substr,">")
		if (.__endpos<0) ; Fix bizzare AS bug as stsstr() fails to check the last character of string
			.__endpos:	set		strlen(.__substr)-1
		endif
    	.__midpos:	set		strstr(substr(.__substr,5,0)," ")
    	if ((.__midpos<0)||(.__midpos+5>.__endpos))
			.__midpos:	set		.__endpos
		else
			.__midpos:	set		.__midpos+5
    	endif
		.__type:		set		substr(.__substr,2,2)	; .type

		; Expression is an effective address (e.g. %(.w d0 hex) )
		if ((strlen(.__type)==2)&&(substr(.__type,0,1)=="."))
			.__operand:	set		substr(.__substr,5,.__midpos-5)						; ea
			.__param:	set		substr(.__substr,.__midpos+1,.__endpos-.__midpos-1)		; param

			if (.__type==".b")
				subq.w	#2, sp
				__FSTRING_PushArgument.b	.__operand,1(sp)
				.__sp:	set		.__sp+2

			elseif (.__type==".w")
				__FSTRING_PushArgument.w	.__operand,-(sp)
				.__sp:	set		.__sp+2

			elseif (.__type==".l")
				__FSTRING_PushArgument.l	.__operand,-(sp)
				.__sp:	set		.__sp+4

			else
				error "Unrecognized type in string operand: \{.__type}"
			endif

		endif

		; Cut string
		if (.__pos>0)
			.__str:	set		substr(.__str, 0, .__pos)
			.__pos:	set		strstr(.__str,"%<")
		else
			.__pos:	set		-1
		endif

	endm

	endm

; ---------------------------------------------------------------
__FSTRING_GenerateDecodedString:	macro string, addnewline

	.__lpos:	set		0		; start position
	.__pos:	set		strstr(string, "%<")

	while (.__pos>=0)

		; Write part of string before % token
		if (.__pos-.__lpos>0)
			dc.b	substr(string, .__lpos, .__pos-.__lpos)
		endif

		; Retrive expression in brakets following % char
    	.__endpos:	set		strstr(substr(string,.__pos+1,0),">")+.__pos+1 
		if (.__endpos<=.__pos) ; Fix bizzare AS bug as stsstr() fails to check the last character of string
			.__endpos:	set		strlen(string)-1
		endif
    	.__midpos:	set		strstr(substr(string,.__pos+5,0)," ")+.__pos+5
    	if ((.__midpos<.__pos+5)||(.__midpos>.__endpos))
			.__midpos:	set		.__endpos
    	endif
		.__type:		set		substr(string,.__pos+1+1,2)		; .type

		; Expression is an effective address (e.g. %<.w d0 hex> )
		if ((strlen(.__type)==2)&&(substr(.__type,0,1)=="."))
			.__param:	set		substr(string,.__midpos+1,.__endpos-.__midpos-1)	; param

			; Validate format setting ("param")
			if (strlen(.__param)<1)
				.__param: 	set		"hex"			; if param is ommited, set it to "hex"
			elseif (.__param=="signed")
				.__param:	set		"hex+signed"	; if param is "signed", correct it to "hex+signed"
			endif

			if (val(.__param) < $80)
				!error "Illegal operand format setting: \{.__param}. Expected hex, dec, bin, sym, str or their derivatives."
			endif

			if (.__type==".b")
				dc.b	val(.__param)
			elseif (.__type==".w")
				dc.b	val(.__param)|1
			else
				dc.b	val(.__param)|3
			endif

		; Expression is an inline constant (e.g. %<endl> )
		else
			dc.b	val(substr(string,.__pos+1+1,.__endpos-.__pos-2))
		endif

		.__lpos:	set		.__endpos+1
		if (strstr(substr(string,.__pos+1,0),"%<")>=0)
			.__pos:	set		strstr(substr(string,.__pos+1,0), "%<")+.__pos+1
		else
			.__pos:	set		-1
		endif

	endm

	; Write part of string before the end
	dc.b	substr(string, .__lpos, 0)
	if addnewline
		dc.b	endl
	endif
	dc.b	0

	endm


; ---------------------------------------------------------------
; MD-Shell blob
; ---------------------------------------------------------------

MDShell:

	dc.l	$00FFFFF0, $00000214, BusError, AddressError, IllegalInstr, ZeroDivide, ChkInstr, TrapvInstr
	dc.l	PrivilegeViol, Trace, Line1010Emu, Line1111Emu, ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept
	dc.l	ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept, ErrorExcept
	dc.l	ErrorExcept, $00000310, $00000310, $00000310, MDSHELL__HBLANK_HANDLER, $00000310, MDSHELL__VBLANK_HANDLER, $00000310
	dc.l	$00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310
	dc.l	$00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310
	dc.l	$00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310
	dc.l	$00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310, $00000310
	dc.l	$53454741, $204D4547, $41204452, $49564520, $28432956, $4C414420, $32303233, $2E4A414E
	dc.l	$53454741, $204D4547, $41204452, $49564520, $4150504C, $49434154, $494F4E20, $20202020
	dc.l	$20202020, $20202020, $20202020, $20202020, $53454741, $204D4547, $41204452, $49564520
	dc.l	$4150504C, $49434154, $494F4E20, $20202020, $20202020, $20202020, $20202020, $20202020
	dc.l	$474D2078, $78787878, $7878782D, $78780000, $4A202020, $20202020, $20202020, $20202020
	dc.l	$00000000, $000FFFFF, $00FF0000, $00FFFFFF, $20202020, $20202020, $20202020, $20202020
	dc.l	$20202020, $20202020, $20202020, $20202020, $20202020, $20202020, $20202020, $20202020
	dc.l	$20202020, $20202020, $20202020, $20202020, $4A554520, $20202020, $20202020, $20202020
	dc.l	$00000000, $4D442053, $68656C6C, $20762E32, $2E360000, $46FC2700, $41FA0064, $4CD83C00
	dc.l	$4A6BEF0C, $66564C98, $007F7E0F, $CE2BEF01, $67062778, $01002F00, $36813881, $4A523482
	dc.l	$D4411418, $51CBFFF8, $1AC21AD8, $1AC051CD, $FFFC3880, $36803881, $24983E18, $2540FFFC
	dc.l	$51CFFFFA, $51CCFFF2, $9DCE2D00, $51CEFFFC, $13440011, $04040020, $6BF63880, $604400C0
	dc.l	$000400A1, $110000A1, $120000A0, $00000000, $01008004, $00120002, $1FFD3FFF, $14303C07
	dc.l	$6C000000, $00FF0081, $37000201, $0000F3C3, $40000000, $3FFFC000, $0000001F, $40000010
	dc.l	$00132E78, $00007040, $13C000A1, $000913C0, $00A1000B, $13C000A1, $000D46FC, $27004FEF
	dc.l	$FFF047D7, $4EBA0280, $4EBA016E, $70007200, $74007600, $78007A00, $7C007E00, $20402241
	dc.l	$24422643, $28442A45, $2C464EB9, Main, $4E7160FC, $4E7346FC, $27004FEF, $FFF048E7
	dc.l	$FFFE4EBA, $024249EF, $004C4E68, $2F0847EF, $00404EBA, $012441FA, $02C44EBA, $0B70225C
	dc.l	$45D44EBA, $0C2E4EBA, $0AF649D2, $1C196A02, $524947D1, $08060000, $670E41FA, $02A7222C
	dc.l	$00024EBA, $016A504C, $41FA02A4, $222C0002, $4EBA015C, $08060002, $66142278, $000045EC
	dc.l	$00064EBA, $01BC41FA, $02904EBA, $01424EBA, $0AAE0806, $00066600, $00AA45EF, $00044EBA
	dc.l	$0A783F01, $70034EBA, $0A3C303C, $64307A07, $4EBA0132, $321F7011, $4EBA0A2A, $303C6130
	dc.l	$7A064EBA, $0120303C, $73707A00, $2F0C45D7, $4EBA0112, $584F0806, $00016714, $43FA0255
	dc.l	$45D74EBA, $0B9243FA, $025645D4, $4EBA0B84, $584F4EBA, $0A245241, $70014EBA, $09E82038
	dc.l	$007841FA, $02444EBA, $010A2038, $007041FA, $02404EBA, $00FE4EBA, $0A262278, $000045D4
	dc.l	$53896140, $4EBA09F2, $7A199A41, $6B0A6148, $4EBA005A, $51CDFFFA, $08060005, $660A4E71
	dc.l	$60FC7200, $4EBA0A26, $2ECB4CDF, $7FFF487A, $FFEE2F2F, $FFC44E75, $43FA015E, $45FA0208
	dc.l	$4EFA08F2, $223C00FF, $FFFF2409, $C4812242, $240AC481, $24424E75, $4FEFFFD0, $41D77EFF
	dc.l	$20FC2853, $502930FC, $3A206018, $4FEFFFD0, $41D77EFF, $30FC202B, $320A924C, $4EBA05BE
	dc.l	$30FC3A20, $700572EC, $B5C96502, $72EE10C1, $321A4EBA, $05C610FC, $002051C8, $FFEA4218
	dc.l	$41D77200, $4EBA09E0, $4FEF0030, $4E754EBA, $09DC2F01, $2F0145D7, $43FA0148, $4EBA0A94
	dc.l	$504F4E75, $4FEFFFF0, $7EFF41D7, $30C030FC, $3A2010FC, $00EC221A, $4EBA0578, $421841D7
	dc.l	$72004EBA, $09A25240, $51CDFFE0, $4FEF0010, $4E752200, $48414601, $66F62440, $0C5A4EF9
	dc.l	$66042212, $60A80C6A, $4EF8FFFE, $66063212, $48C1609A, $4EBA0976, $41FA011E, $4EFA096A
	dc.l	$59894EBA, $FF20B3CA, $650C0C52, $0040650A, $548AB3CA, $64F47200, $4E752212, $67F20801
	dc.l	$000066EC, $4E754BF9, $00C00004, $4DEDFFFC, $44D569FC, $41FA0026, $30186A04, $3A8060F8
	dc.l	$70002ABC, $40000000, $2C802ABC, $40000010, $2C802ABC, $C0000000, $3C804E75, $80048134
	dc.l	$85008700, $8B008C81, $8D008F02, $90119100, $92008220, $84040000, $44000000, $00000001
	dc.l	$00100011, $01000101, $01100111, $10001001, $10101011, $11001101, $11101111, $FFFF0EEE
	dc.l	$FFF200CE, $FFF20EEA, $FFF20E86, $FFF24000, $00020028, $00280000, $008000FF, $EAE0FA01
	dc.l	$F02600EA, $41646472, $6573733A, $2000EA4F, $66667365, $743A2000, $EA43616C, $6C65723A
	dc.l	$2000EC80, $8120E8BF, $ECC800EC, $8320E8BF, $ECC800FA, $10E87573, $703A20EC, $8300FA03
	dc.l	$E873723A, $20EC8100, $EA56496E, $743A2000, $EA48496E, $743A2000, $E83C756E, $64656669
	dc.l	$6E65643E, $000002F7, $00000000, $00000000, $183C3C18, $18001800, $6C6C6C00, $00000000
	dc.l	$6C6CFE6C, $FE6C6C00, $187EC07C, $06FC1800, $00C60C18, $3060C600, $386C3876, $CCCC7600
	dc.l	$18183000, $00000000, $18306060, $60301800, $60301818, $18306000, $00EE7CFE, $7CEE0000
	dc.l	$0018187E, $18180000, $00000000, $18183000, $000000FE, $00000000, $00000000, $00383800
	dc.l	$060C1830, $60C08000, $7CC6CEDE, $F6E67C00, $18781818, $18187E00, $7CC60C18, $3066FE00
	dc.l	$7CC6063C, $06C67C00, $0C1C3C6C, $FE0C0C00, $FEC0FC06, $06C67C00, $7CC6C0FC, $C6C67C00
	dc.l	$FEC6060C, $18181800, $7CC6C67C, $C6C67C00, $7CC6C67E, $06C67C00, $001C1C00, $001C1C00
	dc.l	$00181800, $00181830, $0C183060, $30180C00, $0000FE00, $00FE0000, $6030180C, $18306000
	dc.l	$7CC6060C, $18001800, $7CC6C6DE, $DCC07E00, $386CC6C6, $FEC6C600, $FC66667C, $6666FC00
	dc.l	$3C66C0C0, $C0663C00, $F86C6666, $666CF800, $FEC2C0F8, $C0C2FE00, $FE62607C, $6060F000
	dc.l	$7CC6C0C0, $DEC67C00, $C6C6C6FE, $C6C6C600, $3C181818, $18183C00, $3C181818, $D8D87000
	dc.l	$C6CCD8F0, $D8CCC600, $F0606060, $6062FE00, $C6EEFED6, $D6C6C600, $C6E6E6F6, $DECEC600
	dc.l	$7CC6C6C6, $C6C67C00, $FC66667C, $6060F000, $7CC6C6C6, $C6D67C06, $FCC6C6FC, $D8CCC600
	dc.l	$7CC6C07C, $06C67C00, $7E5A1818, $18183C00, $C6C6C6C6, $C6C67C00, $C6C6C6C6, $6C381000
	dc.l	$C6C6D6D6, $FEEEC600, $C66C3838, $386CC600, $6666663C, $18183C00, $FE860C18, $3062FE00
	dc.l	$7C606060, $60607C00, $C0603018, $0C060200, $7C0C0C0C, $0C0C7C00, $10386CC6, $00000000
	dc.l	$00000000, $000000FF, $30301800, $00000000, $0000780C, $7CCC7E00, $E0607C66, $6666FC00
	dc.l	$00007CC6, $C0C67C00, $1C0C7CCC, $CCCC7E00, $00007CC6, $FEC07C00, $1C3630FC, $30307800
	dc.l	$000076CE, $C67E067C, $E0607C66, $6666E600, $18003818, $18183C00, $0C001C0C, $0C0CCC78
	dc.l	$E060666C, $786CE600, $18181818, $18181C00, $00006CFE, $D6D6C600, $0000DC66, $66666600
	dc.l	$00007CC6, $C6C67C00, $0000DC66, $667C60F0, $000076CC, $CC7C0C1E, $0000DC66, $6060F000
	dc.l	$00007CC0, $7C067C00, $3030FC30, $30361C00, $0000CCCC, $CCCC7600, $0000C6C6, $6C381000
	dc.l	$0000C6C6, $D6FE6C00, $0000C66C, $386CC600, $0000C6C6, $CE76067C, $0000FC98, $3064FC00
	dc.l	$0E181870, $18180E00, $18181800, $18181800, $7018180E, $18187000, $76DC0000, $00000000
	dc.l	$22790000, $02000C59, $DEB26672, $70FED059, $74FC7600, $48410241, $00FFD241, $D241B240
	dc.l	$625C675E, $20311000, $675847F1, $08004841, $7000301B, $B253654C, $43F308FE, $45E9FFFC
	dc.l	$E248C042, $B2730000, $65146204, $D6C0601A, $47F30004, $200A908B, $6AE6594B, $600C45F3
	dc.l	$00FC200A, $908B6AD8, $47D2925B, $7400341B, $D3C24841, $42414841, $D2837000, $4E7570FF
	dc.l	$4E754841, $70003001, $D6805283, $323CFFFF, $48415941, $6A8E70FF, $4E752679, $00000200
	dc.l	$0C5BDEB2, $664AD6D3, $78007200, $740045D3, $51CC0006, $16197807, $D603D341, $5242B252
	dc.l	$620A65EC, $B42A0002, $671265E4, $584AB252, $62FA65DC, $B42A0002, $65D666F0, $10EA0003
	dc.l	$670A51CF, $FFC64E94, $64C04E75, $53484E75, $70004E75, $4EFA0024, $4EFA0018, $760F3401
	dc.l	$E84AC443, $10FB205C, $51CF004A, $4E946444, $4E754841, $61046548, $4841E959, $780FC841
	dc.l	$10FB4040, $51CF0006, $4E946534, $E959780F, $C84110FB, $402E51CF, $00064E94, $6522E959
	dc.l	$780FC841, $10FB401C, $51CF0006, $4E946510, $E959760F, $C24310FB, $100A51CF, $00044ED4
	dc.l	$4E753031, $32333435, $36373839, $41424344, $45464841, $67066106, $65E6609C, $4841E959
	dc.l	$780FC841, $670E10FB, $40DA51CF, $FFA04E94, $649A4E75, $E959780F, $C841670E, $10FB40C4
	dc.l	$51CFFF9C, $4E946496, $4E75E959, $780FC841, $679E10FB, $40AE51CF, $FF984E94, $64924E75
	dc.l	$4EFA0026, $4EFA001A, $74077018, $D201D100, $10C051CF, $00064E94, $650451CA, $FFEE4E75
	dc.l	$48416104, $65184841, $740F7018, $D241D100, $10C051CF, $00064E94, $650451CA, $FFEE4E75
	dc.l	$4EFA0010, $4EFA0048, $47FA009A, $024100FF, $600447FA, $008C4200, $7609381B, $34039244
	dc.l	$55CAFFFC, $D2449443, $44428002, $670E0602, $003010C2, $51CF0006, $4E946510, $381B6ADC
	dc.l	$06010030, $10C151CF, $00044ED4, $4E7547FA, $002E4200, $7609281B, $34039284, $55CAFFFC
	dc.l	$D2849443, $44428002, $670E0602, $003010C2, $51CF0006, $4E9465D4, $281B6ADC, $609E3B9A
	dc.l	$CA0005F5, $E1000098, $9680000F, $42400001, $86A00000, $2710FFFF, $03E80064, $000AFFFF
	dc.l	$271003E8, $0064000A, $FFFF48C1, $60084EFA, $00064881, $48C148E7, $50604EBA, $FD446618
	dc.l	$2E814EBA, $FDD64CDF, $060A650A, $08030003, $66044EFA, $00B64E75, $4CDF060A, $08030002
	dc.l	$670847FA, $000A4EFA, $00B470FF, $60DE3C75, $6E6B6E6F, $776E3E00, $10FC002B, $51CF0006
	dc.l	$4E9465D2, $48414A41, $6700FE72, $6000FE68, $08030003, $66C04EFA, $FDFA48E7, $F81010D9
	dc.l	$5FCFFFFC, $6E146718, $16207470, $C4034EBB, $201A64EA, $4CDF081F, $4E754E94, $64E060F4
	dc.l	$53484E94, $4CDF081F, $4E7547FA, $FDA8B702, $D4024EFB, $205A4E71, $4E7147FA, $FEA4B702
	dc.l	$D4024EFB, $204A4E71, $4E7147FA, $FE54B702, $D4024EFB, $203A5348, $4E7547FA, $FF2E7403
	dc.l	$C403D442, $4EFB2028, $4E714A40, $6B084A81, $67164EFA, $FF644EFA, $FF78265A, $10DB57CF
	dc.l	$FFFC67D2, $4E9464F4, $4E755248, $6032504B, $321A4ED3, $584B221A, $4ED35547, $6028504B
	dc.l	$321A6004, $584B221A, $6A084481, $10FC002D, $600410FC, $002B51CF, $00064E94, $65CA4ED3
	dc.l	$51CFFFC6, $4ED46506, $524810D9, $4E755447, $53494ED4, $4BF900C0, $00044DED, $FFFC4A51
	dc.l	$6B102A99, $41D23818, $4EBA023C, $43E90020, $60EC5449, $2ABCC000, $00007000, $76033C80
	dc.l	$34193C82, $34196AFA, $72004EBB, $204C51CB, $FFEE2A19, $200B4840, $024000FF, $00405D00
	dc.l	$48402640, $4E6326C5, $26C526D9, $26D92A85, $70003219, $61122ABC, $40000000, $72006108
	dc.l	$3ABC8174, $2A854E75, $2C802C80, $2C802C80, $2C802C80, $2C802C80, $51C9FFEE, $4E754CAF
	dc.l	$00030004, $48E76010, $4E6B240B, $48424202, $0C425D00, $661C342B, $00040242, $E000C2EB
	dc.l	$000ED441, $D440D440, $36823742, $0004504B, $36DB4CDF, $08064E75, $2F0B4E6B, $200B4840
	dc.l	$42000C40, $5D006612, $72003213, $02411FFF, $82EB000E, $20014840, $E248265F, $4E752F0B
	dc.l	$2F004E6B, $200B4840, $42000C40, $5D006616, $302B0004, $D06B000E, $02405FFF, $36803740
	dc.l	$0004504B, $36DB201F, $265F4E75, $2F0B2F00, $4E6B200B, $48404200, $0C405D00, $66043741
	dc.l	$000C201F, $265F4E75, $2F0B2F00, $4E6B200B, $48404200, $0C405D00, $6606504B, $36C136C1
	dc.l	$201F265F, $4E7561C4, $487AFF94, $48E77F12, $4E6B240B, $48424202, $0C425D00, $66282A1B
	dc.l	$2E1B4C93, $005C4846, $4DF900C0, $00002D45, $00044845, $72001218, $6E126B32, $4893001C
	dc.l	$484548E3, $05004CDF, $48FE4E75, $51CB0012, $D642DE86, $0887001D, $2D470004, $2A074845
	dc.l	$D2443C81, $54457200, $12186EE0, $67CE0241, $001E4EFB, $1002DE86, $721D0387, $6020602A
	dc.l	$602E6036, $603E1418, $60141818, $60D8603A, $1218D241, $76804843, $CE834841, $8E813602
	dc.l	$2D470004, $2A074845, $60BC0244, $9FFF60B6, $02449FFF, $00442000, $60AC0244, $9FFF0044
	dc.l	$400060A2, $00446000, $609C3F04, $1E98381F, $6094487A, $FECA2F0C, $49FA0016, $4FEFFFD0
	dc.l	$41D77E2E, $4EBAFCF4, $4FEF0030, $285F4E75, $42184447, $0647002F, $90C72F08, $4EBAFF0E
	dc.l	$205F7E2E, $4E75741E, $10181200, $E609C242, $3CB11000, $D000C042, $3CB10000, $51CCFFEA
	dc.l	$4E75487A, $00562F0C, $49FA0016, $4FEFFFD0, $41D77E2E, $4EBAFCA4, $4FEF0030, $285F4E75
	dc.l	$42184447, $0647002F, $90C72F08, $2F0D4BF9, $00C00004, $3E3C9E00, $60023A87, $1E186EFA
	dc.l	$67100407, $00E067F2, $0C070010, $6DEE5248, $60EA2A5F, $205F7E2E, $4E7533FC, $9E0000C0
	dc.l	$00044E75, $487AFFF4, $3F072F0D, $4BF900C0, $00043E3C, $9E006002, $3A871E18, $6EFA6710
	dc.l	$040700E0, $67F20C07, $00106DEE, $524860EA, $2A5F3E1F, $4E7546FC, $27004FEF, $FFF048E7
	dc.l	$FFFE47EF, $003C4EBA, $F4FE4EBA, $F3EC4CDF, $7FFF487A, $F3CA2F2F, $00144E75, $48E7C456
	dc.l	$4E6B200B, $48404200, $0C405D00, $66124BF9, $00C00004, $4DEDFFFC, $43FAF554, $4EBAFCF4
	dc.l	$4CDF6A23, $4E7548E7, $C0D04E6B, $200B4840, $42000C40, $5D00660C, $3F3C0000, $610C610A
	dc.l	$67FC544F, $4CDF0B03, $4E756174, $41EF0004, $43F900A1, $00036178, $70F0C02F, $00054E75
	dc.l	$48E7FFFE, $3F3C0000, $61E04BF9, $00C00004, $4DEDFFFC, $61D467F2, $6B4041FA, $00765888
	dc.l	$D00064FA, $20106F32, $20404FEF, $FFF043FA, $F4E247D7, $2A3C4000, $00034EBA, $FC782ABC
	dc.l	$82308406, $2A85487A, $000C4850, $4CEF7FFF, $00164E75, $4FEF0010, $60B02ABA, $F47660AA
	dc.l	$41F900C0, $000444D0, $6BFC44D0, $6AFC4E75, $12BC0000, $4E7172C0, $1011E508, $12BC0040
	dc.l	$4E71C001, $12110201, $003F8001, $46001210, $B10110C0, $C20010C1, $4E750000, $11860000
	dc.l	$00000000, $11D248E7, $00FE41FA, $002A4EBA, $FD1C49D7, $7C063F3C, $20002F3C, $E861303A
	dc.l	$41D7221C, $4EBAF328, $522F0002, $51CEFFF2, $4FEF0022, $4E75E0FA, $01F026EA, $41646472
	dc.l	$65737320, $52656769, $73746572, $733AE0E0, $000041FA, $00884EBA, $FCD42278, $00005989
	dc.l	$45D74EBA, $F280B3CA, $65700C52, $00406464, $20126760, $20400240, $00016658, $12201020
	dc.l	$0C000061, $66044A01, $663A0C00, $004E660A, $020100F8, $0C010090, $672A3020, $0C406100
	dc.l	$67221200, $42000C40, $4E006612, $0C0100A8, $650C0C01, $00BB6206, $0C0100B9, $66060C60
	dc.l	$4EB96610, $2F0A2F09, $22084EBA, $F286225F, $245F548A, $548AB3CA, $64904E75, $E0FA01F0
	dc.l	$26EA4261, $636B7472, $6163653A, $E0E00000


; ---------------------------------------------------------------
; MD-Shell's exported symbols
; ---------------------------------------------------------------

MDDBG__IdleInt:	equ	$314
MDDBG__ErrorHandler:	equ	$316
MDDBG__Error_IdleLoop:	equ	$43E
MDDBG__Error_InitConsole:	equ	$458
MDDBG__Error_MaskStackBoundaries:	equ	$464
MDDBG__Error_DrawOffsetLocation:	equ	$4CE
MDDBG__Error_DrawOffsetLocation2:	equ	$4D2
MDDBG__Error_DrawOffsetLocation__inj:	equ	$4D8
MDDBG__ErrorHandler_SetupVDP:	equ	$566
MDDBG__ErrorHandler_VDPConfig:	equ	$59C
MDDBG__ErrorHandler_VDPConfig_Nametables:	equ	$5B2
MDDBG__ErrorHandler_ConsoleConfig_Initial:	equ	$5EE
MDDBG__ErrorHandler_ConsoleConfig_Shared:	equ	$5F2
MDDBG__Str_OffsetLocation_24bit:	equ	$622
MDDBG__Str_OffsetLocation_32bit:	equ	$62B
MDDBG__Art1bpp_Font:	equ	$666
MDDBG__GetSymbolByOffset:	equ	$960
MDDBG__FormatString:	equ	$C7A
MDDBG__Console_Init:	equ	$D54
MDDBG__Console_Reset:	equ	$D92
MDDBG__Console_InitShared:	equ	$D94
MDDBG__Console_SetPosAsXY_Stack:	equ	$DDE
MDDBG__Console_SetPosAsXY:	equ	$DE4
MDDBG__Console_GetPosAsXY:	equ	$E18
MDDBG__Console_StartNewLine:	equ	$E3E
MDDBG__Console_SetBasePattern:	equ	$E6C
MDDBG__Console_SetWidth:	equ	$E88
MDDBG__Console_WriteLine_WithPattern:	equ	$EA6
MDDBG__Console_WriteLine:	equ	$EA8
MDDBG__Console_Write:	equ	$EAC
MDDBG__Console_WriteLine_Formatted:	equ	$F72
MDDBG__Console_Write_Formatted:	equ	$F76
MDDBG__Decomp1bpp:	equ	$FA6
MDDBG__KDebug_WriteLine_Formatted:	equ	$FC2
MDDBG__KDebug_Write_Formatted:	equ	$FC6
MDDBG__KDebug_FlushLine:	equ	$101A
MDDBG__KDebug_WriteLine:	equ	$1024
MDDBG__KDebug_Write:	equ	$1028
MDDBG__ErrorHandler_ConsoleOnly:	equ	$1056
MDDBG__ErrorHandler_ClearConsole:	equ	$107C
MDDBG__ErrorHandler_PauseConsole:	equ	$10A6
MDDBG__ErrorHandler_PagesController:	equ	$10E0
MDDBG__VSync:	equ	$1140
MDDBG__ErrorHandler_ExtraDebuggerList:	equ	$117A
MDDBG__Debugger_AddressRegisters:	equ	$1186
MDDBG__Debugger_Backtrace:	equ	$11D2
MDDBG__BusError:	equ	$1270
MDDBG__AddressError:	equ	$1284
MDDBG__IllegalInstr:	equ	$129C
MDDBG__ZeroDivide:	equ	$12BA
MDDBG__ChkInstr:	equ	$12D0
MDDBG__TrapvInstr:	equ	$12EA
MDDBG__PrivilegeViol:	equ	$1306
MDDBG__Trace:	equ	$1324
MDDBG__Line1010Emu:	equ	$1334
MDDBG__Line1111Emu:	equ	$1350
MDDBG__ErrorExcept:	equ	$136C


; ---------------------------------------------------------------
; Exception vectors
; ---------------------------------------------------------------

	if DEBUGGER__SHOW_SR_USP
_eh_default:	equ	_eh_show_sr_usp
	else
_eh_default:	equ	0
	endif

; ---------------------------------------------------------------

BusError:
	__ErrorMessage "BUS ERROR", _eh_default|_eh_address_error

AddressError:
	__ErrorMessage "ADDRESS ERROR", _eh_default|_eh_address_error

IllegalInstr:
	__ErrorMessage "ILLEGAL INSTRUCTION", _eh_default

ZeroDivide:
	__ErrorMessage "ZERO DIVIDE", _eh_default

ChkInstr:
	__ErrorMessage "CHK INSTRUCTION", _eh_default

TrapvInstr:
	__ErrorMessage "TRAPV INSTRUCTION", _eh_default

PrivilegeViol:
	__ErrorMessage "PRIVILEGE VIOLATION", _eh_default

Trace:
	__ErrorMessage "TRACE", _eh_default

Line1010Emu:
	__ErrorMessage "LINE 1010 EMULATOR", _eh_default

Line1111Emu:
	__ErrorMessage "LINE 1111 EMULATOR", _eh_default

ErrorExcept:
	__ErrorMessage "ERROR EXCEPTION", _eh_default
