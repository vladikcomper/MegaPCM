
# Mega PCM Vizualizer

**Mega PCM Vizualizer** is a custom-made Z80 and YM2612 DAC emulator to test Mega PCM 2 during development and vizualize its internal state (e.g. buffer health) across TV-frame. I mostly built this tool for development purposes, so it's not fully user-friendly or convenient. You need to compile it manually, since it's not publicly released.

If you just want a glimpse of it in action, refer to this short video (**Volume warning!** Relatively loud sound): https://drive.google.com/file/d/12ceuu8dUHGmrKKK1weNBXXI4GT-cVVNT/view (preview quality is low, I recommend downloading it for 60 fps)

## Building

- You need SDL3 development files (`libsdl3-dev` on Debian, `SDL3-devel` on Fedora).
- Run `make` (Mega PCM Emu library and Mega PCM driver binaries should be built automatically).

## Usage

Mega PCM Vizualizer reads data from a pre-compiled ROM with includes sample table and samples themselves. ROM is compiled using ASM68K and native Mega PCM 2 macros. It's auto-compiled when you run `make`.

It's recommended to `megapcm-viz` from terminal to see driver's debug output.

## Controls

- **`Enter`** - Play sample
    - Note that SFX samples have high priority and won't allow other normal samples to play.
- **`Left` / `Right`** - Change sample
- **`Up` / `Down`** - Change SFX volume
    - Hold `Shift` to change normal sample volume
- **`Esc`** - Stop playback
- **`p`** - Pause/unpause playback
- **`[` / `]` / `\`** - change initial SFX panning (left, right, center)
    - Only applies to new samples;
    - Hold `Shift` to change normal sample panning.

## Vizualizations

Below state display there are two vizualizations: **buffer health** and **DAC output**.

- Both vizualizations are sampled across the entire TV frame (panning from left to right);
    - `[XXX samples]` represents number of samples Mega PCM output to DAC this frame (hex);
    - `[xxxxx Hz]` represents effective playback rate;
        - Playback rate is specific to playback loop (PCM, PCM-Turbo, DPCM or DPCM-Turbo);
        - For pitched samples, it will be higher than actual sample rate, as Mega PCM upsamples output to match base loop frequency;
- **DAC output** is a simple vizualization of the wave output during TV frame;
- **Buffer health** shows the state of Mega PCM 2's internal sample buffer during TV frame;
    - Each vertical stripe represents "health percentage" (filled by white pixels);
    - White filling basically shows how full the buffer is with "samples read in advance";
    - "Samples read in advance" allow Mega PCM 2 to continue playback without touching M68K ROM;
    - Reading from the buffer without filling it drains the buffer;
    - When Mega PCM 2 starts reading from ROM, buffer grows again ("health" increases);
    - If buffer gets fully drained (empty), playback quality will degrade (should never happen).
