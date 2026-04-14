
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

uint8_t* MPCM_MakeSamplesROM(const MPCM_SampleMetadata* input_records, size_t input_records_size, MPCM_Sample* out_sample_table, size_t *out_rom_size) {
	uint8_t* rom = NULL;
	size_t rom_pos = 0;
	size_t rom_size = 0;

	for (size_t i = 0; i < input_records_size; ++i) {
		/* Append sample data to ROM */
		FILE * sample_data = fopen(input_records[i].sample_path, "rb");
		if (!sample_data) {
			fprintf(stderr, "Failed to open sample file: %s\n", input_records[i].sample_path);
			goto failure;
		}

		fseek(sample_data, 0, SEEK_END);
		size_t sample_size = ftell(sample_data);
		fseek(sample_data, 0, SEEK_SET);

		rom_size += sample_size;
		rom = realloc(rom, rom_size);
		if (!rom) {
			fprintf(stderr, "Out of memory\n");
			goto failure;
		}

		if (!fread(&rom[rom_pos], sample_size, 1, sample_data)) {
			fprintf(stderr, "Failed to read sample data: %s\n", input_records[i].sample_path);
			fclose(sample_data);
			goto failure;
		}
		fclose(sample_data);

		/* Make sample record */
		out_sample_table[i].flags = (1<<Z_MPCM_FLAGS_SAMPLE) | input_records[i].type | input_records[i].flags;
		out_sample_table[i].pitch = MPCM_SampleRateToPitch(input_records[i].type, input_records[i].sample_rate);
		out_sample_table[i].startBank = rom_pos >> 15;
		out_sample_table[i].startOffset = rom_pos & 0x7FFF;
		out_sample_table[i].endBank = (rom_pos + sample_size) >> 15;
		out_sample_table[i].endOffset = (rom_pos + sample_size) & 0x7FFF;

		/* Read WAVE files */
		if (input_records[i].type == MPCM_TYPE_PCM_TURBO || input_records[i].type == MPCM_TYPE_PCM) {
			if (
				strncmp((char*)&rom[rom_pos], "AIFF", 4) == 0 ||
				strncmp((char*)&rom[rom_pos], "NIST", 4) == 0
			) {
				fprintf(stderr, "Invalid container (AIFF/NIST): %s\n", input_records[i].sample_path);
				goto failure;
			}
			if (strncmp((char*)&rom[rom_pos], "RIFF", 4) == 0) {

				if (strncmp((char*)&rom[rom_pos+8], "WAVE", 4) != 0) {
					fprintf(stderr, "Invalid WAVE header: %s\n", input_records[i].sample_path);
					goto failure;
				}
				size_t chunk_pos = rom_pos+12;	// "fmt" chunk
				if (strncmp((char*)&rom[chunk_pos], "fmt ", 4) != 0) {
					fprintf(stderr, "Missing 'fmt' chunk: %s\n", input_records[i].sample_path);
					goto failure;
				}
				const uint16_t wave_format = *(uint16_t*)&rom[chunk_pos+8];
				if (wave_format != 1 && wave_format != 0xFFFE) {
					fprintf(stderr, "Invalid audio format: %s\n", input_records[i].sample_path);
					goto failure;
				}
				const uint16_t num_channels = *(uint16_t*)&rom[chunk_pos+10];
				if (num_channels != 1) {
					fprintf(stderr, "Too many channels: %s\n", input_records[i].sample_path);
					goto failure;					
				}
				const uint16_t bit_depth = *(uint16_t*)&rom[chunk_pos+22];
				if (bit_depth != 8) {
					fprintf(stderr, "Not a 8-bit audio stream: %s\n", input_records[i].sample_path);
					goto failure;
				}

				/* If pitch wasn't set, auto-calculate it */
				if (!out_sample_table[i].pitch) {
					const uint16_t sample_rate = *(uint16_t*)&rom[rom_pos+12+12];
					out_sample_table[i].pitch = MPCM_SampleRateToPitch(input_records[i].type, sample_rate);
				}

				/* Locate "data" chunk */
				while (strncmp((char*)&rom[chunk_pos], "data", 4) != 0) {
					chunk_pos += 8 + *(uint32_t*)&rom[chunk_pos+4];
					if (chunk_pos >= rom_size) {
						fprintf(stderr, "Missing 'data' chunk: %s\n", input_records[i].sample_path);
						goto failure;
					}
				}

				/* Correct sample start/end pointers */
				const size_t data_size = *(uint32_t*)&rom[chunk_pos+4];
				const size_t start_pos = chunk_pos+8;
				const size_t end_pos = chunk_pos+8+data_size;

				out_sample_table[i].startBank = start_pos >> 15;
				out_sample_table[i].startOffset = start_pos & 0x7FFF;
				out_sample_table[i].endBank = end_pos >> 15;
				out_sample_table[i].endOffset = end_pos & 0x7FFF;
			}
		}
		/* Read DPCM and DPCM-HQ files */
		else if (input_records[i].type == MPCM_TYPE_DPCM || input_records[i].type == MPCM_TYPE_DPCM_TURBO) {
			if (strncmp((char*)&rom[rom_pos], "DQ", 2) == 0) {
				const uint8_t version = rom[rom_pos+2];
				if (version != '1') {
					fprintf(stderr, "Unsupported DPCM-HQ version: %s\n", input_records[i].sample_path);
					goto failure;
				}

				/* If pitch wasn't set, auto-calculate it */
				if (!out_sample_table[i].pitch) {
					const uint16_t sample_rate = (rom[rom_pos+6]<<8) + rom[rom_pos+7];
					out_sample_table[i].pitch = MPCM_SampleRateToPitch(input_records[i].type, sample_rate);
				}

				/* Correct sample start/end pointers */
				const size_t start_pos = rom_pos+9;
				const size_t end_pos = start_pos + ((rom[rom_pos+3]<<16)|(rom[rom_pos+5]<<8)|(rom[rom_pos+6]));
				out_sample_table[i].startBank = start_pos >> 15;
				out_sample_table[i].startOffset = start_pos & 0x7FFF;
				out_sample_table[i].endBank = end_pos >> 15;
				out_sample_table[i].endOffset = end_pos & 0x7FFF;
			}
		}

		/* Fail if pitch wasn't auto-detected */
		if (!out_sample_table[i].pitch) {
			fprintf(stderr, "Invalid pitch: %s\n", input_records[i].sample_path);
			goto failure;
		}

		rom_pos += sample_size;

		if (rom_pos > 0x800000) {
			fprintf(stderr, "ROM exceeds 8 MB after sample: %s\n", input_records[i].sample_path);
			goto failure;
		}
	}

	*out_rom_size = rom_size;
	return rom;

failure:
	if (!rom) free(rom);
	return NULL;
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
