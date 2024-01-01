
AR := ar rcs
RANLIB := ranlib
CC := gcc
CFLAGS := -Wall -pedantic -O2 -fomit-frame-pointer

LIBZ80VM_A := libz80vm.a
Z80VM_O := z80vm.o
Z80EMU_O := z80emu.o

OBJECT_FILES := $(Z80VM_O) $(Z80EMU_O)


.PHONY: all z80vm

all: z80vm

z80vm: $(LIBZ80VM_A)

$(LIBZ80VM_A):	$(OBJECT_FILES)
	$(AR) $@ $(OBJECT_FILES)

$(Z80EMU_O): z80vm.h z80emu.c z80emu.h z80config.h instructions.h macros.h tables.h
	$(CC) $(CFLAGS) -c z80emu.c -o $@

$(Z80VM_O): z80vm.c z80vm.h z80emu.h z80config.h instructions.h macros.h tables.h
	$(CC) $(CFLAGS) -c z80vm.c -o $@

clean:
	rm $(LIBZ80VM_A) $(OBJECT_FILES)
