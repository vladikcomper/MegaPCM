
#include "z80emu.h"
#include "z80vm.h"

#include "megapcm.debug.h"

#include <assert.h>
#include <bits/stdint-uintn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

const size_t MAX_CYCLES = 100000;
const size_t CYCLES_PER_ITERATION = 100;

typedef struct {
	uint8_t type;
	uint8_t flags;
	uint8_t pitch;
	uint8_t startBank;
	uint8_t endBank;
	uint16_t startOffset;
	uint16_t endOffset;
} __attribute__((packed)) Sample;

typedef struct {
	uint32_t offset;
	uint32_t length;
	uint8_t pitch;
	uint8_t pitchCounter;
} EmulatedPlaybackState;

const uint8_t sample_2[]   = { 0xFF, 0xFF };
const uint8_t sample_8[]   = { 0, 1, 2, 3, 4, 5, 6, 7 };
const uint8_t sample_254[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 
							   21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 
							   39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 
							   57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 
							   75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 
							   93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 
							   109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 
							   124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 
							   139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 
							   154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 
							   169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 
							   184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 
							   199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 
							   214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 
							   229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 
							   244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254 };

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

void throwMegaPCMError(uint8_t errorCode, Z80VM_Context * context) {
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
	abort();
}

void waitMegaPCMReady(Z80VM_Context * context) {
	size_t cycles_emulated = 0;
	uint8_t isReady = 0;
	uint8_t errorCode = 0;

	while (cycles_emulated < MAX_CYCLES && !isReady && !errorCode) {
		cycles_emulated += Z80VM_Emulate(context, CYCLES_PER_ITERATION);
		
		isReady = Z80_ReadByte(Z_MPCM_DriverReady, context);
		errorCode = Z80_ReadByte(Z_MPCM_Debug_ErrorCode, context);
	}

	assert(isReady == 'R');
	if (errorCode) {
		throwMegaPCMError(errorCode, context);
	}
}

/* Lightweight emulator of Mega PCM's playback routine to ensure driver operates correctly */
uint8_t emulateSamplePlayback(Z80VM_Context * context) {
	EmulatedPlaybackState * playbackState = context->stateExtension;

	if (!playbackState) {
		fprintf(stderr, "Playback state is NULL in Z80VM context\n");
		abort();
	}
	if (playbackState->length == 0) {
		fprintf(stderr, "Attempt to read past the end of sample\n");
		abort();
	}

	/* Fetch sample */
	uint8_t sample = context->ROM[playbackState->offset];

	/* Apply pitch */
	if ((uint16_t)playbackState->pitchCounter + (uint16_t)playbackState->pitch >= 0x100) {
		playbackState->offset++;
		playbackState->length--;
	}
	playbackState->pitchCounter += playbackState->pitch;

	return sample;
}

void runTest_WriteByteCallback(uint16_t address, uint8_t value, Z80VM_Context * context) {
	if (address == 0x4001) {
		fprintf(stderr, "YM Port 0 Write: %02X %02X\n", context->ymPort0Reg, value);

		/* For DAC output, make sure we output the exact same bytes we request */
		if (context->ymPort0Reg == 0x2A) {
			const uint8_t sample = value;
			const uint8_t expectedSample = emulateSamplePlayback(context);

			if (sample != expectedSample) {
				fprintf(stderr, "Invalid sample played: EXPECTED %02X, GOT %02X\n", expectedSample, sample);
				abort();
			}
		}
	}
	else if (address == 0x4003) {
		fprintf(stderr, "YM Port 1 Write: %02X %02X\n", context->ymPort1Reg, value);
	}
	else if (address == 0x6000) {
		fprintf(stderr, "Rotating bank register: %04X\n", context->ROMBankId);
	}
}

void runTest(Z80VM_Context * context, const uint8_t * sample, const size_t sampleSize, uint32_t startOffsetInROM) {

	fprintf(stderr, "Testing sample: %ld bytes, @%X...\n", sampleSize, startOffsetInROM);

	const uint8_t pitch = 0xFF;

	/* Setup callbacks */
	context->onWriteByte = &runTest_WriteByteCallback;

	/* Create empty 1 MB ROM, copy sample to `startOffsetInROM` */
	uint8_t * ROM = calloc(1024 * 1024, 1);
	for (size_t offset = 0; offset < sampleSize; ++offset) {
		ROM[offset + startOffsetInROM] = sample[offset];
	}
	context->ROM = ROM;
	context->ROMsize = 1024 * 1024;

	/* Setup sample */
	Sample * sampleInput = (Sample*) &context->programRAM[Z_MPCM_SampleInput];
	sampleInput->type = 'P';
	sampleInput->pitch = pitch;
	sampleInput->startBank = startOffsetInROM >> 15;
	sampleInput->startOffset = 0x8000 | (startOffsetInROM & 0x7FFE);
	sampleInput->endBank = (startOffsetInROM + sampleSize) >> 15;
	sampleInput->endOffset = 0x8000 | ((startOffsetInROM + sampleSize) & 0x7FFE);

	/* Setup playback emulation state */
	EmulatedPlaybackState playbackState = {
		.offset = startOffsetInROM,
		.length = sampleSize,
		.pitch = pitch,
		.pitchCounter = 0
	};
	context->stateExtension = &playbackState;

	/* Start emulation */
	const size_t MAX_CYCLES = 100000;
	const size_t CYCLES_PER_ITERATION = 100;
	size_t cycles_emulated = 0;

	uint8_t errorCode = 0;

	/* Request sample playback */
	Z80_WriteByte(Z_MPCM_CommandInput, 0x80, context);

	/* Emulate Mega PCM now */
	size_t cycles_to_emulate = MAX_CYCLES;
	while (cycles_emulated < cycles_to_emulate && !errorCode) {
		cycles_emulated += Z80VM_Emulate(context, CYCLES_PER_ITERATION);

		/* If playback is over, quit shortly */
		if (playbackState.length == 0 && cycles_to_emulate == MAX_CYCLES) {
			cycles_to_emulate = cycles_emulated + 1000;
		}

		errorCode = Z80_ReadByte(Z_MPCM_Debug_ErrorCode, context);
	}

	if (errorCode) {
		throwMegaPCMError(errorCode, context);
	}
	assert(cycles_emulated < MAX_CYCLES);
	assert(playbackState.length == 0);

	/* 
	 * Test passes if no exceptions are thrown;
	 * "runTest_WriteByteCallback" takes care of verifying playback state
	 */

	free(ROM);
}

int main(int argc, char * argv[]) {

	Z80VM_Context * context = Z80VM_Init();

	uint8_t * buffer;
	size_t bufferSize;
	loadMegaPCM("../build/megapcm.debug.bin", &buffer, &bufferSize);

	Z80VM_LoadProgram(context, buffer, bufferSize);

	waitMegaPCMReady(context);

	/* Run actual tests */

	/* No-bankswitching */
	runTest(context, sample_2, sizeof(sample_2), 0);
	runTest(context, sample_8, sizeof(sample_8), 0);
	runTest(context, sample_254, sizeof(sample_254), 0);

	/* With bankswitching */
	runTest(context, sample_2, sizeof(sample_2), 0x7FFE);
	runTest(context, sample_8, sizeof(sample_8), 0x7FFE);
	runTest(context, sample_254, sizeof(sample_254), 0x7FFE);

	Z80VM_Destroy(context);

	puts("OK");

	return 0;
}
