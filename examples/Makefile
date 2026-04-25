
# Include toolchain file for $(ASM68K), $(PSYLINK) etc
TOOLCHAIN_DIR := ../toolchain
include ../toolchain.mk

LIBS := ../lib-68k/mdshell.obj ../build/68k/megapcm.debug.obj
ASMFLAGS := /q /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae-,v+ /g

COMMON_FILES := $(wildcard common/*.*)

DEMO_ROMS_ASM := $(wildcard demo-roms/*.asm)
DEMO_ROMS_GEN := $(DEMO_ROMS_ASM:%.asm=%.gen)
DEMO_ROMS_GEN_ASM68K := $(DEMO_ROMS_ASM:%.asm=%.asm68k.gen)
DEMO_ROMS_GEN_AS := $(DEMO_ROMS_ASM:%.asm=%.as.gen)


.PHONY: all dma-survival-test s1-smps-integration demo-roms clean

all:	dma-survival-test s1-smps-integration demo-roms

demo-roms:	$(DEMO_ROMS_GEN) $(DEMO_ROMS_GEN_ASM68K) $(DEMO_ROMS_GEN_AS)

dma-survival-test:	dma-survival-test/dma-survival-test.gen

s1-smps-integration:	s1-smps-integration/s1-smps-integration.gen

s1-smps-integration/s1-smps-integration.gen: $(wildcard s1-smps-integration/*.asm)

%.obj: %.asm $(COMMON_FILES)
	$(ASM68K) $(ASMFLAGS) /l /e __LINKABLE__ /e __AS__=0 /e __DEBUG__ $<,$@,,$@.lst

%.as.gen: %.asm $(COMMON_FILES)
	set AS_MSGPATH="..\toolchain\as"
	set USEANSI=n
	$(AS) -D __DEBUG__=1 -D __AS__=1 -U -xx -i . -A -L -OLIST $@.lst $< -o $@.p
	$(P2BIN) $@.p $@
	rm -rf $@.p
	$(CONVSYM) $@.lst $@ -in as_lst -a -ref 200

%.asm68k.gen: %.asm $(COMMON_FILES)
	$(ASM68K) $(ASMFLAGS) /p /e __AS__=0 /e __DEBUG__ $<,$@,$@.sym,$@.lst
	$(CONVSYM) $@.sym $@ -ref 200 -a
	rm -rf $@.sym

%.gen: %.obj
	$(PSYLINK) /q /p $(LIBS) $<,$@,$@.sym
	$(CONVSYM) $@.sym $@ -ref 200 -a
	rm -rf $@.sym

clean:
	rm -rf **/*.gen **/*.obj **/*.lst
