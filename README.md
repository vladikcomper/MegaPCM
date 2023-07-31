
# Architecture

- 256-byte sample buffer

Driver has 2 states:
- **Idle**
- **PCM Playback**

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
