
CC := cc
CFLAGS := -I../../build/z80 -I../../lib/z80vm -I../../lib/megapcm-emu -Wall -pedantic -Og -g -fomit-frame-pointer
LDFLAGS := -L../../lib/megapcm-emu -L../../lib/z80vm -lz80vm -lmegapcm-emu -lSDL3 -g

OBJ_FILES := megapcm-viz.o

.PHONY: run megapcm-emu z80vm

megapcm-viz: $(OBJ_FILES) megapcm-emu z80vm
	$(CC) $(OBJ_FILES) $(LDFLAGS) -o $@

run:	megapcm-viz
	./megapcm-viz

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

megapcm-emu:
	$(MAKE) -C ../../lib/megapcm-emu

z80vm:
	$(MAKE) -C ../../lib/z80vm

clean:
	rm megapcm-viz $(OBJ_FILES)
