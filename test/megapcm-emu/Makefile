
AR := ar rcs
RANLIB := ranlib
CC := cc
CFLAGS := -I../../build/z80 -I../z80vm -Wall -pedantic -O2 -fomit-frame-pointer

LIBMEGAPCM_EMU_A := libmegapcm-emu.a
MEGAPCM_EMU_O := megapcm-emu.o

OBJECT_FILES := $(MEGAPCM_EMU_O)


.PHONY: all megapcm-emu

all: megapcm-emu

megapcm-emu: $(LIBMEGAPCM_EMU_A)

$(LIBMEGAPCM_EMU_A):	$(OBJECT_FILES)
	$(AR) $@ $(OBJECT_FILES)

$(MEGAPCM_EMU_O): megapcm-emu.c megapcm-emu.h
	$(CC) $(CFLAGS) -c megapcm-emu.c -o $@

clean:
	rm $(LIBMEGAPCM_EMU_A) $(OBJECT_FILES)
