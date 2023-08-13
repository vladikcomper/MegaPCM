
#include "z80emu.h"
#include "z80vm.h"
#include "megapcm.h"

#include <assert.h>
#include <bits/stdint-uintn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
	uint8_t type;
	uint8_t startBank;
	uint16_t startOffset;
	uint8_t endBank;
	uint16_t endLen;
	uint8_t pitch;
	uint8_t flags;
} __attribute__((packed)) Sample;

const uint8_t ROM[] = {
	1, 2, 3, 4, 5, 6, 7, 8
};

void loadMegaPCM(const char * path, uint8_t ** buffer, size_t * bufferSize) {
	FILE * stream = fopen(path, "rb");
	if (!stream) {
		fprintf(stderr, "Unable to open Mega PCM binary\n");
		abort();
	}

	fseek(stream, 0, SEEK_END);
	*bufferSize = ftell(stream);
	fseek(stream, 0, SEEK_SET);

	*buffer = malloc(*bufferSize);
	if (!*buffer) {
		fprintf(stderr, "Unable to allocate buffer for Mega PCM binary\n");
		abort();		
	}

	if (fread(*buffer, *bufferSize, 1, stream) != 1) {
		fprintf(stderr, "Unable to read Mega PCM binary\n");
		abort();
	}

	fclose(stream);
}

void WriteByteCallback(uint16_t address, uint8_t value, Z80VM_Context * context) {
	if (address == 0x4001) {
		printf("YM Write: %02X %02X\n", context->ymPort0Reg, value);
	}
	// if (address < 0x2000) {
	// 	printf("RAM Write: %04X %02X\n", address, value);
	// }
}

// void ReadByteCallback(uint16_t address, Z80VM_Context * context) {
// 	printf("Read byte: address=%04X, pc=%04X\n", address, context->z80State.pc);
// }

int main(int argc, char * argv[]) {
	Z80VM_Context * context = Z80VM_Init();

	uint8_t * buffer;
	size_t bufferSize;
	loadMegaPCM("../build/megapcm.bin", &buffer, &bufferSize);

	Z80VM_LoadProgram(context, buffer, bufferSize);

	/* Setup ROM */
	context->ROM = ROM;
	context->ROMsize = sizeof(ROM);

	/* Setup sample table */
	Sample * sample_80 = (Sample*) &context->programRAM[Z_MPCM_SampleTable];
	sample_80->type = 'P';
	sample_80->startBank = 0;
	sample_80->startOffset = 0x8000;
	sample_80->endBank = 0;
	sample_80->endLen = sizeof(ROM);

	/* Setup callbacks */
	context->onWriteByte = &WriteByteCallback;
	// context->onReadByte = &ReadByteCallback;

	/* Start emulation */
	const size_t MAX_CYCLES = 100000;
	const size_t CYCLES_PER_ITERATION = 100;
	size_t cycles_emulated = 0;

	int isReady = 0;
	int errorCode = 0;

	while (cycles_emulated < MAX_CYCLES && !isReady && !errorCode) {
		cycles_emulated += Z80VM_Emulate(context, CYCLES_PER_ITERATION);
		
		isReady = Z80_ReadByte(Z_MPCM_DriverIO_RAM + 1, context);
		errorCode = Z80_ReadByte(Z_MPCM_DriverIO_RAM + 4, context);
	}

	// Request sample 80
	Z80_WriteByte(Z_MPCM_DriverIO_RAM + 0, 0x80, context);

	while (cycles_emulated < MAX_CYCLES && !errorCode) {
		cycles_emulated += Z80VM_Emulate(context, CYCLES_PER_ITERATION);

		errorCode = Z80_ReadByte(Z_MPCM_DriverIO_RAM + 4, context);
	}

	if (errorCode) {
		fprintf(stderr, "errorCode = %d\n", errorCode);
		fprintf(stderr, "af = %04X, bc = %04X\n", context->z80State.registers.word[Z80_AF], context->z80State.registers.word[Z80_BC]);
		fprintf(stderr, "de = %04X, hl = %04X\n", context->z80State.registers.word[Z80_DE], context->z80State.registers.word[Z80_HL]);
		fprintf(stderr, "ix = %04X, iy = %04X\n", context->z80State.registers.word[Z80_IX], context->z80State.registers.word[Z80_IY]);
		fprintf(stderr, "sp = %04X\n", context->z80State.registers.word[Z80_SP]);
		fprintf(stderr, "Stack: ");
		for (size_t sp = context->z80State.registers.word[Z80_SP]; sp < Z_MPCM_Stack; sp += 2) {
			fprintf(stderr, "%04X ", Z80_ReadWord(sp, context));
		}
		fputs("\n", stderr);
	}

	assert(errorCode == 0);
	assert(isReady == 1);
	assert(cycles_emulated < MAX_CYCLES);

	Z80VM_Destroy(context);

	puts("OK");

	return 0;
}
