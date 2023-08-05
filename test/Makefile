
CC := gcc
CFLAGS := -I./z80vm -O2 -std=c99 -Wall -pedantic-errors
LDFLAGS := -L../build/z80vm -lz80vm

BUILD_DIR ?= ../build/test

LIBZ80VM_A := ../build/z80vm/libz80vm.a
LIBFILES := $(wildcard z80vm/*.c) $(wildcard z80vm/*.h)

SRC_FILES := $(wildcard *.c)
EXE_FILES := $(SRC_FILES:%.c=%)


.PHONY:	all run build

all:	run build

run:	$(EXE_FILES)
	$(foreach executable, $(EXE_FILES), echo -n "$(executable)... "; ./$(executable);)

build:	$(EXE_FILES)

$(EXE_FILES):	$(SRC_FILES)

$(SRC_FILES):	$(LIBZ80VM_A)

$(LIBZ80VM_A):	$(LIBFILES)
	make -C z80vm

%: %.c
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@
