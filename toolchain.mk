
# This Makfile shouldn't be invoked directly!

ifndef TOOLCHAIN_DIR
$(error TOOLCHAIN_DIR wasn't specified)
endif

# Common python tools
BLOBTOASM := python $(TOOLCHAIN_DIR)/blobtoasm.py
SYMTOH := python $(TOOLCHAIN_DIR)/symtoh.py
MKVOLUME := python $(TOOLCHAIN_DIR)/mkvolume.py
MKDPCMTBL := python $(TOOLCHAIN_DIR)/mkdpcmtbl.py

# OS-specific tools
ifeq ($(OS),Windows_NT)
	# Windows commands
	SJASMPLUS := $(TOOLCHAIN_DIR)/sjasmplus.exe
	ASM68K := $(TOOLCHAIN_DIR)/asm68k.exe
	PSYLINK := $(TOOLCHAIN_DIR)/psylink.exe
	CONVSYM := $(TOOLCHAIN_DIR)/convsym.exe
	CBUNDLE := $(TOOLCHAIN_DIR)/cbundle.exe
	CC := gcc
	CP := copy
	MKDIR := -md
	RM := del

else
	# Unix commands
	SJASMPLUS := sjasmplus
	ASM68K := wine $(TOOLCHAIN_DIR)/asm68k.exe
	PSYLINK := wine $(TOOLCHAIN_DIR)/psylink.exe
	CONVSYM := convsym
	CBUNDLE := cbundle
	CC := cc
	CP := cp
	MKDIR := mkdir -p
	RM := rm -rf

	# Fallback to Wine if some tools aren't installed
	ifeq (,$(shell which %$(SJASMPLUS)))
		SJASMPLUS := wine $(TOOLCHAIN_DIR)/sjasmplus.exe
	endif
	ifeq (,$(shell which $(CONVSYM)))
		CONVSYM := wine $(TOOLCHAIN_DIR)/convsym.exe
	endif
	ifeq (,$(shell which $(CBUNDLE)))
		CBUNDLE := wine $(TOOLCHAIN_DIR)/cbundle.exe
	endif

endif
