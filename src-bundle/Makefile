
TOOLCHAIN_DIR := ../toolchain
BUILD_DIR := ../build/bundle
LIB_BUILD_DIR := ../build/68k
SRC_DIR := .
LIB_SRC_DIR := ../src-68k

# Tools
BLOBTOASM := $(TOOLCHAIN_DIR)/blobtoasm.py
CBUNDLE := cbundle
CONVSYM := convsym

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	all asm68k asm68k-linkable megapcm-68k

all:	asm68k asm68k-linkable

megapcm-68k:
	$(MAKE) -C ../src-68k

asm68k:	$(BUILD_DIR)/asm68k/MegaPCM.asm

asm68k-linkable:	$(BUILD_DIR)/asm68k-linkable/MegaPCM.asm $(BUILD_DIR)/asm68k-linkable/MegaPCM.obj $(BUILD_DIR)/asm68k-linkable/MegaPCM.Debug.obj

$(BUILD_DIR)/asm68k-linkable/MegaPCM.asm:	$(SRC_FILES) $(LIB_SRC_DIR)/sample-table.defs.asm $(LIB_SRC_DIR)/load-sample-table.defs.asm | $(BUILD_DIR)/asm68k-linkable
	$(CBUNDLE) $(SRC_DIR)/MegaPCM.asm -def BUNDLE-ASM68K -def LINKABLE -out $@

$(BUILD_DIR)/asm68k-linkable/MegaPCM.obj:	$(LIB_BUILD_DIR)/megapcm.obj | $(BUILD_DIR)/asm68k-linkable
	cp $^ $@

$(BUILD_DIR)/asm68k-linkable/MegaPCM.Debug.obj:	$(LIB_BUILD_DIR)/megapcm.debug.obj | $(BUILD_DIR)/asm68k-linkable
	cp $^ $@

$(BUILD_DIR)/asm68k/MegaPCM.asm:	$(SRC_FILES) $(LIB_SRC_DIR)/sample-table.defs.asm $(LIB_SRC_DIR)/load-sample-table.defs.asm $(BUILD_DIR)/MegaPCM.Blob.asm $(BUILD_DIR)/MegaPCM.Symbols.asm | $(BUILD_DIR)/asm68k
	$(CBUNDLE) $(SRC_DIR)/MegaPCM.asm -def BUNDLE-ASM68K -out $@

$(BUILD_DIR)/MegaPCM.Blob.asm:	$(LIB_BUILD_DIR)/megapcm.bin | $(BUILD_DIR)
	$(BLOBTOASM) $^ $@

$(BUILD_DIR)/MegaPCM.Symbols.asm: $(LIB_BUILD_DIR)/megapcm.sym | $(BUILD_DIR)
	$(CONVSYM) $(LIB_BUILD_DIR)/megapcm.sym $@ -out asm -outopt "%s:	equ	MegaPCMLibraryBlob+$$%X"

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/asm68k:
	mkdir -p $@

$(BUILD_DIR)/asm68k-linkable:
	mkdir -p $@

$(LIB_BUILD_DIR)/megapcm.obj $(LIB_BUILD_DIR)/megapcm.debug.obj $(LIB_BUILD_DIR)/megapcm.bin $(LIB_BUILD_DIR)/megapcm.sym:	megapcm-68k

clean:
	rm -rf $(BUILD_DIR)/*
