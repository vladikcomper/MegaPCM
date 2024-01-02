
#pragma once

#include <stdint.h>
#include <stdlib.h>

#include <z80vm.h>

/* Include Mega PCM symbols */
#include <megapcm.symbols.h>

/**
 * Mega PCM 2.0 sample record format, as presented in Z80 definitions
 */
typedef struct {
	uint8_t type;
	uint8_t flags;
	uint8_t pitch;
	uint8_t startBank;
	uint8_t endBank;
	uint16_t startOffset;
	uint16_t endOffset;
} __attribute__((packed)) MPCM_Sample;


/**
 * Loads Mega PCM driver to Z80VM. Note that Z80VM must be initialized at this point
 */
void MPCM_LoadDriver(Z80VM_Context * context, const char * path);


/**
 * Waits until Mega PCM fully initialized
 */
void MPCM_WaitForInitialization(Z80VM_Context * context);


/**
 * Displays Mega PCM's last error code in human-readable form
 */
void MPCM_ThrowLastErrorCode(Z80VM_Context * context);
