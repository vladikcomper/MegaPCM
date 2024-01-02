
#include "megapcm-emu.h"
#include "z80vm.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


void MPCM_LoadDriver(Z80VM_Context * context, const char * path) {
	FILE * stream = fopen(path, "rb");
	if (!stream) {
		fprintf(stderr, "Unable to open Mega PCM binary\n");
		abort();
	}

	fseek(stream, 0, SEEK_END);
	const size_t bufferSize = ftell(stream);
	fseek(stream, 0, SEEK_SET);

	uint8_t * buffer = malloc(bufferSize);
	if (!buffer) {
		fprintf(stderr, "Unable to allocate buffer for Mega PCM binary\n");
		abort();		
	}

	if (fread(buffer, bufferSize, 1, stream) != 1) {
		free(buffer);
		fclose(stream);
		fprintf(stderr, "Unable to read Mega PCM binary\n");
		abort();
	}
	fclose(stream);

	Z80VM_LoadProgram(context, buffer, bufferSize);

	free(buffer);
}


void MPCM_WaitForInitialization(Z80VM_Context * context) {
	/* Mega PCM shouldn't take longer than this to initialize */
	const size_t MAX_FRAMES_FOR_INIT = 4;

	/* We must substitute a small ROM so MegaPCM's calibration loop doesn't fail */
	const uint8_t ROM[] = { 0x00 };
	context->ROM = ROM;
	context->ROMsize = sizeof(ROM);

	uint8_t isReady = 0;
	uint8_t lastErrorCode = 0;

	size_t frame = 0;
	size_t prevFrameOvershootCycles = 0;
	for (; frame < MAX_FRAMES_FOR_INIT && !isReady && !lastErrorCode; ++frame) {
		prevFrameOvershootCycles = Z80VM_EmulateTVFrame(context, prevFrameOvershootCycles);

		isReady = Z80_ReadByte(Z_MPCM_DriverReady, context);
		lastErrorCode = Z80_ReadByte(Z_MPCM_LastErrorCode, context);
	}

	assert(isReady == 'R');
	if (lastErrorCode) {
		MPCM_ThrowLastErrorCode(context);
	}

	fprintf(stderr, "Mega PCM initialized after %ld frames\n", frame);
	fprintf(stderr, "Calibration report: Calibrated=%d, ROMScore=%d, RAMScore=%d\n",
		Z80_ReadByte(Z_MPCM_CalibrationApplied, context),
		Z80_ReadWord(Z_MPCM_CalibrationScore_ROM, context),
		Z80_ReadWord(Z_MPCM_CalibrationScore_RAM, context)
	);

}


void MPCM_ThrowLastErrorCode(Z80VM_Context * context) {
	const uint8_t lastErrorCode = Z80_ReadByte(Z_MPCM_LastErrorCode, context);

	fputs("Mega PCM exception: ", stderr);

	switch (lastErrorCode) {
	case Z_MPCM_ERROR__BAD_INTERRUPT:
		fputs("Bad Interrupt\n", stderr);
		break;

	case Z_MPCM_ERROR__UNKNOWN_COMMAND:
		fputs("Unkown command\n", stderr);
		break;

	case Z_MPCM_ERROR__BAD_SAMPLE_TYPE:
		fputs("Invalid sample type\n", stderr);
		break;

	default:
		fprintf(stderr, "Unknown error code: %02X\n", lastErrorCode);
	}

	abort();
}
