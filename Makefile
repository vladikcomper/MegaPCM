
.PHONY:	megapcm megapcm-68k megapcm-z80 test clean

megapcm:
	$(MAKE) -C src-bundle

megapcm-68k:
	$(MAKE) -C src-68k

megapcm-z80:
	$(MAKE) -C src

test:	megapcm-z80
	$(MAKE) -C test

clean:
	$(MAKE) -C src clean
	$(MAKE) -C src-68k clean
	$(MAKE) -C src-bundle clean
	$(MAKE) -C test clean
