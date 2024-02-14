
.PHONY:	megapcm examples test clean

megapcm:
	$(MAKE) -C src

examples:	megapcm
	$(MAKE) -C examples

test:	megapcm
	$(MAKE) -C test

clean:
	$(MAKE) -C src clean
	$(MAKE) -C examples clean
	$(MAKE) -C test clean
