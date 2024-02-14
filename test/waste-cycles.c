
#include <megapcm-emu.h>
#include <stdio.h>
#include <z80vm.h>

#include <stdlib.h>
#include <stdint.h>

void runTest(uint16_t cycles, uint16_t expectedCycles, Z80VM_Context* context) {
	fprintf(stderr, "Waste cycles test: cycles=%d, expectedCycles=%d\n", cycles, expectedCycles);

	// This emulates `ld hl, CYCLES`
	context->z80State.registers.word[Z80_HL] = cycles;

	const size_t cyclesEmulated = Z80VM_EmulateSubroutine(context, Z_MPCM_WasteCycles, cycles * 2) + 17;

	if (cyclesEmulated != expectedCycles) {
		fprintf(stderr, "Test failed: Emulated %ld cycles, expected %d\n", cyclesEmulated, expectedCycles);
		abort();
	}
}

int main(int argc, char * argv[]) {
	Z80VM_Context * context = Z80VM_Init();

	MPCM_LoadDriver(context, "../build/z80/megapcm.bin");

	/* Initialize Z80 stack */
	context->z80State.registers.word[Z80_SP] = Z_MPCM_Stack;

	/* Perfectly wastes 2^N */
	runTest(256, 256, context);
	runTest(512, 512, context);
	runTest(1024, 1024, context);

	/* Perfectly wastes 2^N + 4x */
	runTest(256+4, 256+4, context);
	runTest(256+8, 256+8, context);
	runTest(256+12, 256+12, context);
	runTest(256-4, 256-4, context);
	runTest(256-8, 256-8, context);
	runTest(256-12, 256-12, context);

	/* Rounds to the nearest 2^N + 4x */
	runTest(256+5, 256+8, context);
	runTest(256+6, 256+8, context);
	runTest(256+7, 256+8, context);

	/* Arbitrary tests */
	runTest(19856, 19856, context);

	Z80VM_Destroy(context);
	puts("OK");
	return 0;
}
