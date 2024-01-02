
#pragma once

#include "z80emu.h"

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>


/* -------------------------------------------- */
/* Z80 VM API                                   */
/* -------------------------------------------- */

typedef struct Z80VM_Context Z80VM_Context;
typedef void (*Z80VM_WriteByteCallback)(uint16_t, uint8_t, Z80VM_Context *);
typedef void (*Z80VM_ReadByteCallback)(uint16_t, Z80VM_Context *);


struct Z80VM_Context {
	/* Z80 program RAM (0000h-1FFFh) */
	uint8_t programRAM [0x2000];

	/* Z80 CPU state */
	Z80_STATE z80State;

	/* Basic YM state */
	uint8_t ymPort0Reg;
	uint8_t ymPort1Reg;
	uint8_t ymGlobalRegValues [0x10];	// regs 20h .. 2Fh
	uint8_t ymPort0ChRegValues [0xB8 - 0xA0];	// regs 0xA0 .. 0xB8 (FM1-3)
	uint8_t ymPort1ChRegValues [0xB8 - 0xA0];	// regs 0xA0 .. 0xB8 (FM4-6)

	/* Basic VDP support */
	size_t VDPFrame;
	uint16_t VDPScanline;
	enum { NTSC, PAL } VPDRegion;

	/* ROM support */
	const uint8_t* ROM;
	size_t ROMsize;
	uint16_t ROMBankId;
	uint8_t ROMBankRegPos;

	/* Callback support */
	Z80VM_WriteByteCallback onWriteByte;
	Z80VM_ReadByteCallback onReadByte;

	/* Custom state extension (can be set to any external struct) */
	void * stateExtension;
};


Z80VM_Context * Z80VM_Init();

void Z80VM_LoadProgram(Z80VM_Context * context, const uint8_t * buffer, size_t bufferSize);

size_t Z80VM_Emulate(Z80VM_Context * context, size_t cycles);

size_t Z80VM_EmulateSubroutine(Z80VM_Context *context, uint16_t pc, size_t maxCycles);

size_t Z80VM_EmulateTVFrame(Z80VM_Context * context, size_t prevFrameOvershootCycles);

void Z80VM_Destroy(Z80VM_Context * context);


/* -------------------------------------------- */
/* VM-specific inline functions					*/
/* -------------------------------------------- */

static inline void Z80VM_WriteYMRegister(uint8_t reg, uint8_t val, uint8_t port, Z80VM_Context * context) {
	// Per-channel regiters (Port 0, 1)
	if (reg >= 0xA0 && reg <= 0xB8) {
		(port == 0 ? context->ymPort0ChRegValues : context->ymPort1ChRegValues)[reg - 0xA0] = val;
	}
	// Global registers (Port 0 only)
	else if (port == 0 && reg >= 0x22 && reg <= 0x2B) {
		context->ymGlobalRegValues[reg - 0x20] = val;
	}
	else {
		fprintf(stderr, "%s: Illegal or unsupported YM write: %X %X, port %X\n", __func__, reg, val, port);
		abort();
	}
}

static inline uint8_t Z80VM_ReadROMByte(uint16_t address, Z80VM_Context * context) {
	if (address < 0x8000) {
		fprintf(stderr, "%s: Invalid in-bank address: %04X\n", __func__, address);
		abort();
	}
	const size_t absoluteAddress = (address & 0x7FFF) + context->ROMBankId * 0x8000;
	if (absoluteAddress >= context->ROMsize) {
		fprintf(stderr, "%s: Attempt to read outside of ROM: %08lX (pc=%04X)\n", __func__, absoluteAddress, context->z80State.pc);
		abort();
	}
	return context->ROM[absoluteAddress];
}


/* -------------------------------------------- */
/* Inline functions to provide API for "z80emu" */
/* -------------------------------------------- */

static inline uint8_t Z80_ReadByte(uint16_t address, Z80VM_Context * context) {
	if (context->onReadByte) {
		context->onReadByte(address, context);
	}

	if (address < 0x2000) {
		return context->programRAM[address];
	}
	else if (address >= 0x8000) {
		return Z80VM_ReadROMByte(address, context);
	}

	fprintf(stderr, "%s: Illegal read: %04X\n", __func__, address);
	abort();
}


static inline uint16_t Z80_ReadWord(uint16_t address, Z80VM_Context * context) {
	return Z80_ReadByte(address, context) | (Z80_ReadByte(address + 1, context) << 8);
}


static inline void Z80_WriteByte(uint16_t address, uint8_t value, Z80VM_Context * context) {
	if (context->onWriteByte) {
		context->onWriteByte(address, value, context);
	}

	/* Z80 RAM */
	if (address < 0x2000) {
		context->programRAM[address] = value;
	}

	/* YM Ports */
	else if ((address & 0xF000) == 0x4000) {
		if (address == 0x4000) {
			context->ymPort0Reg = value;
		}
		else if (address == 0x4001) {
			Z80VM_WriteYMRegister(context->ymPort0Reg, value, 0, context);
		}
		else if (address == 0x4002) {
			context->ymPort1Reg = value;
		}
		else if (address == 0x4003) {
			Z80VM_WriteYMRegister(context->ymPort1Reg, value, 1, context);
		}
		else {
			goto illegalWrite;
		}
	}

	/* Bank register */
	else if (address == 0x6000) {
		context->ROMBankId = (context->ROMBankId >> 1 | value << 8) & 0x1FF;
	}

	else {
	illegalWrite:
		fprintf(stderr, "%s: Illegal write: %04X: %02X\n", __func__, address, value);
		abort();
	}
}


static inline void Z80_WriteWord(uint16_t address, uint16_t value, Z80VM_Context * context) {
	Z80_WriteByte(address, value & 0xFF, context);
	Z80_WriteByte(address + 1, value >> 8, context);
}


static inline void Z80_OutputByte(uint8_t port, uint8_t byte, Z80VM_Context * context) {
	fprintf(stderr, "%s: Output not implemented: port %02X, byte %02X\n", __func__, port, byte);
	abort();
}


static inline int8_t Z80_InputByte(uint8_t port, Z80VM_Context * context) {
	fprintf(stderr, "%s: Input not implemented: port %02X\n", __func__, port);
	abort();
}

