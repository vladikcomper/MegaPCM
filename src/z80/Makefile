
# Include toolchain file for $(SJASMPLUS), $(MKVOLUME), $(MKDIR) etc
TOOLCHAIN_DIR := ../../toolchain
include ../../toolchain.mk

BUILD_DIR := ../../build/z80
SRC_DIR := .

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	megapcm-z80 volume-tables clean

megapcm-z80: $(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.exports.asm $(BUILD_DIR)/megapcm.exports.h $(BUILD_DIR)/megapcm.symbols.asm $(BUILD_DIR)/megapcm.symbols.h | $(BUILD_DIR)

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.symbols.sym &:	$(SRC_FILES) | $(BUILD_DIR)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" -DTRACEPATH=\"$(BUILD_DIR)/megapcm.tracedata.txt\" --exp=$(BUILD_DIR)/megapcm.exports.sym --sym=$(BUILD_DIR)/megapcm.symbols.sym --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

volume-tables:	$(SRC_DIR)/volume-tables.asm

$(SRC_DIR)/volume-tables.asm:
	$(MKVOLUME) -n 16 $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

%.h: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --locals $< $@

%.asm: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --outputFormat asm $< $@

clean:
	rm -rf $(BUILD_DIR)/*
