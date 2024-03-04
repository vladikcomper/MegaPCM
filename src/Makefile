# Include toolchain file for $(BLOBTOASM), $(CBUNDLE), $(CONVSYM) etc
TOOLCHAIN_DIR := ../toolchain
include ../toolchain.mk

BUILD_DIR := ../build/bundle
LIB_BUILD_DIR := ../build/68k
SRC_DIR := .
LIB_SRC_DIR := ./68k

SRC_FILES := $(wildcard $(SRC_DIR)/*.asm)

.PHONY:	all asm68k asm68k-linkable as megapcm-68k

all:	asm68k asm68k-linkable as

megapcm-68k:
	$(MAKE) -C 68k

asm68k:	$(BUILD_DIR)/asm68k/MegaPCM.asm

asm68k-linkable:	$(BUILD_DIR)/asm68k-linkable/MegaPCM.asm $(BUILD_DIR)/asm68k-linkable/MegaPCM.obj $(BUILD_DIR)/asm68k-linkable/MegaPCM.Debug.obj

as:	$(BUILD_DIR)/as/MegaPCM.asm

$(BUILD_DIR)/asm68k-linkable/MegaPCM.asm:	$(SRC_FILES) $(LIB_SRC_DIR)/sample-table.defs.asm $(LIB_SRC_DIR)/load-sample-table.defs.asm | $(BUILD_DIR)/asm68k-linkable
	$(CBUNDLE) $(SRC_DIR)/MegaPCM.asm -def BUNDLE-ASM68K -def LINKABLE -out $@

$(BUILD_DIR)/asm68k-linkable/MegaPCM.obj:	$(LIB_BUILD_DIR)/megapcm.obj | $(BUILD_DIR)/asm68k-linkable
	$(CP) $^ $@

$(BUILD_DIR)/asm68k-linkable/MegaPCM.Debug.obj:	$(LIB_BUILD_DIR)/megapcm.debug.obj | $(BUILD_DIR)/asm68k-linkable
	$(CP) $^ $@

$(BUILD_DIR)/asm68k/MegaPCM.asm:	$(SRC_FILES) $(LIB_SRC_DIR)/sample-table.defs.asm $(LIB_SRC_DIR)/load-sample-table.defs.asm $(BUILD_DIR)/MegaPCM.Blob.asm $(BUILD_DIR)/MegaPCM.Symbols.asm | $(BUILD_DIR)/asm68k
	$(CBUNDLE) $(SRC_DIR)/MegaPCM.asm -def BUNDLE-ASM68K -out $@

$(BUILD_DIR)/as/MegaPCM.asm:	$(SRC_FILES) $(LIB_SRC_DIR)/sample-table.defs.asm $(LIB_SRC_DIR)/load-sample-table.defs.asm $(BUILD_DIR)/MegaPCM.Blob.asm $(BUILD_DIR)/MegaPCM.Symbols.asm | $(BUILD_DIR)/as
	$(CBUNDLE) $(SRC_DIR)/MegaPCM.asm -def BUNDLE-AS -out $@

$(BUILD_DIR)/MegaPCM.Blob.asm:	$(LIB_BUILD_DIR)/megapcm.bin | $(BUILD_DIR)
	$(BLOBTOASM) $^ $@

$(BUILD_DIR)/MegaPCM.Symbols.asm: $(LIB_BUILD_DIR)/megapcm.sym | $(BUILD_DIR)
	$(CONVSYM) $(LIB_BUILD_DIR)/megapcm.sym $@ -out asm -outopt "%s:	equ	MegaPCMLibraryBlob+$$%X"

$(BUILD_DIR):
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$@"

$(BUILD_DIR)/as:
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$@"

$(BUILD_DIR)/asm68k:
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$@"

$(BUILD_DIR)/asm68k-linkable:
	# Quotes are mandatory in Windows so MKDIR recognizes Unix slashes
	$(MKDIR) "$@"

$(LIB_BUILD_DIR)/megapcm.obj $(LIB_BUILD_DIR)/megapcm.debug.obj $(LIB_BUILD_DIR)/megapcm.bin $(LIB_BUILD_DIR)/megapcm.sym:	megapcm-68k

clean:
	$(MAKE) -C 68k clean
	$(RM) $(BUILD_DIR)/*
