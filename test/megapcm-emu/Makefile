
AR := ar rcs
RANLIB := ranlib
CC := cc
CFLAGS := -I../../build/z80 -I../z80vm -Wall -pedantic -O2 -fomit-frame-pointer

MEGAPCM_SYMBOLS_H := ../../build/z80/megapcm.symbols.h
LIBMEGAPCM_EMU_A := libmegapcm-emu.a
MEGAPCM_EMU_O := megapcm-emu.o

OBJECT_FILES := $(MEGAPCM_EMU_O)


.PHONY: all megapcm-emu

all: megapcm-emu

megapcm-emu: $(LIBMEGAPCM_EMU_A)

$(LIBMEGAPCM_EMU_A):	$(OBJECT_FILES)
	$(AR) $@ $(OBJECT_FILES)

$(MEGAPCM_EMU_O): megapcm-emu.c megapcm-emu.h $(MEGAPCM_SYMBOLS_H)
	$(CC) $(CFLAGS) -c megapcm-emu.c -o $@

clean:
	rm $(LIBMEGAPCM_EMU_A) $(OBJECT_FILES)
