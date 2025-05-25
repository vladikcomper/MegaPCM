#!/usr/bin/env python
from typing import Tuple
import argparse
import numpy as np
import math
import sys

input_fn = "test.pcm"
output_fn = "test.dpcm"

deltaTables = (
	# 0 - Standard
	np.array([0, 1, 2, 4, 8, 16, 32, 64, -128, -1, -2, -4, -8, -16, -32, -64], dtype=np.int8),
	# 1 - DPCM-HQ Type 1 (SGDK-like)
	np.array([-34, -21, -13, -8, -5, -3, -2, -1, 0, 1, 2, 3, 5, 8, 13, 21], dtype=np.int8),
)


input_buff = np.fromfile(input_fn, dtype=np.int8) + (-128)

def encode(samples: np.ndarray, deltaTable: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
	if samples.size % 2: raise Exception('Buffer should contain even number of samples')
	samples_predicted = np.empty_like(samples)
	outdeltas = np.empty_like(samples)
	current_sample = 0

	for i in range(len(samples)):
		actual_sample = samples[i]
		predicted_samples = current_sample + deltaTable
		best_delta_index = np.argmin(np.abs(np.subtract(actual_sample, predicted_samples, dtype=np.int16)))
		current_sample = predicted_samples[best_delta_index]
		outdeltas[i] = best_delta_index
		samples_predicted[i] = current_sample

	rmse = np.sqrt(np.mean((samples_predicted - samples) ** 2))
	return ((outdeltas[::2] << 4) + outdeltas[1::2], rmse)


def decode(deltaNibbles: np.ndarray, deltaTable: np.ndarray):
	deltasBytes = np.empty(deltaNibbles.size * 2, dtype=np.uint8)
	deltasBytes[0::2] = deltaNibbles >> 4
	deltasBytes[1::2] = deltaNibbles & 0xF
	deltas = deltaTable[deltasBytes]
	return deltas.cumsum(dtype=np.int8)


if __name__ == '__main__':
	# Parse CLI arguments
	parser = argparse.ArgumentParser(description='DPCM-HQ compressor and decompressor (reference implementation)')
	parser.add_argument("input_filename", help="Input file path (DPCM or raw PCM)")
	parser.add_argument("output_filename", help="Output file path (raw PCM or DPCM)")
	parser.add_argument("-d", "--decompress", action="store_true")
	parser.add_argument("-t", "--table", type=int, default=0)
	args = parser.parse_args()

	# Default compression mode
	if not args.decompress:
		input_buff = np.fromfile(args.input_filename, dtype=np.int8) + (-128) # signed 8-bit format for faster overflow detection
		delta_table = deltaTables[args.table]
		output_buff, rmse = encode(input_buff, delta_table)
		print(f"RMSE: {rmse:f}")
		with open(args.output_filename, 'wb') as output_file:
			output_file.write(bytes([0xD0, args.table]))
			output_buff.tofile(output_file)

	else:
		input_buff = np.fromfile(args.input_filename, dtype=np.uint8)
		if input_buff[0] != 0xD0:
			raise Exception('Invalid DPCM-HQ header: 0xD0 expected as the first byte')
		delta_table = deltaTables[int(input_buff[1])]
		output_buff = decode(input_buff[2:], delta_table) + (-128)
		output_buff.tofile(args.output_filename)
