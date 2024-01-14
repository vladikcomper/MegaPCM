
#include <megapcm-emu.h>
#include <stdio.h>
#include <z80vm.h>

#include <stdlib.h>
#include <stdint.h>

void runTest(uint16_t romScore, uint16_t ramScore, uint8_t expectedCalibration, Z80VM_Context* context) {
	fprintf(stderr, "Running calibration test: ROM=%d, RAM=%d\n", romScore, ramScore);

	const size_t MAX_CYCLES = 400;

	// We need to clear "CalibrationApplied", because it's not cleared after it's set
	Z80_WriteByte(Z_MPCM_CalibrationApplied, 0, context);
	Z80_WriteWord(Z_MPCM_CalibrationScore_ROM, romScore, context);
	Z80_WriteWord(Z_MPCM_CalibrationScore_RAM, ramScore, context);

	// A hack, because the routine already stores RAM score in BC
	context->z80State.alternates[Z80_BC] = ramScore;

	Z80VM_EmulateSubroutine(context, Z_MPCM_CalibrationLoop_VBlank_Frame02_FinalizeBenchmark, MAX_CYCLES);

	const uint8_t calibration = Z80_ReadByte(Z_MPCM_CalibrationApplied, context);
	if (calibration != expectedCalibration) {
		fprintf(stderr, "Test failed: Expected %02X, got %02X\n", expectedCalibration, calibration);
		abort();
	}
}

int main(int argc, char * argv[]) {
	Z80VM_Context * context = Z80VM_Init();

	MPCM_LoadDriver(context, "../build/z80/megapcm.bin");

	/* Initialize Z80 stack */
	context->z80State.registers.word[Z80_SP] = Z_MPCM_Stack;

	/* No calibration: real hardware and accurate emulators, no Z80 stops */
	runTest(2435, 3016, 0, context);	// NTSC, real hardware, by Mask of Destiny
	runTest(2468, 3016, 0, context);	// NTSC, Blastem
	runTest(3116, 3878, 0, context);	// PAL, real hardware, by smds
	runTest(2464, 3012, 0, context);	// NTSC, PicoDrive 1.93

	/* Yes calibration: inaccurate emulators */
	runTest(3016, 3016, 1, context);	// NTSC, BizHawk, Clownmdemu 0.5.1 and various others
	runTest(2913, 2913, 1, context);	// NTSC, Genecyst DOS

	/* Synthetic tests */
	runTest(1000, 1000, 1, context);
	runTest(1000, 1100, 1, context);
	runTest(1000, 1250, 0, context);	// calibration won't trigger if ROM/RAM are roughly 12.5% different
	runTest(1000, 9999, 0, context);	// measure error: RAM score is much higher
	runTest(1000, 999, 1, context);		// measure error: RAM score is lower
	runTest(1000, 100, 1, context);		// measure error: RAM score is much lower

	Z80VM_Destroy(context);
	puts("OK");
	return 0;
}
