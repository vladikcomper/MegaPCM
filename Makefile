
.PHONY:	all megapcm examples test tools clean

megapcm:
	$(MAKE) -C src

examples:	megapcm
	$(MAKE) -C examples

test:	megapcm
	$(MAKE) -C test

tools:	dpcm-hq-conv megapcm-viz

dpcm-hq-conv:	megapcm
	$(MAKE) -C tools/megapcm-viz

megapcm-viz:	megapcm
	$(MAKE) -C tools/dpcm-hq-conv

all: megapcm examples tools

clean:
	$(MAKE) -C src clean
	$(MAKE) -C examples clean
	$(MAKE) -C test clean
	$(MAKE) -C tools/megapcm-viz clean
	$(MAKE) -C tools/dpcm-hq-conv clean
