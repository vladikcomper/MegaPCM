
# Executables
SJASMPLUS ?= sjasmplus

TOOLCHAIN_DIR := toolchain
BUILD_DIR := build
SRC_DIR := src

SYMTOH := $(TOOLCHAIN_DIR)/symtoh.py

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	release test clean

release: $(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.h

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.sym &:	$(SRC_FILES)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" --sym=$(BUILD_DIR)/megapcm.sym --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

%.h: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --sort $< $@

test:	release
	make -C test

clean:
	rm -f $(BUILD_DIR)/megapcm*
