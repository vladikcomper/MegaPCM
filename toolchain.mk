
# This Makfile shouldn't be invoked directly!

ifndef TOOLCHAIN_DIR
$(error TOOLCHAIN_DIR wasn't specified. Don't invoke this file directly!)
endif

# Identify Python 3 installation
ifndef PYTHON
ifeq ($(shell python -c "import sys; print(sys.version_info[0])"),3)
	PYTHON := python
else ifeq ($(shell python3 -c "import sys; print(sys.version_info[0])"),3)
	PYTHON := python3
else
$(error Couldn't find Python 3 in your system. Please install it or manually specify PYTHON variable)
endif
endif


SJASMPLUS := sjasmplus
AS := wine $(TOOLCHAIN_DIR)/as/asw.exe
P2BIN := wine $(TOOLCHAIN_DIR)/as/p2bin.exe
ASM68K := wine $(TOOLCHAIN_DIR)/asm68k.exe
PSYLINK := wine $(TOOLCHAIN_DIR)/psylink.exe
CONVSYM := convsym
CBUNDLE := cbundle
BLOBTOASM := $(PYTHON) $(TOOLCHAIN_DIR)/blobtoasm.py
SYMTOH := $(PYTHON) $(TOOLCHAIN_DIR)/symtoh.py
MKVOLUME := $(PYTHON) $(TOOLCHAIN_DIR)/mkvolume.py
CC := cc

# Fallback to Wine if some tools aren't installed
ifeq (,$(shell which $(SJASMPLUS)))
	SJASMPLUS := wine $(TOOLCHAIN_DIR)/sjasmplus.exe
endif
ifeq (,$(shell which $(CONVSYM)))
	CONVSYM := wine $(TOOLCHAIN_DIR)/convsym.exe
endif
ifeq (,$(shell which $(CBUNDLE)))
	CBUNDLE := wine $(TOOLCHAIN_DIR)/cbundle.exe
endif
