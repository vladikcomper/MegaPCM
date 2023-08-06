
#include "z80vm.h"
#include "megapcm.h"

#include <assert.h>
#include <bits/stdint-uintn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


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

	/* Setup callbacks */
	context->onWriteByte = &WriteByteCallback;
	// context->onReadByte = &ReadByteCallback;

	/* Start emulation */
	const size_t MAX_CYCLES = 100000;
	const size_t CYCLES_PER_ITERATION = 1000;
	size_t cycles_emulated = 0;

	while (cycles_emulated < MAX_CYCLES) {
		cycles_emulated += Z80VM_Emulate(context, CYCLES_PER_ITERATION);
		
		uint16_t bufferPos = Z80_ReadWord(Z_MPCM_Debug_BufferPos, context);
		if (bufferPos == Z_MPCM_SampleBuffer + 0xFF) {
			break;
		}
	}

	assert(cycles_emulated < MAX_CYCLES);
	assert(Z80_ReadWord(Z_MPCM_Debug_BufferPos, context) == Z_MPCM_SampleBuffer + 0xFF);

	Z80VM_Destroy(context);

	puts("OK");

	return 0;
}
