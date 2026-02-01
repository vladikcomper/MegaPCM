
#include <SDL3/SDL_keycode.h>
#include <SDL3/SDL_rect.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_stdinc.h>
#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "macros.h"
#include "z80vm.h"
#include "megapcm-emu.h"

static inline int min(int a, int b) {
	return a < b ? a : b;
}

static inline int max(int a, int b) {
	return a > b ? a : b;
}

static Z80VM_Context* z80vm = NULL;
static SDL_Window* window = NULL;
static SDL_Renderer* renderer = NULL;

/* Vizualizer state */
typedef struct {
	int8_t max_dac_sample_value;	// max DAC sample this frame
	uint8_t selected_sample;
} VizState;
static VizState g_state = { .selected_sample = 0x81, .max_dac_sample_value = 0 };

/* Vizualizer graph support */
typedef struct {
	SDL_Texture* texture;
	SDL_Renderer* renderer;
	int width;
	int height;
	int current_pos;
	SDL_Color bg_color;
	SDL_Color fg_color;
} VizGraph;
static VizGraph* g_buffer = NULL;
static VizGraph* g_sample = NULL;

static inline VizGraph* VizGraph_Init(SDL_Renderer* renderer, int width, int height, SDL_Color* bg_color, SDL_Color* fg_color) {
	VizGraph* vizgraph = calloc(sizeof(VizGraph), 1);
	if (!vizgraph) return NULL;

	vizgraph->texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, width*2, height);
	if (!vizgraph->texture) return NULL;
	SDL_SetTextureScaleMode(vizgraph->texture, SDL_SCALEMODE_NEAREST);

	vizgraph->renderer = renderer;
	vizgraph->width = width;
	vizgraph->height = height;
	vizgraph->current_pos = 0;
	vizgraph->bg_color = *bg_color;
	vizgraph->fg_color = *fg_color;

	SDL_Color* pixels = NULL;
	int pitch_bytes = 0;
	SDL_LockTexture(vizgraph->texture, NULL, (void**)&pixels, &pitch_bytes);
	assert(pitch_bytes == width * 2 * sizeof(SDL_Color));
	for (int i = 0; i < width * 2 * height; ++i) {
		*pixels++ = *bg_color;
	}
	SDL_UnlockTexture(vizgraph->texture);

	return vizgraph;
}

static inline void VizGraph_Destroy(VizGraph* vizgraph) {
	if (vizgraph) {
		SDL_DestroyTexture(vizgraph->texture);
		free(vizgraph);
	}
}

static inline void VizGraph_PutMeasure(VizGraph* vizgraph, float val) {
	assert(val <= 1.0f);
	SDL_Rect rect = { vizgraph->current_pos % (vizgraph->width * 2), 0, 1, vizgraph->height };

	SDL_Color *pixels = NULL;
	int pitch_bytes = 0;
	SDL_LockTexture(vizgraph->texture, &rect, (void**)&pixels, &pitch_bytes);
	assert(pitch_bytes % sizeof(SDL_Color) == 0);

	const int num_fg_pixels = vizgraph->height * val;
	const int num_bg_pixels = vizgraph->height - num_fg_pixels;
	for (int i = 0; i < num_bg_pixels; ++i) { *pixels = vizgraph->bg_color; pixels += pitch_bytes / sizeof(SDL_Color); }
	for (int i = 0; i < num_fg_pixels; ++i) { *pixels = vizgraph->fg_color; pixels += pitch_bytes / sizeof(SDL_Color); }
	SDL_UnlockTexture(vizgraph->texture);

	vizgraph->current_pos++;
}

static inline void VizGraph_PutMeasure2(VizGraph* vizgraph, float val) {
	assert(val <= 1.0f);
	SDL_Rect rect = { vizgraph->current_pos % (vizgraph->width * 2), 0, 1, vizgraph->height };

	SDL_Color *pixels = NULL;
	int pitch_bytes = 0;
	SDL_LockTexture(vizgraph->texture, &rect, (void**)&pixels, &pitch_bytes);
	assert(pitch_bytes % sizeof(SDL_Color) == 0);

	const int num_fg_pixels = min(max((int)(vizgraph->height * fabsf(val)), 1), vizgraph->height);
	const int num_bg_pixels_pt1 = (vizgraph->height - num_fg_pixels) / 2;
	const int num_bg_pixels_pt2 = vizgraph->height - num_fg_pixels - num_bg_pixels_pt1;
	for (int i = 0; i < num_bg_pixels_pt1; ++i) { *pixels = vizgraph->bg_color; pixels += pitch_bytes / sizeof(SDL_Color); }
	for (int i = 0; i < num_fg_pixels; ++i) { *pixels = vizgraph->fg_color; pixels += pitch_bytes / sizeof(SDL_Color); }
	for (int i = 0; i < num_bg_pixels_pt2; ++i) { *pixels = vizgraph->bg_color; pixels += pitch_bytes / sizeof(SDL_Color); }
	SDL_UnlockTexture(vizgraph->texture);

	vizgraph->current_pos++;
}

static inline void VizGraph_Render(VizGraph* vizgraph, int x, int y) {
	int start_pos = vizgraph->current_pos - vizgraph->width;
	if (start_pos < 0) start_pos += vizgraph->width * 2;
	start_pos %= vizgraph->width * 2;

	const int draw_w = SDL_min(vizgraph->width * 2 - start_pos, vizgraph->width);
	SDL_FRect srcrect = { start_pos, 0, draw_w, vizgraph->height };
	SDL_FRect dstrect = { x, y, draw_w, vizgraph->height };
	SDL_RenderTexture(vizgraph->renderer, vizgraph->texture, &srcrect, &dstrect);

	if (vizgraph->width > draw_w) {
		SDL_FRect srcrect = { 0, 0, vizgraph->width - draw_w, vizgraph->height };
		SDL_FRect dstrect = { x + draw_w, y, vizgraph->width - draw_w, vizgraph->height };
		SDL_RenderTexture(vizgraph->renderer, vizgraph->texture, &srcrect, &dstrect);
	}
}

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

		const int8_t dac_sample_s8 = abs((signed)dac_sample - 0x80);
		if (dac_sample_s8 > g_state.max_dac_sample_value) g_state.max_dac_sample_value = dac_sample_s8;

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
		YM_DAC_RenderOutput(ym_dac_device, z80vm);
	}
}

/* ... */
typedef struct {
	YM_DAC_Device* ym_dac_device;
	uint8_t mpcm_buffer_health;
} Z80VM_Extension;

void Z80VM_Extension_WriteByteCallback(uint16_t address, uint8_t value, Z80VM_Context * z80vm) {
	Z80VM_Extension* extension = z80vm->stateExtension;
	YM_DAC_WriteByteCallback(extension->ym_dac_device, z80vm, address, value);
}

void Z80VM_Extension_VBlankCallback(Z80VM_Context * z80vm) {
	Z80VM_Extension* extension = z80vm->stateExtension;

	const uint8_t loopId = z80vm->programRAM[Z_MPCM_LoopId];

	const uint8_t playbackPos = z80vm->z80State.alternates[Z80_HL] & 0xFF;
	const uint8_t readaheadPos = ((loopId == Z_MPCM_LOOP_DPCM) || (loopId == Z_MPCM_LOOP_DPCM_TURBO))
		? z80vm->z80State.registers.byte[Z80_C]
		: z80vm->z80State.registers.byte[Z80_E];
	extension->mpcm_buffer_health = 0xFF - (playbackPos - readaheadPos);
}

static inline bool handle_events(void) {
	SDL_Event e;
	while (SDL_PollEvent(&e)) {
		switch (e.type) {
			case SDL_EVENT_QUIT:
				return false;	// stop running
			case SDL_EVENT_KEY_DOWN:
				if (e.key.key == SDLK_Q) {
					return false;	// also stop running
				} else if (e.key.key == SDLK_LEFT && g_state.selected_sample > 0x81) {
					g_state.selected_sample -= 1;
				} else if (e.key.key == SDLK_RIGHT && g_state.selected_sample < 0xFF) {
					g_state.selected_sample += 1;
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
					MPCM_PlaySample(z80vm, g_state.selected_sample);
					fprintf(stderr, "Request sample %02X\n", g_state.selected_sample);
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

static inline void render_video_frame(void) {
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

			SDL_RenderDebugTextFormat(renderer, 8.0f, 8.0f, "SAMPLE: %X", g_state.selected_sample);

			SDL_RenderDebugTextFormat(renderer, 8.0f, 24.0f, "Volume: %X", Z80_ReadByte(Z_MPCM_VolumeInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 32.0f, "SFX Volume: %X", Z80_ReadByte(Z_MPCM_SFXVolumeInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 40.0f, "CurrentLoop: %02X", Z80_ReadByte(Z_MPCM_LoopId, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 48.0f, "CurrentBank: %02X", Z80_ReadByte(Z_MPCM_CurrentBank, z80vm));
			SDL_RenderDebugTextFormat(renderer, 8.0f, 56.0f, "LastError: %02X", Z80_ReadByte(Z_MPCM_LastErrorCode, z80vm));

			SDL_RenderDebugTextFormat(renderer, 160.0f, 24.0f, "PanInput: %X", Z80_ReadByte(Z_MPCM_PanInput, z80vm));
			SDL_RenderDebugTextFormat(renderer, 160.0f, 32.0f, "SFX PanInput: %X", Z80_ReadByte(Z_MPCM_SFXPanInput, z80vm));

			SDL_RenderDebugText(renderer, 8.0f, 80.0f, "BUFFER HEALTH:");
			VizGraph_PutMeasure(g_buffer, ((Z80VM_Extension*)(z80vm->stateExtension))->mpcm_buffer_health / 256.0f);
			VizGraph_Render(g_buffer, 0, 88);

			VizGraph_PutMeasure2(g_sample, (g_state.max_dac_sample_value / 128.0f));
			VizGraph_Render(g_sample, 0, 160+4);

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
		.mpcm_buffer_health = 0,
	};
	z80vm->stateExtension = &z80vm_ext;	// attach Z80 VM extension
	z80vm->onWriteByte = &Z80VM_Extension_WriteByteCallback;
	z80vm->onEnterVBlank = &Z80VM_Extension_VBlankCallback;

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
		{ .type = Z_MPCM_TYPE_PCM_TURBO, .flags = (1<<Z_MPCM_FLAGS_SFX), .sample_rate = 0, .sample_path = "../../__example-rom/jump.wav" },
		{ .type = Z_MPCM_TYPE_DPCM_TURBO, .flags = (1<<Z_MPCM_FLAGS_SFX), .sample_rate = 25800, .sample_path = "../../__example-rom/jump.dpcm" },
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

	/* Setup graphs */
	{
		SDL_Color fg = { 0xFF, 0xFF, 0xFF, 0xFF };
		SDL_Color bg = { 0x80, 0x80, 0x80, 0xFF };
		g_buffer = VizGraph_Init(renderer, 320, 64, &bg, &fg);
		g_sample = VizGraph_Init(renderer, 320, 64, &bg, &fg);
	}

	/* Emulation loop */
	assert(!z80vm->z80State.cycles_emulated);	// shouldn't have emulated any cycles by now
	SDL_ResumeAudioStreamDevice(audio_stream);
	
	bool running = true;
	size_t prevFrameOvershootCycles = 0;
	while (running) {
		const uint64_t frame_start_ns = SDL_GetTicksNS();

		running = handle_events();

		// Emulate shit
		g_state.max_dac_sample_value = 0;
		prevFrameOvershootCycles = Z80VM_EmulateTVFrame(z80vm, prevFrameOvershootCycles);

		// Render audio
		YM_DAC_RenderOutput(&ym_dac_device, z80vm);
		SDL_PutAudioStreamData(audio_stream, ym_dac_device.buffer, ym_dac_device.buffer_pos);
		YM_DAC_FlushBuffer(&ym_dac_device);

		render_video_frame();

		// Cap at 60 fps
		const uint64_t frame_end_ns = SDL_GetTicksNS();
		const int64_t delay_ns = 1000000000 / 60 - (frame_end_ns - frame_start_ns);

		if (delay_ns > 0) {
			SDL_DelayPrecise(delay_ns);
		}
	}

	VizGraph_Destroy(g_buffer);
	g_buffer = NULL;

	SDL_DestroyAudioStream(audio_stream);
	SDL_DestroyWindow(window);
	SDL_DestroyRenderer(renderer);

	Z80VM_Destroy(z80vm);

    SDL_Quit();
    return 0;
}
