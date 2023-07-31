
#include "z80vm.h"
#include "z80emu.h"

#include <stdio.h>
#include <stdlib.h>


Z80VM_Context * Z80VM_Init() {
	Z80VM_Context * context = calloc(1, sizeof(Z80VM_Context));

	if (!context) {
		fprintf(stderr, "Failed to allocate Z80VM context");
		abort();
	}

	/* Fill program RAM with random values */
	for (size_t i = 0; i < 0x2000; ++i) {
		context->programRAM[i] = random();
	}

	/* Reset CPU */
	context->z80State = (Z80_STATE){0};
	Z80Reset(&context->z80State);

	return context;
}


void Z80VM_Destroy(Z80VM_Context *context) {
	free(context);
}
