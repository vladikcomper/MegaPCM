
#include "z80vm.h"
#include "z80emu.h"

#include <stdint.h>
#include <string.h>
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

void Z80VM_LoadTraceData(Z80VM_Context *context, const char * traceFilePath) {
	FILE * textInput = fopen(traceFilePath, "r");
	
	/* Read trace tables */
	const size_t LINE_BUFFER_SIZE = 4096;			// 4 KB
	const size_t MAX_TEXT_BUFFER_SIZE = 0x10000;	// 64 KB

	uint16_t (*traceMessageTbl)[0x2000] = calloc(0x2000, sizeof(uint16_t));
	uint16_t (*traceExceptionTbl)[0x2000] = calloc(0x2000, sizeof(uint16_t));
	char * traceTextBuffer = calloc(MAX_TEXT_BUFFER_SIZE, 1);

	if (!traceMessageTbl || !traceExceptionTbl || !traceTextBuffer) {
		fprintf(stderr, "%s: Memory allocation failed\n", __func__);
		abort();
	}

	char * traceTextBufferPos = traceTextBuffer;

	char lineBuffer[LINE_BUFFER_SIZE];
	enum  { None, TraceMsg, TraceException } section;

	*traceTextBufferPos++ = 0x00;		// The offset 0000 in text buffer is unused

	while (fgets(lineBuffer, LINE_BUFFER_SIZE, textInput)) {
		// Cut newline character if present
		size_t lineLength = strlen(lineBuffer);
		if (lineLength && lineBuffer[lineLength-1] == '\n') {
			lineBuffer[lineLength-1] = 0x00;
			lineLength -= 1;
		}
		if (lineLength == 0) {
			continue;
		}

		// Line marks the section
		if (lineBuffer[0] == '[') {
			if (strcmp(lineBuffer, "[TraceMsg]") == 0) {
				section = TraceMsg;
			}
			else if (strcmp(lineBuffer, "[TraceException]") == 0) {
				section = TraceException;
			}
			else {
				fprintf(stderr, "%s: Unknown or unsupported section: \"%s\"\n", __func__, lineBuffer);
				abort();
			}
		}
		// If line isn't a comment, parse it as a trace entry
		else if (lineBuffer[0] != '#') {
			uint16_t offset;
			if (sscanf(lineBuffer, "%hd: \"%[^\"]\"", &offset, traceTextBufferPos) != 2) {
				fprintf(stderr, "%s: Failed to parse line: \"%s\"\n", __func__, lineBuffer);
				abort();
			}
			if (section == TraceMsg) {
				(*traceMessageTbl)[offset] = traceTextBufferPos - traceTextBuffer;
			}
			else if (section == TraceException) {
				(*traceExceptionTbl)[offset] = traceTextBufferPos - traceTextBuffer;
			}
			else {
				fprintf(stderr, "%s: Trace entry before any section definition: \"%s\"\n", __func__, lineBuffer);
				abort();
			}
			traceTextBufferPos += strlen(traceTextBufferPos);
			*traceTextBufferPos++ = 0x00;
		}
	}

	context->traceEnabled = 1;
	context->traceMessageTbl = traceMessageTbl;
	context->traceExceptionTbl = traceExceptionTbl;
	context->traceTextBuffer = traceTextBuffer;

	fclose(textInput);
}

void Z80VM_DestroyTraceData(Z80VM_Context *context) {
	if (context->traceTextBuffer) {
		free(context->traceTextBuffer);
		context->traceTextBuffer = NULL;
	}
	if (context->traceMessageTbl) {
		free(context->traceMessageTbl);
		context->traceMessageTbl = NULL;
	}
	if (context->traceExceptionTbl) {
		free(context->traceExceptionTbl);
		context->traceExceptionTbl = NULL;
	}
	context->traceEnabled = 0;
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
	Z80VM_DestroyTraceData(context);
	free(context);
}
