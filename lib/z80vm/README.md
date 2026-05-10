
# Z80VM

Implements a basic Z80 virtual machine aimed to provide a sandbox environment to run Mega PCM 2.

It uses a customized z80emu v.1.3.0 (c) by Lin Ke-Fong (https://github.com/anotherlin/z80emu)

## z80emu changes

- Refactored to use inline functions instead of macros for Z80 IO API;
- Fixed a serious bug where repeated `DI`/`EI` dirupted cycle counter and could hang emulation;
- Replaced `z80user.h` with Z80VM API;
- Don't use ANSI C;
- Overhauled build system.
