
SRC_DIR ?= ./src
OUT_DIR ?= ./out
TOOLCHAIN_DIR ?= ./toolchain

SJASM = $(TOOLCHAIN_DIR)/sjasm

.PHONY:	megapcm clean

megapcm:	$(OUT_DIR)/megapcm.bin

$(OUT_DIR)/megapcm.bin:	$(wildcard $(SRC_DIR)/*.asm)
	$(SJASM) $(SRC_DIR)/main.asm $(OUT_DIR)/megapcm.bin $(OUT_DIR)/megapcm.lst

clean:
	rm out/*
