
# Executables
SJASMPLUS ?= sjasmplus

TOOLCHAIN_DIR := toolchain
BUILD_DIR := build
SRC_DIR := src

SYMTOH := $(TOOLCHAIN_DIR)/symtoh.py
MKVOLUME := $(TOOLCHAIN_DIR)/mkvolume.py
MKDPCMTBL := $(TOOLCHAIN_DIR)/mkdpcmtbl.py

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	megapcm volume-tables dpcm-tables test clean

megapcm: $(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.exports.asm $(BUILD_DIR)/megapcm.symbols.asm $(BUILD_DIR)/megapcm.symbols.h

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.sym &:	$(SRC_FILES)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" -DTRACEPATH=\"$(BUILD_DIR)/megapcm.tracedata.txt\" --exp=$(BUILD_DIR)/megapcm.exports.sym --sym=$(BUILD_DIR)/megapcm.symbols.sym --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

volume-tables:	$(SRC_DIR)/volume-tables.asm

dpcm-tables: $(SRC_DIR)/dpcm-tables.asm

$(SRC_DIR)/volume-tables.asm:
	$(MKVOLUME) -n 16 $@

$(SRC_DIR)/dpcm-tables.asm:
	$(MKDPCMTBL) $@

%.h: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --locals $< $@

%.asm: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --outputFormat asm $< $@

test:	megapcm
	make -C test

clean:
	rm -f $(BUILD_DIR)/megapcm*
	make -C test clean
