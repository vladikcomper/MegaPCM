#!/usr/bin/env python3
import argparse
from operator import attrgetter
from typing import NamedTuple, List

"""
Converts raw offset string to integer
"""
def offsetStringToInt(raw_offset: str) -> int:
	if raw_offset.startswith('0x') or raw_offset.startswith('$'):
		return int(raw_offset, base=16)
	elif raw_offset.endswith('h'):
		return int(raw_offset[:-1], base=16)
	else:
		return int(raw_offset)


"""
Controls program usage and gets command line arguments
"""
def getArgs():
	parser = argparse.ArgumentParser(
		description='Converts text symbol files generated by SJasmPlus to C/C++ or ASM header files.'
	)
	parser.add_argument('inputFilename', type=str)
	parser.add_argument('outputFilename', type=str)
	parser.add_argument('-p', '--prefix', type=str, default='',
		help='Prefix appended to all symbols in the resulting header file'
	)
	parser.add_argument('-l', '--locals', action='store_true',
		help='Don\'t strip local labels (symbols that are concatenated via dot)'
	)
	parser.add_argument('-s', '--sort', action='store_true',
		help='Sort symbols by offsets'
	)
	parser.add_argument('-f', '--outputFormat', choices=('h', 'asm'), default='h',
		help='Output format (e.g. C/C++ or assembly header)'
	)
	args = parser.parse_args()

	return args


def main():
	# Get command-line arguments
	args = getArgs()

	SymbolEntry = NamedTuple('SymbolEntry', label=str, offset=int)
	symbols: List[SymbolEntry] = []

	# Step 1: Read input file into `symbols` ...
	with open(args.inputFilename, 'r') as inputFile:
		for line in inputFile:
			if not ': EQU ' in line:
				continue

			label, raw_offset = map(str.strip, line.split(': EQU '))

			# Skip local labels unless "locals" option is given
			if not args.locals and '.' in label:
				continue

			offset = offsetStringToInt(raw_offset)

			symbols.append(SymbolEntry(label=label, offset=offset))

	# Step 2: Transform `symbols` if necessary ...
	if args.sort:
		symbols = sorted(symbols, key=attrgetter('offset'))

	# Step 3: Output `symbols` to .h or .asm file ...
	with open(args.outputFilename, 'w') as outputFilename:
		for symbol in symbols:
			if args.outputFormat == 'h':
				outputFilename.write(f'#define\t{args.prefix}{symbol.label.replace(".", "_")}\t0x{symbol.offset:x}\n')
			elif args.outputFormat == 'asm':
				outputFilename.write(f'{args.prefix}{symbol.label}:\tequ ${symbol.offset:x}\n')

if __name__ == '__main__':
	main()
