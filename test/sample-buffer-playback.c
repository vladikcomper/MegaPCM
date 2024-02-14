
#include <z80vm.h>
#include <megapcm-emu.h>

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/**
 * Simple state for emulating Mega PCM's playback
 * 
 * Used to track currently played sample and compare it against what real Mega PCM outputs to YM DAC
 */
typedef struct {
	char sampleType;
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


/* Lightweight emulator of Mega PCM's playback routine to ensure driver operates correctly */
// TODO: Move this to `megapcm-emu`
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
	if ((playbackState->sampleType == 'T') || ((uint16_t)playbackState->pitchCounter + (uint16_t)playbackState->pitch >= 0x100)) {
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
			/* Log cycles elapsed since last DAC write */
			static long long last_dac_write_cycles = 0;
			if (last_dac_write_cycles != 0) {
				fprintf(stderr, "Cycles since last write: %lld\n", context->z80State.cycles_emulated - last_dac_write_cycles);
			}
			last_dac_write_cycles = context->z80State.cycles_emulated;

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

void runTest(Z80VM_Context * context, const char sampleType, const uint8_t * sample, const size_t sampleSize, uint32_t startOffsetInROM) {

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
	MPCM_Sample * sampleInput = (MPCM_Sample*) &context->programRAM[Z_MPCM_SampleInput];
	sampleInput->type = sampleType;
	sampleInput->pitch = pitch;
	sampleInput->startBank = startOffsetInROM >> 15;
	sampleInput->startOffset = 0x8000 | (startOffsetInROM & 0x7FFE);
	sampleInput->endBank = (startOffsetInROM + sampleSize) >> 15;
	sampleInput->endOffset = 0x8000 | ((startOffsetInROM + sampleSize) & 0x7FFE);

	/* Setup playback emulation state */
	EmulatedPlaybackState playbackState = {
		.sampleType = sampleType,
		.offset = startOffsetInROM,
		.length = sampleSize,
		.pitch = pitch,
		.pitchCounter = 0
	};
	context->stateExtension = &playbackState;

	/* Start emulation */
	const size_t MAX_FRAMES = 10;
	size_t frame = 0;

	uint8_t errorCode = 0;

	/* Request sample playback */
	Z80_WriteByte(Z_MPCM_CommandInput, 0x80, context);

	/* Emulate Mega PCM now */
	size_t prevFrameOvershootCycles = 0;
	for (;
		/* `playbackState` is updated by Z80 write-byte callbacks when YM DAC is written to */
		frame < MAX_FRAMES && playbackState.length != 0 && !errorCode;
		++frame
	) {
		prevFrameOvershootCycles = Z80VM_EmulateTVFrame(context, prevFrameOvershootCycles);

		errorCode = Z80_ReadByte(Z_MPCM_LastErrorCode, context);
	}

	if (errorCode) {
		MPCM_ThrowLastErrorCode(context);
	}
	assert(playbackState.length == 0);

	/* 
	 * Test passes if no exceptions are thrown;
	 * "runTest_WriteByteCallback" takes care of verifying playback state
	 */

	free(ROM);
}

int main(int argc, char * argv[]) {

	Z80VM_Context * context = Z80VM_Init();
	Z80VM_LoadTraceData(context, "../build/z80/megapcm.tracedata.txt");

	MPCM_LoadDriver(context, "../build/z80/megapcm.bin");
	MPCM_WaitForInitialization(context);

	/* Run actual tests */

	/* No-bankswitching */
	runTest(context, 'P', sample_2, sizeof(sample_2), 0);
	runTest(context, 'P', sample_8, sizeof(sample_8), 0);
	runTest(context, 'P', sample_254, sizeof(sample_254), 0);
	runTest(context, 'T', sample_2, sizeof(sample_2), 0);
	runTest(context, 'T', sample_8, sizeof(sample_8), 0);
	runTest(context, 'T', sample_254, sizeof(sample_254), 0);

	runTest(context, 'P', sample_8, sizeof(sample_8), 0x7F00);

	/* With bankswitching */
	runTest(context, 'P', sample_2, sizeof(sample_2), 0x7FFE);
	runTest(context, 'P', sample_8, sizeof(sample_8), 0x7FFE);
	runTest(context, 'P', sample_254, sizeof(sample_254), 0x7FFE);
	runTest(context, 'T', sample_2, sizeof(sample_2), 0x7FFE);
	runTest(context, 'T', sample_8, sizeof(sample_8), 0x7FFE);
	runTest(context, 'T', sample_254, sizeof(sample_254), 0x7FFE);

	Z80VM_Destroy(context);

	puts("OK");

	return 0;
}
