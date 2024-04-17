
# Include toolchain file for $(ASM68K), $(PSYLINK) etc
TOOLCHAIN_DIR := ../toolchain
include ../toolchain.mk

LIBS := ../lib-68k/mdshell.obj ../build/68k/megapcm.debug.obj
ASMFLAGS := /q /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae-,v+ /g /l

.PHONY: all dma-survival-test sample-tester s1-smps-integration clean

all:	dma-survival-test sample-tester s1-smps-integration

dma-survival-test:	dma-survival-test/dma-survival-test.gen

dma-survival-test/dma-survival-test.obj: $(wildcard dma-survival-test/*.asm)

sample-tester:	sample-tester/sample-tester.gen

sample-tester/sample-tester.obj: $(wildcard dma-survival-test/*.asm)

s1-smps-integration:	s1-smps-integration/s1-smps-integration.gen

s1-smps-integration/s1-smps-integration.gen: $(wildcard s1-smps-integration/*.asm)

%.obj: %.asm
	$(ASM68K) $(ASMFLAGS) $<,$@

%.gen: %.obj
	$(PSYLINK) /q /p $(LIBS) $<,$@,$@.sym
	$(CONVSYM) $@.sym $@ -ref 200 -a
	rm -rf $@.sym

clean:
	rm -rf **/*.gen **/*.obj
