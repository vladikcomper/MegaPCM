
#include "megapcm-emu.h"
#include "z80vm.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


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

static inline uint8_t MPCM_SampleRateToPitch(uint8_t type, uint16_t sample_rate) {
	int result = 0;	// invalid pitch
	if (type == MPCM_TYPE_PCM_TURBO && sample_rate == 32000) {
		result = 0xFF;
	}
	else if (type == MPCM_TYPE_DPCM_TURBO && sample_rate == 25800) {
		result = 0xFF;
	}
	else if (type == MPCM_TYPE_PCM) {
		result = 0x100 * sample_rate / 25208;	// TYPE_PCM_BASE_RATE
	}
	else if (type == MPCM_TYPE_DPCM) {
		result = 0x100 * sample_rate / 20691;	// TYPE_DPCM_BASE_RATE
	}
	return result > 0xFF ? 0 : result;
}

MPCM_Sample* MPCM_LoadSamplesROM(uint8_t * rom, size_t rom_size, size_t *out_num_samples) {
	if (rom_size > 0x800000) {
		fprintf(stderr, "ROM exceeds 8 MB\n");
		return NULL;
	}

	size_t num_samples = 0;
	MPCM_Sample* sample_table = NULL;
	uint8_t rom_pos = 0;

	while (1) {
		uint8_t desc = rom[rom_pos++];
		if (desc > 0x80) break;

		num_samples += 1;
		if (num_samples > 0x7F) {
			fprintf(stderr, "Too many samples in a sample table\n");
			return NULL;			
		}

		sample_table = realloc(sample_table, num_samples * sizeof(MPCM_Sample));
		if (!sample_table) {
			fprintf(stderr, "Failed to reallocate sample table\n");
			return NULL;
		}

		const uint8_t type = desc & 0xE;
		const uint8_t pitch = rom[rom_pos++];
		const uint32_t start = ((rom[rom_pos]) << 24) | ((rom[rom_pos+1]) << 16) | ((rom[rom_pos+2]) << 8) | (rom[rom_pos+3]);
		const uint32_t end = ((rom[rom_pos+4]) << 24) | ((rom[rom_pos+5]) << 16) | ((rom[rom_pos+6]) << 8) | (rom[rom_pos+7]);
		rom_pos += 8;

		sample_table[num_samples-1] = (MPCM_Sample){
			.flags = (1<<Z_MPCM_FLAGS_SAMPLE)|desc,
			.pitch = pitch,
			.startBank = start>>15,
			.startOffset = 0x8000|(start&0x7FFF),
			.endBank = end >> 15,
			.endOffset = 0x8000|(end & 0x7FFF),
		};

		if (type == MPCM_TYPE_PCM_TURBO || type == MPCM_TYPE_PCM) {
			/* Parse WAVE files */
			if (
				strncmp((char*)&rom[start], "AIFF", 4) == 0 ||
				strncmp((char*)&rom[start], "NIST", 4) == 0
			) {
				fprintf(stderr, "Invalid container (AIFF/NIST): sampleId=%zu\n", 0x80 + num_samples);
				return NULL;
			}
			if (strncmp((char*)&rom[start], "RIFF", 4) == 0) {

				if (strncmp((char*)&rom[start+8], "WAVE", 4) != 0) {
					fprintf(stderr, "Invalid WAVE header: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
				}
				size_t chunk_pos = start+12;	// "fmt" chunk
				if (strncmp((char*)&rom[chunk_pos], "fmt ", 4) != 0) {
					fprintf(stderr, "Missing 'fmt' chunk: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
				}
				const uint16_t wave_format = *(uint16_t*)&rom[chunk_pos+8];
				if (wave_format != 1 && wave_format != 0xFFFE) {
					fprintf(stderr, "Invalid audio format: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
				}
				const uint16_t num_channels = *(uint16_t*)&rom[chunk_pos+10];
				if (num_channels != 1) {
					fprintf(stderr, "Too many channels: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
				}
				const uint16_t bit_depth = *(uint16_t*)&rom[chunk_pos+22];
				if (bit_depth != 8) {
					fprintf(stderr, "Not a 8-bit audio stream: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
				}

				/* If pitch wasn't set, auto-calculate it */
				if (!pitch) {
					const uint16_t sample_rate = *(uint16_t*)&rom[rom_pos+12+12];
					sample_table[num_samples-1].pitch = MPCM_SampleRateToPitch(type, sample_rate);
				}

				/* Locate "data" chunk */
				while (strncmp((char*)&rom[chunk_pos], "data", 4) != 0) {
					chunk_pos += 8 + *(uint32_t*)&rom[chunk_pos+4];
					if (chunk_pos >= rom_size) {
						fprintf(stderr, "Missing 'data' chunk: sampleId=%zu\n", 0x80 + num_samples);
						return NULL;
					}
				}

				/* Correct sample start/end pointers */
				const size_t data_size = *(uint32_t*)&rom[chunk_pos+4];
				const size_t start_pos = chunk_pos + 8;
				const size_t end_pos = start_pos + data_size;

				sample_table[num_samples-1].startBank = start_pos >> 15;
				sample_table[num_samples-1].startOffset = 0x8000 | (start_pos & 0x7FFF);
				sample_table[num_samples-1].endBank = end_pos >> 15;
				sample_table[num_samples-1].endOffset = 0x8000 | (end_pos & 0x7FFF);
			}

			/* PCM samples must always be aligned on even boundary */
			sample_table[num_samples-1].startOffset &= 0xFFFE;
			sample_table[num_samples-1].endOffset &= 0xFFFE;
		}
		else if (type == MPCM_TYPE_DPCM || type == MPCM_TYPE_DPCM_TURBO) {
			/* Parse DPCM-HQ files */
			if (strncmp((char*)&rom[start], "DQ", 2) == 0) {
				const uint8_t version = rom[start+2];
				if (version != '1') {
					fprintf(stderr, "Unsupported DPCM-HQ version: sampleId=%zu\n", 0x80 + num_samples);
					return NULL;
				}

				sample_table[num_samples-1].flags += 4;

				/* If pitch wasn't set, auto-calculate it */
				if (!pitch) {
					const uint16_t sample_rate = (rom[start+6]<<8) + rom[start+7];
					sample_table[num_samples-1].pitch = MPCM_SampleRateToPitch(type, sample_rate);
				}

				/* Correct sample start/end pointers */
				const size_t start_pos = start + 9;
				const size_t end_pos = start_pos + ((rom[start+3]<<16)|(rom[start+4]<<8)|(rom[start+5]));
				sample_table[num_samples-1].startBank = start_pos >> 15;
				sample_table[num_samples-1].startOffset = 0x8000 | (start_pos & 0x7FFF);
				sample_table[num_samples-1].endBank = end_pos >> 15;
				sample_table[num_samples-1].endOffset = 0x8000 | (end_pos & 0x7FFF);
			}
		}

		/* Fail if pitch wasn't auto-detected */
		if (!sample_table[num_samples-1].pitch) {
			fprintf(stderr, "Invalid pitch: sampleId=%zx\n", 0x80 + num_samples);
			return NULL;
		}
	}

	*out_num_samples = num_samples;
	return sample_table;
}

void MPCM_LoadSampleTable(Z80VM_Context * context, MPCM_Sample* sample_table, size_t sample_table_size) {
	memcpy(&context->programRAM[Z_MPCM_SampleTable], sample_table, sample_table_size * sizeof(MPCM_Sample));
}

void MPCM_PlaySample(Z80VM_Context * context, uint8_t sample_id) {
	context->programRAM[Z_MPCM_CommandInput] = sample_id;
}

void MPCM_PausePlayback(Z80VM_Context * context) {
	context->programRAM[Z_MPCM_CommandInput] = Z_MPCM_COMMAND_PAUSE;
}

void MPCM_StopPlayback(Z80VM_Context * context) {
	context->programRAM[Z_MPCM_CommandInput] = Z_MPCM_COMMAND_STOP;
}

bool MPCM_IsPlaybackPaused(Z80VM_Context * context) {
	return context->programRAM[Z_MPCM_CommandInput] == Z_MPCM_COMMAND_PAUSE;
}

void MPCM_UnpausePlayback(Z80VM_Context * context) {
	context->programRAM[Z_MPCM_CommandInput] = 0;
}

void MPCM_SetPan(Z80VM_Context * context, uint8_t pan) {
	context->programRAM[Z_MPCM_PanInput] = pan;
}

void MPCM_SetSFXPan(Z80VM_Context * context, uint8_t pan) {
	context->programRAM[Z_MPCM_SFXPanInput] = pan;
}

void MPCM_SetVolume(Z80VM_Context * context, uint8_t volume) {
	context->programRAM[Z_MPCM_VolumeInput] = volume;
}

void MPCM_SetSFXVolume(Z80VM_Context * context, uint8_t volume) {
	context->programRAM[Z_MPCM_SFXVolumeInput] = volume;
}

void MPCM_WaitForInitialization(Z80VM_Context * context) {
	/* Mega PCM shouldn't take longer than this to initialize */
	const size_t MAX_FRAMES_FOR_INIT = 4;

	/* We must substitute a small ROM so MegaPCM's calibration loop doesn't fail */
	if (!context->ROM) {
		const uint8_t ROM[] = { 0x00 };
		context->ROM = ROM;
		context->ROMsize = sizeof(ROM);
	}

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
