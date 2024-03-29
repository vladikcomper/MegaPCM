
# Include toolchain file for $(SJASMPLUS), $(MKVOLUME), $(MKDIR) etc
TOOLCHAIN_DIR := ../../toolchain
include ../../toolchain.mk

BUILD_DIR := ../../build/z80
SRC_DIR := .

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	megapcm-z80 volume-tables dpcm-tables clean

megapcm-z80: $(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.exports.asm $(BUILD_DIR)/megapcm.exports.h $(BUILD_DIR)/megapcm.symbols.asm $(BUILD_DIR)/megapcm.symbols.h | $(BUILD_DIR)

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.sym &:	$(SRC_FILES) | $(BUILD_DIR)
	$(SJASMPLUS) -DOUTPATH=\"$(BUILD_DIR)/megapcm.bin\" -DTRACEPATH=\"$(BUILD_DIR)/megapcm.tracedata.txt\" --exp=$(BUILD_DIR)/megapcm.exports.sym --sym=$(BUILD_DIR)/megapcm.symbols.sym --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/megapcm.asm

volume-tables:	$(SRC_DIR)/volume-tables.asm

dpcm-tables: $(SRC_DIR)/dpcm-tables.asm

$(SRC_DIR)/volume-tables.asm:
	$(MKVOLUME) -n 16 $@

$(SRC_DIR)/dpcm-hq-tables.asm:
	$(MKDPCMTBL) --table -34 -21 -13 -8 -5 -3 -2 -1 0 1 2 3 5 8 13 21 $@

$(SRC_DIR)/dpcm-tables.asm:
	$(MKDPCMTBL) $@

$(BUILD_DIR):
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$(BUILD_DIR)"

%.h: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --locals $< $@

%.asm: %.sym
	$(SYMTOH) --prefix "Z_MPCM_" --outputFormat asm $< $@

clean:
	$(RM) $(BUILD_DIR)/*
