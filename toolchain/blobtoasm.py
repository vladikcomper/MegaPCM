#!/usr/bin/env python3
import argparse
from dataclasses import dataclass
from typing import Dict, NamedTuple, Union, List, Tuple


InjectData = NamedTuple('InjectData', size=int, expression=str, inline=bool)


@dataclass
class DataToken:
	size: int

	def render(self):
		raise Exception('Not implemented')


@dataclass
class DataConstantToken(DataToken):
	value: int

	def render(self):
		if self.size == 1:
			return f'${self.value:02X}'
		elif self.size == 2:
			return f'${self.value:04X}'
		elif self.size == 4:
			return f'${self.value:08X}'
		raise Exception(f'Unknown size: {self.size}')


@dataclass
class DataExpressionToken(DataToken):
	expression: str

	def render(self):
		return self.expression


@dataclass
class CustomLine:
	expression: str

	def render(self):
		return self.expression


def getSymbolTable(symbolTablePath: str) -> Dict[str, int]:
	symbolTable: Dict[str, int] = dict()

	with open(symbolTablePath, 'r') as f:
		for line in f.readlines():
			if len(line.strip()) == 0:
				continue

			symbol, offset = map(str.strip, line.split(':'))
			symbolTable[symbol] = int(offset, 16)

	return symbolTable


def encodeSize(size: int):
	if size == 1:
		return 'b'
	elif size == 2:
		return 'w'
	elif size == 4:
		return 'l'
	else:
		raise Exception(f'Unsupported size: {size}')

def decodeSize(size: str):
	if size in ('long', 'l'):
		return 4
	elif size in ('word', 'w'):
		return 2
	elif size in ('byte', 'b'):
		return 1
	else:
		raise Exception(f'Unknown size: {size}')


def getInjectData(injectMapPath: str, symbolTable: Dict[str, int]) -> Dict[int, InjectData]:
	injectData: Dict[int, InjectData] = dict()

	def decodeInline(mode: str):
		if mode == 'inline':
			return True
		elif mode == 'line':
			return False
		else:
			raise Exception(f'Unkown mode specifier: {mode}')


	with open(injectMapPath, 'r') as f:
		for line in f.readlines():
			if len(line.strip()) == 0:
				continue

			symbolWithDisp, size, mode, injectedExpression = map(str.strip, line.split(':'))
			symbol, disp = symbolWithDisp.split('+')

			symbolOffset = symbolTable.get(symbol)

			if symbolOffset is None:
				raise Exception(f'Symbol not found: {symbol}')

			offset = symbolOffset + int(disp, 16)

			injectData[offset] = InjectData(
				size=decodeSize(size),
				inline=decodeInline(mode),
				expression=injectedExpression
			)

	return injectData


def tokenizeBlob(blob: bytes, symbolTable: Dict[str, int], injectionData: Dict[int, InjectData], unit_size) -> List[Union[DataToken, CustomLine]]:

	tokens: List[Union[DataToken, CustomLine]] = []

	def tokenizeDataRange(start_offset, end_offset, unit_size) -> List[Union[DataToken, CustomLine]]:
		tokens = []

		range_size = end_offset - start_offset
		end_offset_corrected = end_offset - (range_size % unit_size)

		# Generate tokens of `unit_size`
		tokens = tokens + [
			DataConstantToken(size=unit_size, value=int.from_bytes(blob[offset:offset+unit_size], byteorder='big'))
			for offset in range(start_offset, end_offset_corrected, unit_size)
		]

		# Generate tokens from the remainder (if present) ...
		if end_offset - end_offset_corrected == 1:
			tokens.append(DataConstantToken(size=1, value=int.from_bytes(blob[end_offset_corrected:end_offset_corrected+1], byteorder='big')))
		elif end_offset - end_offset_corrected == 2:
			tokens.append(DataConstantToken(size=2, value=int.from_bytes(blob[end_offset_corrected:end_offset_corrected+2], byteorder='big')))
		elif end_offset - end_offset_corrected == 3:
			tokens.append(DataConstantToken(size=2, value=int.from_bytes(blob[end_offset_corrected:end_offset_corrected+2], byteorder='big')))
			tokens.append(DataConstantToken(size=1, value=int.from_bytes(blob[end_offset_corrected+2:end_offset_corrected+3], byteorder='big')))

		return tokens

	# Make data ranges ...
	data_ranges: List[Tuple[int, int]] = []
	start_offset = 0
	for inject_offset, inject_data in sorted(injectionData.items()):
		data_ranges.append((start_offset, inject_offset))
		start_offset = inject_offset + inject_data.size
	data_ranges.append((start_offset, len(blob)))

	for start_offset, end_offset in data_ranges:
		tokens = tokens + tokenizeDataRange(start_offset, end_offset, unit_size)

		# If injection token is located at this range ...
		injectData = injectionData.get(end_offset)
		if injectData:
			if injectData.inline:
				tokens.append(DataExpressionToken(size=injectData.size, expression=injectData.expression))
			else:
				tokens.append(CustomLine(expression=injectData.expression))

	return tokens


def render(path: str, tokens: List[Union[DataToken, CustomLine]], units_per_line):
	with open(path, 'w') as f:
		line_opened = False
		line_num_units = 0
		last_data_token = None

		for token in tokens:
			if isinstance(token, DataToken):
				# Reset line if token size changes ...
				if last_data_token and last_data_token.size != token.size:
					line_opened = False

				# Open line if not openned
				if not line_opened or line_num_units == units_per_line:
					f.write(f'\n	dc.{encodeSize(token.size)}	')
					last_data_token = None
					line_num_units = 0
					line_opened = True
				else:
					f.write(', ')

				line_num_units += 1
				last_data_token = token
				f.write(token.render())

			elif isinstance(token, CustomLine):
				last_data_token = None
				line_opened = False
				f.write('\n\t' + token.render())


def main():
	parser = argparse.ArgumentParser(
		description='Renders binary files in M68K assembly.'
	)
	parser.add_argument('blob')
	parser.add_argument('outfile')
	parser.add_argument('-t', '--symbolTable',
		help='Path to a symbol table in log format, which may include control symbols for the conversion, e.g. __blob_start, __blob_end'
	)
	parser.add_argument('-m', '--injectionMap',
		help='Path to injection map, which tells how to inject symbols marked as __inject_* in symbol table'
	)
	parser.add_argument('-s', '--unitSize',
		choices=('long', 'word', 'byte', 'l', 'w', 'b'),
		default='long',
		help='Specifies the default unit size when rendering blob; this will select between dc.l, dc.w and dc.b',
	)
	parser.add_argument('-l', '--unitsPerLine',
		type=int,
		default=8,
		help='Specifies number of units per line',	
	)

	args = parser.parse_args()

	symbolTable = getSymbolTable(args.symbolTable) if args.symbolTable else dict()
	injectionData = getInjectData(args.injectionMap, symbolTable) if args.injectionMap else dict()

	with open(args.blob, 'rb') as f:
		unit_size = decodeSize(args.unitSize)
		units_per_line = int(args.unitsPerLine)

		# Read BLOB into memory and trim it ...
		blob = f.read()
		start, end = (symbolTable.get('__blob_start') or 0, symbolTable.get('__blob_end') or len(blob))
		blob = blob[start:end]

		# Start rendering blob ...
		tokens = tokenizeBlob(blob, symbolTable, injectionData, unit_size)

		render(args.outfile, tokens, units_per_line)


if __name__ == '__main__':
	main()
