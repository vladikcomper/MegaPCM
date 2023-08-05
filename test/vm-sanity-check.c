
#include "z80vm.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

const uint8_t program1[] = {
	0x3E, 0x12,			// [7]		ld a, 12h
	0x21, 0x56, 0x34	// [10]		ld hl, 3456h
};

int main(int argc, char * argv[]) {
	Z80VM_Context * context = Z80VM_Init();

	Z80VM_LoadProgram(context, program1, sizeof(program1));
	size_t cycles_emulated = Z80VM_Emulate(context, 17-1);

	assert(cycles_emulated == 17);
	assert(context->z80State.registers.byte[Z80_A] == 0x12);
	assert(context->z80State.registers.word[Z80_HL] == 0x3456);

	Z80VM_Destroy(context);

	puts("OK");

	return 0;
}
