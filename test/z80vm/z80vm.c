
#include "z80vm.h"
#include "z80emu.h"

#include <stdio.h>
#include <stdlib.h>


Z80VM_Context * Z80VM_Init() {
	Z80VM_Context * context = calloc(1, sizeof(Z80VM_Context));

	if (!context) {
		fprintf(stderr, "Failed to allocate Z80VM context\n");
		abort();
	}

	/* Fill program RAM with zeroes */
	for (size_t i = 0; i < 0x2000; ++i) {
		context->programRAM[i] = 0x00;
	}

	/* Reset CPU */
	context->z80State = (Z80_STATE){0};
	Z80Reset(&context->z80State);

	return context;
}

void Z80VM_LoadProgram(Z80VM_Context *context, const uint8_t *buffer, size_t bufferSize) {
	if (bufferSize > 0x2000) {
		fprintf(stderr, "Z80 Program is too large\n");
		abort();
	}

	for (size_t i = 0; i < bufferSize; ++i) {
		context->programRAM[i] = buffer[i];
	}
}

size_t Z80VM_Emulate(Z80VM_Context *context, size_t cycles) {
	return Z80Emulate(&context->z80State, cycles, context);
}

size_t Z80VM_EmulateSubroutine(Z80VM_Context *context, uint16_t pc, size_t maxCycles) {

	/* Push previous PC to the stack (this emulates subroutine call) */
	uint16_t * SP = &context->z80State.registers.word[Z80_SP];
	*SP -= 2;
	Z80_WriteWord(*SP, context->z80State.pc, context);

	const uint16_t subroutine_sp = *SP;

	/* Enter subroutine emulation now */
	size_t cycles_emulated = 0;
	context->z80State.pc = pc;

	/* Emulation stops as soon as stack breaks out of `subroutine_sp` */
	while (*SP <= subroutine_sp) {
		cycles_emulated += Z80Emulate(&context->z80State, 1, context);

		if (cycles_emulated > maxCycles) {
			fprintf(stderr, "Subroutine emulation failed: reached max cycles.\n");
			abort();
		}
	}

	/* Restore previous PC */
	context->z80State.pc = Z80_ReadWord(*SP-2, context);

	return cycles_emulated;
}

size_t Z80VM_EmulateTVFrame(Z80VM_Context *context, size_t prevFrameOvershootCycles) {
	size_t cycles_emulated = 0;

	const size_t int_signal_start_cycles = (context->VPDRegion == NTSC ? 51006 : 50930) - prevFrameOvershootCycles;
	const size_t int_signal_end_cycles = int_signal_start_cycles + 172;
	const size_t frame_end_cycles = (context->VPDRegion == NTSC ? 59659 : 70938) - prevFrameOvershootCycles;

	/* Emulate frame until VBlank interrupt starts */
	cycles_emulated += Z80VM_Emulate(context, int_signal_start_cycles);

	/* Trigger VBlank signal for 172 cycles */
	fprintf(stderr, "Entering VBlanking period (cycles=%lld)...\n", context->z80State.cycles_emulated);
	size_t interrupt_enter_cycles = 0;
	// WARNING! We technically can enter interrupt multiple times between
	// `int_signal_start_cycles` and `int_signal_end_cycles`,
	// but VInt routines are usually long enough not cause this behavior, so it's not emulated here.
	while (
		cycles_emulated <= int_signal_end_cycles &&
		/* `interrupt_enter_cycles` will be zero until interrupts are enabled */
		!(interrupt_enter_cycles = Z80Interrupt(&context->z80State, 0xFF, context))
	) {
		cycles_emulated += Z80VM_Emulate(context, 1);
	}
	if (interrupt_enter_cycles) {
		fprintf(stderr, "Enterting interrupt after %lu cycles\n", cycles_emulated - int_signal_start_cycles);
		cycles_emulated += interrupt_enter_cycles;
	}
	else {
		fprintf(stderr, "WARNING! Interrupt missed\n");
	}

	/* Emulate the rest of the frame */
	cycles_emulated += Z80VM_Emulate(context, frame_end_cycles - cycles_emulated);

	/* Return "overshoot" cycles for the next `Z80VM_EmulateTVFrame` call */
	return cycles_emulated - frame_end_cycles;
}


void Z80VM_Destroy(Z80VM_Context *context) {
	free(context);
}
