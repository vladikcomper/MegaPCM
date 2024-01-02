
CC := gcc
CFLAGS := -I./megapcm-emu -I./z80vm -I../build -O2 -std=c99 -Wall -pedantic-errors
LDFLAGS := -L./megapcm-emu -L./z80vm -lz80vm -lmegapcm-emu

BUILD_DIR ?= ../build/test

MEGAPCM_SYMBOLS_H := ../build/megapcm.symbols.h
LIBZ80VM_A := ./z80vm/libz80vm.a
LIBZ80VM_FILES := $(wildcard z80vm/*.c) $(wildcard z80vm/*.h)
LIBMEGAPCM_EMU_A := ./megapcm-emu/libmegapcm-emu.a
LIBMEGAPCM_EMU_FILES := $(wildcard megapcm-emu/*.c) $(wildcard megapcm-emu/*.h) $(MEGAPCM_SYMBOLS_H)

SRC_FILES := $(wildcard *.c)
EXE_FILES := $(SRC_FILES:%.c=%)


.PHONY:	all run build clean

all:	run build

run:	$(EXE_FILES)
	$(foreach executable, $(EXE_FILES), echo -n "$(executable)... " && ./$(executable) 2>$(executable).log)

build:	$(EXE_FILES)

clean:
	rm -f $(EXE_FILES)

$(EXE_FILES):	$(SRC_FILES)

$(SRC_FILES):	$(LIBZ80VM_A) $(LIBMEGAPCM_EMU_A) $(MEGAPCM_SYMBOLS_H)

$(LIBZ80VM_A):	$(LIBZ80VM_FILES)
	make -C z80vm

$(LIBMEGAPCM_EMU_A):	$(LIBMEGAPCM_EMU_FILES)
	make -C megapcm-emu

%: %.c $(LIBZ80VM_A) $(LIBMEGAPCM_EMU_A)
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@
