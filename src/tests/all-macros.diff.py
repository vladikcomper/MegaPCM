#!/usr/bin/env python3
files = (
    ('all-macros.gen','all-macros.gen.sym.log'),
    ('all-macros.as.gen','all-macros.as.gen.lst.log'),
    ('all-macros.asm68k.gen','all-macros.asm68k.gen.sym.log'),
)

def extractMacroExpansions(rom_path: str, sym_path: str):
    with open(sym_path, 'r') as sym:
        symbol_tuples = (line.split(':', maxsplit=1) for line in filter(lambda s: ':' in s, sym.readlines()))
        symbol_table = dict(((label.strip(), int(offset, 16)) for offset, label in symbol_tuples))
    with open(rom_path, 'rb') as rom:
        block_start, block_end = symbol_table['MacroExpansions'], symbol_table['MacroExpansions_End']
        rom.seek(block_start)
        return rom.read(block_end - block_start)

blocks = list(extractMacroExpansions(rom_path, sym_path) for rom_path, sym_path in files)

if not all(block == blocks[0] for block in blocks[1:]):
    print("FAILURE: Macro expansions differ.")
    exit(1)
else:
    print("SUCCESS: Macro expansions match for all targets.")
