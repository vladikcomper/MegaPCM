
# Include toolchain file for $(ASM68K), $(PSYLINK) etc
TOOLCHAIN_DIR := ../../toolchain
include ../../toolchain.mk

LIBS := ../../lib-68k/mdshell.obj ../../build/68k/megapcm.debug.obj
ASMFLAGS := /q /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae-,v+ /g

ASMS := $(wildcard *.asm)
ROMS := $(ASMS:%.asm=%.gen)

.PHONY: all all-macros clean

all:	 all-macros $(ROMS)

all-macros: all-macros.gen all-macros.as.gen all-macros.asm68k.gen
	$(CONVSYM) all-macros.gen.sym all-macros.gen.sym.log -out log -filter "MacroExpansions|MacroExpansions_End"
	$(CONVSYM) all-macros.asm68k.gen.sym all-macros.asm68k.gen.sym.log -out log -filter "MacroExpansions|MacroExpansions_End"
	$(CONVSYM) all-macros.as.gen.lst all-macros.as.gen.lst.log -in as_lst -out log -filter "MacroExpansions|MacroExpansions_End"
	$(PYTHON) all-macros.diff.py

%.obj: %.asm
	$(ASM68K) $(ASMFLAGS) /l /e __LINKABLE__ /e __AS__=0 /e __DEBUG__ $<,$@,,$@.lst

%.as.gen: %.asm
	set AS_MSGPATH="..\toolchain\as"
	set USEANSI=n
	$(AS) -D __DEBUG__=1 -D __AS__=1 -U -xx -i . -A -L -OLIST $@.lst $< -o $@.p
	$(P2BIN) $@.p $@
	rm -rf $@.p
	$(CONVSYM) $@.lst $@ -in as_lst -a -ref 200

%.asm68k.gen: %.asm
	$(ASM68K) $(ASMFLAGS) /p /e __AS__=0 /e __DEBUG__ $<,$@,$@.sym,$@.lst
	$(CONVSYM) $@.sym $@ -ref 200 -a

%.gen: %.obj
	$(PSYLINK) /q /p $(LIBS) $<,$@,$@.sym
	$(CONVSYM) $@.sym $@ -ref 200 -a

clean:
	rm -rf *.gen *.obj *.lst *.sym *.log
