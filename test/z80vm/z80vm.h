
#pragma once

#include "z80emu.h"

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

/* -------------------------------------------- */
/* Z80 VM API                                   */
/* -------------------------------------------- */

typedef struct {
	/* Z80 program RAM (0000h-1FFFh) */
	uint8_t programRAM [0x2000];

	/* Z80 CPU state */
	Z80_STATE z80State;

	/* Current ROM bank */
	uint16_t ROMBankId;

	/* ROM contents */
	uint8_t* ROM;
} Z80VM_Context;


Z80VM_Context * Z80VM_Init();

void Z80VM_LoadProgram(Z80VM_Context * context, void * buffer, size_t bufferSize);

// void * Z80VM_Emulate(Z80VM_Context * context);

void Z80VM_Destroy(Z80VM_Context * context);


/* -------------------------------------------- */
/* Inline functions to provide API for "z80emu" */
/* -------------------------------------------- */

static inline uint8_t Z80_ReadByte(uint16_t address, Z80VM_Context * context) {
	if (address < 0x2000) {
		return context->programRAM[address];
	}
	fprintf(stderr, "%s: Illegal read: %04X", __func__, address);
	abort();
}


static inline uint16_t Z80_ReadWord(uint16_t address, Z80VM_Context * context) {
	return Z80_ReadByte(address, context) | (Z80_ReadByte(address + 1, context) << 8);
}


static inline void Z80_WriteByte(uint16_t address, uint8_t value, Z80VM_Context * context) {
	if (address < 0x2000) {
		context->programRAM[address] = value;
	}
	fprintf(stderr, "%s: Illegal write: %04X: %02X", __func__, address, value);
	abort();
}


static inline void Z80_WriteWord(uint16_t address, uint16_t value, Z80VM_Context * context) {
	Z80_WriteByte(address, value & 0xFF, context);
	Z80_WriteByte(address, value >> 8, context);
}


static inline void Z80_OutputByte(uint8_t port, uint8_t byte, Z80VM_Context * context) {
	fprintf(stderr, "%s: Output not implemented: port %02X, byte %02X", __func__, port, byte);
	abort();
}


static inline int8_t Z80_InputByte(uint8_t port, Z80VM_Context * context) {
	fprintf(stderr, "%s: Input not implemented: port %02X", __func__, port);
	abort();
}

