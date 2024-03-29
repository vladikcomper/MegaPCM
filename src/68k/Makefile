
# Include toolchain file for $(ASM68K), $(MKDIR) etc
TOOLCHAIN_DIR := ../../toolchain
include ../../toolchain.mk

BUILD_DIR := ../../build/68k
Z80_BUILD_DIR := ../../build/z80
SRC_DIR := .

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)
Z80_FILES := $(Z80_BUILD_DIR)/megapcm.bin $(Z80_BUILD_DIR)/megapcm.exports.asm

ASMFLAGS := /q /k /m /o c+,ws+,op+,os+,ow+,oz+,oaq+,osq+,omq+,ae-

.PHONY:	all megapcm-blob megapcm-linkable megapcm-debug-linkable megapcm-z80 clean

all:	megapcm-blob megapcm-linkable megapcm-debug-linkable

megapcm-z80:
	$(MAKE) -C ../z80

megapcm-blob:	megapcm-z80 $(BUILD_DIR)/megapcm.bin

megapcm-linkable:	megapcm-z80 $(BUILD_DIR)/megapcm.obj

megapcm-debug-linkable:	megapcm-z80 $(BUILD_DIR)/megapcm.debug.obj

$(BUILD_DIR)/megapcm.bin $(BUILD_DIR)/megapcm.sym &:	$(SRC_FILES) $(Z80_FILES) | $(BUILD_DIR)
	$(ASM68K) $(ASMFLAGS) /p $(SRC_DIR)/megapcm.asm,$@,$(BUILD_DIR)/megapcm.sym

$(BUILD_DIR)/megapcm.obj:	$(SRC_FILES) $(Z80_FILES) | $(BUILD_DIR)
	$(ASM68K) $(ASMFLAGS) /l $(SRC_DIR)/megapcm.asm,$@

$(BUILD_DIR)/megapcm.debug.obj:	$(SRC_FILES) $(Z80_FILES) | $(BUILD_DIR)
	$(ASM68K) $(ASMFLAGS) /o v+ /e __DEBUG__ /l $(SRC_DIR)/megapcm.asm,$@

$(Z80_FILES):	megapcm-z80

$(BUILD_DIR):
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$(BUILD_DIR)"

clean:
	$(MAKE) -C ../z80 clean
	$(RM) $(BUILD_DIR)/*
