
SRC_DIR := ./src
BUILD_DIR := ./build
TOOLCHAIN_DIR := ./toolchain

SJASMPLUS := $(shell which sjasmplus)
SJASMPLUS_LOCAL := $(TOOLCHAIN_DIR)/sjasmplus/sjasmplus

# If sjasmplus is not installed, use a locally-built version
ifndef SJASMPLUS
SJASMPLUS := $(SJASMPLUS_LOCAL)
endif

.PHONY:	megapcm clean

megapcm:	$(BUILD_DIR)/megapcm.bin

$(SJASMPLUS_LOCAL):
	$(MAKE) -C $(TOOLCHAIN_DIR) sjasmplus_local

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/megapcm.bin:	$(wildcard $(SRC_DIR)/*.asm) | $(SJASMPLUS) $(BUILD_DIR)
	$(SJASMPLUS) --raw=$(BUILD_DIR)/megapcm.bin --lst=$(BUILD_DIR)/megapcm.lst $(SRC_DIR)/main.asm

clean:
	rm -drf $(BUILD_DIR)
