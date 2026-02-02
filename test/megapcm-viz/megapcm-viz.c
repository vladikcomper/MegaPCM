
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_keycode.h>
#include <SDL3/SDL_rect.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_stdinc.h>

#include "z80vm.h"
#include "megapcm-emu.h"


static Z80VM_Context* z80vm = NULL;
static SDL_Window* window = NULL;
static SDL_Renderer* renderer = NULL;

/* Vizualizer state */
typedef struct Z80VM_Extension Z80VM_Extension;
typedef struct {
	uint8_t selected_sample;
	SDL_Texture * tex_health_buffer;
	SDL_Texture * tex_dac_output;
	Z80VM_Extension * z80vm_ext;
} VizState;


/* YM DAC output support */
#define YM_DAC_DEVICE_BUFFER_SAMPLES 1024

typedef struct {
	long long previous_master_cycle;
	size_t buffer_pos;
	uint8_t buffer[YM_DAC_DEVICE_BUFFER_SAMPLES*2];	// 2 channels
} YM_DAC_Device;

static inline void YM_DAC_Init(YM_DAC_Device * ym_dac_device) {
	ym_dac_device->previous_master_cycle = 0;
	ym_dac_device->buffer_pos = 0;
}

static inline void Z80VM_Extension_SampleDACOutput(Z80VM_Context * z80vm, uint8_t dac_sample);
static inline void Z80VM_Extension_SampleBufferHealth(Z80VM_Context * z80vm);

static inline void YM_DAC_RenderOutput(YM_DAC_Device * ym_dac_device, Z80VM_Context * z80vm) {
	const long long current_master_cycle = z80vm->z80State.cycles_emulated * 15;
	const size_t samples_to_commit = (current_master_cycle - ym_dac_device->previous_master_cycle) / (144*7);
	const size_t samples_available = YM_DAC_DEVICE_BUFFER_SAMPLES - ym_dac_device->buffer_pos / 2;

	if (!samples_to_commit) return;
	assert(samples_to_commit <= samples_available);

	uint8_t left_sample = 0x80;
	uint8_t right_sample = 0x80;
	if (z80vm->ymGlobalRegValues[0x2B-0x20] & 0x80) { // DAC is enabled
		const uint8_t pan_register = z80vm->ymPort1ChRegValues[0xB6 - 0xA0];
		const uint8_t dac_sample = z80vm->ymGlobalRegValues[0x2A - 0x20];

		left_sample = (pan_register & 0x80) ? dac_sample : 0x80;
		right_sample = (pan_register & 0x40) ? dac_sample : 0x80;
	}
	uint8_t* buff = &ym_dac_device->buffer[ym_dac_device->buffer_pos];
	for (size_t i = 0; i < samples_to_commit; i++) {
		*buff++ = left_sample;
		*buff++ = right_sample;
	}

	const long long current_master_cycle_corrected = current_master_cycle - (current_master_cycle % (144*7));
	ym_dac_device->buffer_pos += samples_to_commit * 2;
	ym_dac_device->previous_master_cycle = current_master_cycle_corrected;
}

static inline void YM_DAC_FlushBuffer(YM_DAC_Device * ym_dac_device) {
	ym_dac_device->buffer_pos = 0;
}

static inline void YM_DAC_WriteByteCallback(YM_DAC_Device * ym_dac_device, Z80VM_Context * z80vm, uint16_t address, uint8_t value) {
	// Happens before YM registers are commited
	if (
		(address == 0x4001 && z80vm->ymPort0Reg == 0x2A) ||	// dac sample
		(address == 0x4001 && z80vm->ymPort0Reg == 0x2B) ||	// dac enable
		(address == 0x4003 && z80vm->ymPort1Reg == 0xB6)	// panning
	) {
		if (z80vm->ymGlobalRegValues[0x2B-0x20] & 0x80) { // DAC is enabled
			const uint8_t dac_sample = z80vm->ymGlobalRegValues[0x2A - 0x20];

			Z80VM_Extension_SampleDACOutput(z80vm, dac_sample);
			Z80VM_Extension_SampleBufferHealth(z80vm);
		}

		YM_DAC_RenderOutput(ym_dac_device, z80vm);
	}
}

/* Z80VM Extnesion implementation */
#define MAX_SAMPLES_PER_TV_FRAME 1024

struct Z80VM_Extension {
	YM_DAC_Device* ym_dac_device;
	uint8_t ym_dac_output_sampled[MAX_SAMPLES_PER_TV_FRAME];
	size_t ym_dac_output_sampled_pos;
	uint8_t mpcm_buffer_health_sampled[MAX_SAMPLES_PER_TV_FRAME];
	size_t mpcm_buffer_health_sampled_pos;
};

void Z80VM_Extension_WriteByteCallback(uint16_t address, uint8_t value, Z80VM_Context * z80vm) {
	Z80VM_Extension* extension = z80vm->stateExtension;
	YM_DAC_WriteByteCallback(extension->ym_dac_device, z80vm, address, value);
}

static inline void Z80VM_Extension_SampleDACOutput(Z80VM_Context * z80vm, uint8_t dac_sample) {
	Z80VM_Extension* extension = z80vm->stateExtension;

	assert(extension->ym_dac_output_sampled_pos < MAX_SAMPLES_PER_TV_FRAME);
	extension->ym_dac_output_sampled[extension->ym_dac_output_sampled_pos++] = dac_sample;
}

static inline void Z80VM_Extension_SampleBufferHealth(Z80VM_Context * z80vm) {
	Z80VM_Extension* extension = z80vm->stateExtension;

	const uint8_t loopId = z80vm->programRAM[Z_MPCM_LoopId];
	const uint8_t playbackPos = z80vm->z80State.registers.byte[Z80_L];
	const uint8_t readaheadPos = ((loopId == Z_MPCM_LOOP_DPCM) || (loopId == Z_MPCM_LOOP_DPCM_TURBO))
		? (z80vm->z80State.alternates[Z80_BC] & 0xFF)
		: (z80vm->z80State.alternates[Z80_DE] & 0xFF);

	assert(extension->mpcm_buffer_health_sampled_pos < MAX_SAMPLES_PER_TV_FRAME);
	extension->mpcm_buffer_health_sampled[extension->mpcm_buffer_health_sampled_pos++] = 0xFF - (playbackPos - readaheadPos);
}


static inline bool Viz_HandleEvents(VizState* viz) {
	SDL_Event e;
	while (SDL_PollEvent(&e)) {
		switch (e.type) {
			case SDL_EVENT_QUIT:
				return false;	// stop running
			case SDL_EVENT_KEY_DOWN:
				if (e.key.key == SDLK_Q) {
					return false;	// also stop running
				} else if (e.key.key == SDLK_LEFT && viz->selected_sample > 0x81) {
					viz->selected_sample -= 1;
				} else if (e.key.key == SDLK_RIGHT && viz->selected_sample < 0xFF) {
					viz->selected_sample += 1;
				} else if (e.key.key == SDLK_UP && (e.key.mod & SDL_KMOD_SHIFT)) {
					const uint8_t volume = Z80_ReadByte(Z_MPCM_VolumeInput, z80vm);
					if (volume < 8) MPCM_SetVolume(z80vm, volume+1);
				} else if (e.key.key == SDLK_DOWN && (e.key.mod & SDL_KMOD_SHIFT)) {
					const uint8_t volume = Z80_ReadByte(Z_MPCM_VolumeInput, z80vm);
					if (volume > 0) MPCM_SetVolume(z80vm, volume-1);
				} else if (e.key.key == SDLK_UP) {
					const uint8_t volume = Z80_ReadByte(Z_MPCM_SFXVolumeInput, z80vm);
					if (volume < 8) MPCM_SetSFXVolume(z80vm, volume+1);
				} else if (e.key.key == SDLK_DOWN) {
					const uint8_t volume = Z80_ReadByte(Z_MPCM_SFXVolumeInput, z80vm);
					if (volume > 0) MPCM_SetSFXVolume(z80vm, volume-1);
				} else if (e.key.key == SDLK_RETURN) {
					MPCM_PlaySample(z80vm, viz->selected_sample);
					fprintf(stderr, "Request sample %02X\n", viz->selected_sample);
				} else if (e.key.key == SDLK_P) {
					if (MPCM_IsPlaybackPaused(z80vm)) {
						MPCM_UnpausePlayback(z80vm);
						fprintf(stderr, "Unpaused\n");
					} else {
						MPCM_PausePlayback(z80vm);
						fprintf(stderr, "Paused\n");
					}
				} else if (e.key.key == SDLK_ESCAPE) {
					MPCM_StopPlayback(z80vm);
				} else if (e.key.key == SDLK_LEFTBRACKET && (e.key.mod & SDL_KMOD_SHIFT)) {
					MPCM_SetPan(z80vm, 0x80);
					fprintf(stderr, "Pan left\n");
				} else if (e.key.key == SDLK_RIGHTBRACKET && (e.key.mod & SDL_KMOD_SHIFT)) {
					MPCM_SetPan(z80vm, 0x40);
					fprintf(stderr, "Pan right\n");
				} else if (e.key.key == SDLK_BACKSLASH && (e.key.mod & SDL_KMOD_SHIFT)) {
					MPCM_SetPan(z80vm, 0xC0);
					fprintf(stderr, "Pan center\n");
				} else if (e.key.key == SDLK_LEFTBRACKET) {
					MPCM_SetSFXPan(z80vm, 0x80);
					fprintf(stderr, "Pan SFX left\n");
				} else if (e.key.key == SDLK_RIGHTBRACKET) {
					MPCM_SetSFXPan(z80vm, 0x40);
					fprintf(stderr, "Pan SFX right\n");
				} else if (e.key.key == SDLK_BACKSLASH) {
					MPCM_SetSFXPan(z80vm, 0xC0);
					fprintf(stderr, "Pan SFX center\n");
				}
				break;
		}
	}
	return true;	// keep running
}

static inline void Viz_PlotSamplesToTexture(SDL_Texture* texture, int width, int height, uint8_t *samples, size_t samples_len) {
	int pitch = 0;
	SDL_Color *pixels = NULL;

	if (SDL_LockTexture(texture, NULL, (void**)&pixels, &pitch)) {
		const SDL_Color bg_color = {0x80, 0x80, 0x80, 0xFF};
		const SDL_Color fg_color = {0xFF, 0xFF, 0xFF, 0xFF};

        for (int i = 0; i < width * height; i++) pixels[i] = bg_color;        

        if (samples_len >= 2) {
	        for (int x = 0; x < width; x++) {
	            int idx = ((float)x / (float)(width - 1)) * (samples_len - 1);
	            assert(idx >= 0 && idx < samples_len);
	            const uint8_t sample = samples[idx];
	            const int fill_height = (sample * height) / 255;
	            for (int y = 0; y < fill_height; y++) {
	                int pixel_y = height - 1 - y;
	                pixels[pixel_y * width + x] = fg_color;
	            }
	        }
        }

		SDL_UnlockTexture(texture);
	}
}

static inline void Viz_PlotSamplesToTexture2(SDL_Texture* texture, const SDL_FRect* rect, uint8_t *samples, size_t samples_len) {
	SDL_SetRenderTarget(renderer, texture);
	SDL_SetRenderDrawColor(renderer, 0x80, 0x80, 0x80, 0xFF);
	SDL_RenderFillRect(renderer, NULL);

	if (samples_len >= 2) {
		SDL_FPoint points[(int)rect->w];
	    for (int x = 0; x < (int)rect->w; x++) {
	        const int idx = ((float)x / (float)(rect->w - 1)) * (samples_len - 1);
	        assert(idx >= 0 && idx < samples_len);
	    	points[x].x = x;
	    	points[x].y = (samples[idx] * (float)rect->h) / 255;
	    }
	    SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
	    SDL_RenderLines(renderer, points, rect->w);
	}

	SDL_SetRenderTarget(renderer, NULL);
}

static inline void Viz_RenderVideoFrame(VizState* viz) {
	SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xFF);
	SDL_RenderClear(renderer);

	static int routine = 0;

	switch (routine) {
		case 0: {	// wait init
			SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
			SDL_RenderDebugText(renderer, 8.0f, 8.0f, "Waiting Mega PCM initialization...");

			if (Z80_ReadByte(Z_MPCM_DriverReady, z80vm) == 'R') {
				routine++;
			}
			break;
		}

		case 1: {			
			SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);

			SDL_RenderDebugTextFormat(renderer, 8.0f, 8.0f, "SAMPLE: %X", viz->selected_sample);

			SDL_RenderDebugTextFormat(renderer, 8.0f, 24.0f, "Volume: %X", Z80_ReadByte(Z_MPCM_VolumeInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 32.0f, "SFX Volume: %X", Z80_ReadByte(Z_MPCM_SFXVolumeInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 40.0f, "CurrentLoop: %02X", Z80_ReadByte(Z_MPCM_LoopId, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 48.0f, "CurrentBank: %02X", Z80_ReadByte(Z_MPCM_CurrentBank, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 56.0f, "LastError: %02X", Z80_ReadByte(Z_MPCM_LastErrorCode, z80vm));

			SDL_RenderDebugTextFormat(renderer, 160.0f, 24.0f, "PanInput: %X", Z80_ReadByte(Z_MPCM_PanInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 160.0f, 32.0f, "SFX PanInput: %X", Z80_ReadByte(Z_MPCM_SFXPanInput, z80vm));


			{
				SDL_RenderDebugText(renderer, 8.0f, 80.0f, "BUFFER HEALTH:");
				SDL_RenderDebugTextFormat(renderer, 208.0f, 80.0f, "[%03zX samples]", viz->z80vm_ext->mpcm_buffer_health_sampled_pos);
				SDL_FRect dstrect = { .x = 0.0f, .y = 88.0f, .w = 320, .h = 64 };
				Viz_PlotSamplesToTexture(viz->tex_health_buffer, 320, 64, viz->z80vm_ext->mpcm_buffer_health_sampled, viz->z80vm_ext->mpcm_buffer_health_sampled_pos);
				SDL_RenderTexture(renderer, viz->tex_health_buffer, NULL, &dstrect);
			}
			{
				SDL_RenderDebugText(renderer, 8.0f, 156.0f, "DAC OUTPUT:");
				SDL_RenderDebugTextFormat(renderer, 224.0f, 156.0f, "[%05zu kHz]", viz->z80vm_ext->mpcm_buffer_health_sampled_pos * 60);
				SDL_FRect dstrect = { .x = 0, .y = 164, .w = 320, .h = 64 };
				Viz_PlotSamplesToTexture2(viz->tex_dac_output, &dstrect, viz->z80vm_ext->ym_dac_output_sampled, viz->z80vm_ext->ym_dac_output_sampled_pos);
				SDL_RenderTexture(renderer, viz->tex_dac_output, NULL, &dstrect);
			}

			break;
		}
	}

	SDL_RenderPresent(renderer);
}


int main(int argc, char** argv) {
	if (!SDL_Init(SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
		fprintf(stderr, "Failed to initilize SDL: %s\n", SDL_GetError());
		return 1;
	}
	atexit(SDL_Quit);

	if (!SDL_CreateWindowAndRenderer("Mega PCM 2 Visualizer", 640, 480, SDL_WINDOW_RESIZABLE, &window, &renderer)) {
		fprintf(stderr, "Failed to setup SDL window and renderer: %s\n", SDL_GetError());
		exit(1);
	}
	if (!SDL_SetRenderLogicalPresentation(renderer, 320, 240, SDL_LOGICAL_PRESENTATION_LETTERBOX)) {
		fprintf(stderr, "Failed to set renderer logical presentation: %s\n", SDL_GetError());
		exit(1);
	}

	SDL_AudioSpec spec = {
		.channels = 2,
		.format = SDL_AUDIO_U8,
		.freq = 53267,
	};
	SDL_AudioStream* audio_stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, NULL, NULL);
	if (!audio_stream) {
		fprintf(stderr, "Failed to initialize audio stream: %s\n", SDL_GetError());
		exit(2);
	}

	/* Setup Z80 VM */
	z80vm = Z80VM_Init();
	if (!z80vm) {
		fprintf(stderr, "Failed to initialize Z80 VM.\n");
		exit(3);
	}

	YM_DAC_Device ym_dac_device;
	YM_DAC_Init(&ym_dac_device);

	Z80VM_Extension z80vm_ext = {
		.ym_dac_device = &ym_dac_device,
		.mpcm_buffer_health_sampled = { 0 },
		.mpcm_buffer_health_sampled_pos = 0,
		.ym_dac_output_sampled = { 0 },
		.ym_dac_output_sampled_pos = 0
	};
	z80vm->stateExtension = &z80vm_ext;	// attach Z80 VM extension
	z80vm->onWriteByte = &Z80VM_Extension_WriteByteCallback;

	/* Load Mega PCM binary */
	size_t z80_program_size = 0;
	uint8_t * z80_program = SDL_LoadFile("../../build/z80/megapcm.bin", &z80_program_size);
	if (!z80_program || !z80_program_size) {
		fprintf(stderr, "Failed to load Mega PCM 2 binary.\n");
		exit(4);
	}
	Z80VM_LoadProgram(z80vm, z80_program, z80_program_size);
	Z80VM_LoadTraceData(z80vm, "../../build/z80/megapcm.tracedata.txt");
	SDL_free(z80_program);

	/* Create ROM and a sample table */
	static const MPCM_SampleMetadata samples[] = {
		{ .type = MPCM_TYPE_PCM_TURBO, .flags = MPCM_FLAGS_LOOP, .sample_rate = 0, .sample_path = "../../examples/dma-survival-test/music.wav" },
		{ .type = MPCM_TYPE_PCM_TURBO, .flags = MPCM_FLAGS_LOOP, .sample_rate = 0, .sample_path = "../../examples/sample-tester/sample-loop.wav" },
		{ .type = MPCM_TYPE_PCM_TURBO, .flags = MPCM_FLAGS_SFX, .sample_rate = 0, .sample_path = "../../examples/s1-smps-integration/dac/voice.wav" },
		{ .type = MPCM_TYPE_DPCM, .flags = 0, .sample_rate = 8000, .sample_path = "../../examples/s1-smps-integration/dac/kick.dpcm" },
		{ .type = MPCM_TYPE_PCM,  .flags = 0, .sample_rate = 24000, .sample_path = "../../examples/s1-smps-integration/dac/snare.pcm" },
		{ .type = MPCM_TYPE_DPCM, .flags = 0, .sample_rate = 7250, .sample_path = "../../examples/s1-smps-integration/dac/timpani.dpcm" },
	};
	MPCM_Sample sample_table[SDL_arraysize(samples)];
	size_t rom_size = 0;
	uint8_t * rom = MPCM_MakeSamplesROM(samples, SDL_arraysize(samples), sample_table, &rom_size);
	if (!rom || !rom_size) {
		fprintf(stderr, "Failed to make Mega PCM 2 sample ROM.\n");
		exit(5);
	}
	z80vm->ROM = rom;	// attach ROM to Z80VM
	z80vm->ROMsize = rom_size;
	MPCM_LoadSampleTable(z80vm, sample_table, SDL_arraysize(samples));

	/* Setup main program data */
	VizState viz = {
		.selected_sample = 0x81,
		.tex_health_buffer = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, 320, 64),
		.tex_dac_output = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_TARGET, 320, 64),
		.z80vm_ext = &z80vm_ext
	};
	assert(viz.tex_health_buffer != NULL);
	assert(viz.tex_dac_output != NULL);
	SDL_SetTextureScaleMode(viz.tex_health_buffer, SDL_SCALEMODE_NEAREST);
	SDL_SetTextureScaleMode(viz.tex_dac_output, SDL_SCALEMODE_NEAREST);

	/* Emulation loop */
	assert(!z80vm->z80State.cycles_emulated);	// shouldn't have emulated any cycles by now
	SDL_ResumeAudioStreamDevice(audio_stream);
	
	bool running = true;
	size_t prevFrameOvershootCycles = 0;
	while (running) {
		const uint64_t frame_start_ns = SDL_GetTicksNS();

		running = Viz_HandleEvents(&viz);

		// Reset sampled arrays and emulate this TV frame
		z80vm_ext.mpcm_buffer_health_sampled_pos = 0;
		z80vm_ext.ym_dac_output_sampled_pos = 0;
		prevFrameOvershootCycles = Z80VM_EmulateTVFrame(z80vm, prevFrameOvershootCycles);

		// Render audio
		YM_DAC_RenderOutput(&ym_dac_device, z80vm);
		SDL_PutAudioStreamData(audio_stream, ym_dac_device.buffer, ym_dac_device.buffer_pos);
		YM_DAC_FlushBuffer(&ym_dac_device);

		// Render video
		Viz_RenderVideoFrame(&viz);

		// Cap at 60 fps
		const uint64_t frame_end_ns = SDL_GetTicksNS();
		const int64_t delay_ns = 1000000000 / 60 - (frame_end_ns - frame_start_ns);

		if (delay_ns > 0) SDL_DelayPrecise(delay_ns);
	}

	SDL_DestroyTexture(viz.tex_health_buffer);
	SDL_DestroyTexture(viz.tex_dac_output);
	SDL_DestroyAudioStream(audio_stream);
	SDL_DestroyWindow(window);
	SDL_DestroyRenderer(renderer);

	Z80VM_Destroy(z80vm);

    SDL_Quit();
    return 0;
}
