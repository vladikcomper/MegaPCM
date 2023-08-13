
# Features

- Crystal clear PCM playback at up to 24 kHz;
- Auto-bankswitching;

Planned:
- DPCM playback;
- 2-channel mixer?
- Volume control?

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

	^A + 3 <= ^P	


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
- `PCMPlyabackLoop_VBlank` - to keep buffer playing during VBlank


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

- Between `di`/`ei` less than 120 cycles should occur!
- When writing both register and value to YM, set a flag to avoid busreq.
- Take care of the edge case: when sample is exactly 32kb and aligned, it should start and end in the same bank!

## Future optimizations

```asm
 	; Handle "read-ahead"
	ldi					; 16
	ldi					; 16
	jp		po, BC_is_zero	; 10
```
