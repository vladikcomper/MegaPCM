
TOOLCHAIN_DIR := ../toolchain
BUILD_DIR := ../build/z80
SRC_DIR := .

# Tools
SJASMPLUS ?= sjasmplus
SYMTOH := $(TOOLCHAIN_DIR)/symtoh.py
MKVOLUME := $(TOOLCHAIN_DIR)/mkvolume.py
MKDPCMTBL := $(TOOLCHAIN_DIR)/mkdpcmtbl.py

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	megapcm-z80 volume-tables dpcm-tables clean

megapcm-z80: $(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.exports.asm $(BUILD_DIR)/megapcm.exports.h $(BUILD_DIR)/megapcm.symbols.asm $(BUILD_DIR)/megapcm.symbols.h | $(BUILD_DIR)

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.sym &:	$(SRC_FILES) | $(BUILD_DIR)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" -DTRACEPATH=\"$(BUILD_DIR)/megapcm.tracedata.txt\" --exp=$(BUILD_DIR)/megapcm.exports.sym --sym=$(BUILD_DIR)/megapcm.symbols.sym --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

volume-tables:	$(SRC_DIR)/volume-tables.asm

dpcm-tables: $(SRC_DIR)/dpcm-tables.asm

$(SRC_DIR)/volume-tables.asm:
	$(MKVOLUME) -n 16 $@

$(SRC_DIR)/dpcm-tables.asm:
	$(MKDPCMTBL) $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

%.h: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --locals $< $@

%.asm: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --outputFormat asm $< $@

clean:
	rm -f $(BUILD_DIR)/*
