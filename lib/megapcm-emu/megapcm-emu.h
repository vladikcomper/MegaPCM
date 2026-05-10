
#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include <z80vm.h>

/* Include Mega PCM symbols */
#include <megapcm.symbols.h>

/**
 * Mega PCM 2.1 sample record format, as presented in Z80 definitions
 */
typedef struct {
	uint8_t flags;
	uint8_t pitch;
	uint8_t startBank;
	uint8_t endBank;
	uint16_t startOffset;
	uint16_t endOffset;
} __attribute__((packed)) MPCM_Sample;


typedef struct {
	uint8_t type;
	uint8_t flags;
	uint16_t sample_rate;
	char * sample_path;
} MPCM_SampleMetadata;


/* Higher-level constants for `MPCM_SampleMetadata` struct */

#define MPCM_FLAGS_LOOP			0x01		// loop sample indefinitely
#define MPCM_FLAGS_SFX			0x40		// sample is SFX, normal drums cannot interrupt it
#define MPCM_FLAGS_SAMPLE		0x80		// marks slot as a playable sample

#define MPCM_TYPE_NONE			0x00
#define MPCM_TYPE_PCM			0x02
#define MPCM_TYPE_PCM_TURBO		0x04
#define MPCM_TYPE_DPCM			0x06
#define MPCM_TYPE_DPCM_TURBO	0x08


/**
 * Loads Mega PCM driver to Z80VM. Note that Z80VM must be initialized at this point
 */
void MPCM_LoadDriver(Z80VM_Context * context, const char * path);

/**
 * Loads Mega PCM Sample ROM, returns a pre-processed sample table
 */
MPCM_Sample* MPCM_LoadSamplesROM(uint8_t * rom, size_t rom_size, size_t *out_num_samples);

/**
 * Uploads sample table to Z80 VM
 */
void MPCM_LoadSampleTable(Z80VM_Context * context, MPCM_Sample* sample_table, size_t sample_table_size);


/**
 * Waits until Mega PCM fully initialized
 */
void MPCM_WaitForInitialization(Z80VM_Context * context);


void MPCM_PlaySample(Z80VM_Context * context, uint8_t sample_id);
void MPCM_PausePlayback(Z80VM_Context * context);
bool MPCM_IsPlaybackPaused(Z80VM_Context * context);
void MPCM_StopPlayback(Z80VM_Context * context);
void MPCM_UnpausePlayback(Z80VM_Context * context);
void MPCM_SetPan(Z80VM_Context * context, uint8_t pan);
void MPCM_SetSFXPan(Z80VM_Context * context, uint8_t pan);
void MPCM_SetVolume(Z80VM_Context * context, uint8_t volume);
void MPCM_SetSFXVolume(Z80VM_Context * context, uint8_t volume);

/**
 * Displays Mega PCM's last error code in human-readable form
 */
void MPCM_ThrowLastErrorCode(Z80VM_Context * context);
