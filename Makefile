
# Executables
SJASMPLUS ?= sjasmplus

BUILD_DIR := build
SRC_DIR := src

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	megapcm clean

megapcm: build/megapcm.bin

build/megapcm.bin:	$(SRC_FILES)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

clean:
	rm -f $(BUILD_DIR)/*
