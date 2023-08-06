
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

	/* YM state */
	uint8_t ymPort0Reg;
	uint8_t ymPort1Reg;
	uint8_t ymGlobalRegValues [0x10];	// regs 20h .. 2Fh

	/* ROM support */
	uint8_t* ROM;
	size_t ROMsize;
	uint16_t ROMBankId;
	uint8_t ROMBankRegPos;

	/* Callback support */
	Z80VM_WriteByteCallback onWriteByte;
	Z80VM_ReadByteCallback onReadByte;
};


Z80VM_Context * Z80VM_Init();

void Z80VM_LoadProgram(Z80VM_Context * context, const uint8_t * buffer, size_t bufferSize);

size_t Z80VM_Emulate(Z80VM_Context * context, size_t cycles);

void Z80VM_Destroy(Z80VM_Context * context);


/* -------------------------------------------- */
/* VM-specific inline functions					*/
/* -------------------------------------------- */

static inline void Z80VM_WriteYMRegister(uint8_t reg, uint8_t val, uint8_t port, Z80VM_Context * context) {
	if (port > 0) {
		fprintf(stderr, "%s: Only YM port 0 is supported: %X %X, port %X\n", __func__, reg, val, port);
		abort();
	}
	if (reg < 0x22 || reg > 0x2B) {
		fprintf(stderr, "%s: Only registers 22..2B are supported: %X %X, port %X\n", __func__, reg, val, port);
		abort();
	}
	context->ymGlobalRegValues[reg - 0x20] = val;
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
		else if (address == 0x4002) {
			Z80VM_WriteYMRegister(context->ymPort1Reg, value, 1, context);
		}
		else {
			goto illegalWrite;
		}
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

