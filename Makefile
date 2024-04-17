
.PHONY:	megapcm examples test clean

MAKEFILE := Makefile
ifeq ($(OS),Windows_NT)
	MAKEFILE := Makefile.win
endif

megapcm:
	$(MAKE) -C src -f $(MAKEFILE)

examples:	megapcm
	$(MAKE) -C examples -f $(MAKEFILE)

test:	megapcm
	$(MAKE) -C test -f $(MAKEFILE)

clean:
	$(MAKE) -C src -f $(MAKEFILE) clean
	$(MAKE) -C examples -f $(MAKEFILE) clean
	$(MAKE) -C test -f $(MAKEFILE) clean
