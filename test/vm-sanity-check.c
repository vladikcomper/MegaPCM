
#include "z80vm.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

const uint8_t program1[] = {
	0x3E, 0x12,			// [7]		ld a, 12h
	0x21, 0x56, 0x34	// [10]		ld hl, 3456h
};

const uint8_t program2[] = {
	0x21, 0x00, 0x00,	// [10]		ld hl, 0000h
	0x11, 0x0B, 0x00,	// [10]		ld de, 000Bh
	0x01, 0x01, 0x00,	// [10]		ld bc, 0001h
	0xED, 0xA0,			// [16]		ldi
	0x00
};

int main(int argc, char * argv[]) {

	/* Test program 1 */
	{
		fprintf(stderr, "Testing program1... ");
		
		Z80VM_Context * context = Z80VM_Init();
		Z80VM_LoadProgram(context, program1, sizeof(program1));
		size_t cycles_emulated = Z80VM_Emulate(context, 17-1);

		assert(cycles_emulated == 17);
		assert(context->z80State.registers.byte[Z80_A] == 0x12);
		assert(context->z80State.registers.word[Z80_HL] == 0x3456);
	
		Z80VM_Destroy(context);
		fprintf(stderr, "OK\n");
	}

	/* Test program 1 */
	{
		fprintf(stderr, "Testing program2... ");

		Z80VM_Context * context = Z80VM_Init();
		Z80VM_LoadProgram(context, program2, sizeof(program2));

		// Emulate LD instructions
		size_t cycles_emulated = Z80VM_Emulate(context, 30-1);
		assert(cycles_emulated == 30);

		// Emulate LDI
		cycles_emulated = Z80VM_Emulate(context, 16-1);
		assert(cycles_emulated == 16);

		assert(context->programRAM[0xB] == 0x21);
		assert(context->z80State.registers.word[Z80_BC == 0x0000]);

		Z80VM_Destroy(context);
		fprintf(stderr, "OK\n");
	}

	puts("OK");

	return 0;
}
