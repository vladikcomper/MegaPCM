
SRC_DIR ?= ./src
BUILD_DIR ?= ./build
TOOLCHAIN_DIR ?= ./toolchain

SJASMPLUS = sjasmplus

.PHONY:	megapcm clean

megapcm:	$(BUILD_DIR)/megapcm.bin

$(BUILD_DIR)/megapcm.bin:	$(wildcard $(SRC_DIR)/*.asm)
	$(SJASMPLUS) --raw=$(BUILD_DIR)/megapcm.bin --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/main.asm

clean:
	rm out/*
