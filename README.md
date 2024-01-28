
# Mega PCM 2

Mega PCM 2 is a DAC sound driver for Sega Mega-Drive / Genesis.

## Features

- Crystal-clear PCM playback;
- Volume control and smooth pitch control;
	- 16 volume levels;
	- 256 pitch levels;
- Several supported sample formats:
	- WAVE file 8-bit unsigned PCM (playback rate can be detected from header);
	- Raw 8-bit unsigned PCM (headless);
	- Raw 4-bit DPCM (headless);
- High quality PCM playback up to 25 kHz with 256-step pitch and volume control;
- High quality DPCM playback up to 20.5 kHz with 256-step pitch and volume control;
- Turbo mode! PCM playback at 32 kHz, but without volume and pitch control;

# Architecture

256-byte sample buffer and a read-ahead loop.

## Buffer states

Consider a 16-byte buffer.
Let `^A` and `^P` be read-ahead pointer and playback pointers respectively.

Initial state:
	
	0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	^P
	^A

We've read-ahead 8 samples:

	A A A A A A A A 0 0 0 0 0 0 0 0
	^P				^A

We've played 4 samples:

	P P P P A A A A A A A 0 0 0 0 0
			^P            ^A	

Buffer wrapped:

	A A A A P P P P P P P P A A A A
		  ^A                ^P

Invariant for checking if we can still play (P):

	^P != ^A

Invariant for checking if we can read-ahead (A):

	^P - ^A - 3 <= 0

The driver implements two loops:
- `IdleLoop`
- `PCMLoop`

## `IdleLoop`

DAC is disabled

Phases:
- `IdleLoop_Init`
- `IdleLoop_Main`
	- Check for new sample

## `PCMPlaybackLoop`

Phase:
- `PCMLoop_Init` - enables PCM playback, loads a sample
- `PCMLoop_NormalPhase` - handles both playback and read-ahead
	- => `PCMLoop_ReadAheadExhausted`
	- => `PCMLoop_Sync_ReadaheadFull`
- `PCMLoop_DrainingPhase` - playback the remaining buffer, read-ahead is done
- `PCMPlaybackLoop_VBlank` - to keep buffer playing during VBlank


Sound Driver Loops in playback state:
1. `DriverLoop_Main` (Main loop)
	Until VBlank occurs:
	- Fill sample buffer (read ahead)
	- Play sample buffer (mask interrupts temporarily)
2. `DriverLoop_Int` (VBlank loop)
	Until VBlank ends:
	- Play sample buffer
	Before leaving VBlank:
	- Check if new sample is requested

Be mindful about disabling interrupts!
According to Blastem, Z80's INT signal only lasts for around 171.5 cycles:

```c
#define Z80_INT_PULSE_MCLKS 2573 //measured value is ~171.5 Z80 clocks
```

## Conventions

- Between `di`/`ei` less than 140 cycles should occur!
- When 68K stops Z80 and alters YM registers, always set YM Port 0 back to 2A to avoid broken DAC playback.
- Take care of the edge case: when sample is exactly 32kb and aligned, it should start and end in the same bank!

## Future optimizations

```asm
 	; Handle "read-ahead"
	ldi					; 16
	ldi					; 16
	jp		po, BC_is_zero	; 10
```

## Regarding bus access


When the Z80 accesses ROM the bus arbiter needs to pause the 68k, let the Z80 finish its request, then unpause the 68k again. Since all those components run asynchronously timing is barely predictable, also if the 68k is just about to access the bus itself it finishes its own access cycle first before releasing the bus. This typically means that the Z80’s 68k bus accesses will be delayed by 2 to 5 cycles. IIRC reads and writes behave exactly the same way. The average Z80 delay is around 3.3 Z80 cycles, whereas the average 68k delay is around 11 68k cycles.[1] 

IIRC If the Z80 tries to access ROM while the VDP is doing a DMA from 68k RAM this can lead to corruption of RAM contents due to glitchy signals on the address bus (similar to the C64’s VSP bug).[2]

Source: https://plutiedev.com/mirror/kabuto-hardware-notes#bus-system
