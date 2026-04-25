
	if __AS__
		include	"../lib-68k/mdshell.as.asm"						; MD Shell blob
		include "../build/bundle/as/MegaPCM.asm"				; Mega PCM blob

	elseif ~def(__LINKABLE__)
		include	"../lib-68k/mdshell.asm68k.asm"					; MD Shell blob
		include "../build/bundle/asm68k/MegaPCM.asm"			; Mega PCM blob
		opt l+

	else
		include	"../lib-68k/mdshell.asm"						; MD Shell library
		include "../build/bundle/asm68k-linkable/MegaPCM.asm"	; Mega PCM library

		section rom
		xdef	Main
		opt l+

	endif
