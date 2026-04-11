#!/usr/bin/env python
from typing import Tuple
from itertools import product
import numpy as np
import json
import argparse

input_fn = "test.pcm"
output_fn = "test.dpcm"

deltaTables = (
	# 0 - Standard
	np.array([0, 1, 2, 4, 8, 16, 32, 64, -128, -1, -2, -4, -8, -16, -32, -64], dtype=np.int8),
	# 1 - DPCM-HQ Type 1 (SGDK-like)
	np.array([-34, -21, -13, -8, -5, -3, -2, -1, 0, 1, 2, 3, 5, 8, 13, 21], dtype=np.int8),
	# 2 - DPCM-HQ Type 2 (Vladikcomper's custom)
	np.array([-20, -12, -8, -6, -4, -3, -2, -1, 0, 1, 2, 3, 4, 6, 8, 12], dtype=np.int8),
)

def encodeV2(samples: np.ndarray, delta_table: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
	if samples.size % 2: raise Exception('Buffer should contain even number of samples')
	if samples.dtype != np.uint8: raise Exception('Buffer must be 8-bit unsigned PCM')
	samples_predicted = np.empty_like(samples)
	outdeltas = np.empty_like(samples)
	current_sample = 0x80

	for i in range(len(samples)):
		actual_sample = samples[i]
		predicted_samples = np.add(current_sample, delta_table, dtype=np.int16)
		nonclipped_predicted_samples = predicted_samples.astype(np.uint16) < 0x100
		abs_errors = np.full_like(predicted_samples, 0x7FFF)
		np.abs(actual_sample - predicted_samples, out=abs_errors, where=nonclipped_predicted_samples) # calc errors for non-clipped samples only
		best_delta_index = np.argmin(abs_errors)
		current_sample = predicted_samples[best_delta_index].astype(np.uint8)
		outdeltas[i] = best_delta_index
		samples_predicted[i] = current_sample

	rmse = np.sqrt(np.mean(np.subtract(samples_predicted, samples, dtype=np.int16) ** 2))
	return ((outdeltas[::2] << 4) + outdeltas[1::2], rmse)

def encodeV3(samples: np.ndarray, delta_table: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
	if samples.size % 2: raise Exception('Buffer should contain even number of samples')
	if samples.dtype != np.uint8: raise Exception('Buffer must be 8-bit unsigned PCM')
	samples_predicted = np.empty_like(samples)
	outdeltas = np.empty_like(samples)
	current_sample = 0x80

	k = 0.5
	delta_click_factor = np.full(delta_table.size, 0, dtype=np.int32)
	np.square(np.subtract(np.abs(delta_table, dtype=np.int32), 32, dtype=np.int32), out=delta_click_factor, where=np.abs(delta_table, dtype=np.int32) > 32)
	delta_click_factor = k * delta_click_factor

	for i in range(len(samples)):
		actual_sample = samples[i]
		predicted_samples = np.add(current_sample, delta_table, dtype=np.uint8, casting='unsafe')
		cost = np.square(np.subtract(actual_sample, predicted_samples, dtype=np.int32), dtype=np.int32) + delta_click_factor
		best_delta_index = np.argmin(cost)
		current_sample = predicted_samples[best_delta_index]
		outdeltas[i] = best_delta_index
		samples_predicted[i] = current_sample

	rmse = np.sqrt(np.mean(np.subtract(samples_predicted, samples, dtype=np.int16) ** 2))
	return ((outdeltas[::2] << 4) + outdeltas[1::2], rmse)


encode_algorithms = (encodeV2,encodeV3)


def decode(deltaNibbles: np.ndarray, deltaTable: np.ndarray):
	deltasBytes = np.empty(deltaNibbles.size * 2, dtype=np.uint8)
	deltasBytes[0::2] = deltaNibbles >> 4
	deltasBytes[1::2] = deltaNibbles & 0xF
	deltas = deltaTable[deltasBytes]
	return (deltas.cumsum(dtype=np.int8) + (-128)).astype(np.uint8)


def runDecoder(path: str) -> np.ndarray:
	input_buff = np.fromfile(path, dtype=np.uint8)
	if input_buff[0:3] != 'DQ1':
		return decode(input_buff, deltaTables[0])
	else:
		return decode(input_buff[9:], deltaTables[int(input_buff[8] // 0x10)])

def readFromFile(path: str):
	buff = np.fromfile(path, dtype=np.uint8)
	if buff.size % 2 == 1:
		return np.append(buff, buff[-1])
	else:
		return buff

if __name__ == '__main__':
	# Parse CLI arguments
	parser = argparse.ArgumentParser(description='DPCM-HQ compressor and decompressor (reference implementation)')
	parser.add_argument("input_filename", help="Input file path (DPCM or raw PCM)")
	parser.add_argument("output_filename", help="Output file path (raw PCM or DPCM)")
	parser.add_argument("-a", "--algorithm", type=int, default=-1)
	parser.add_argument("-t", "--table", type=int, default=-1)
	parser.add_argument("-d", "--decompress", action="store_true")
	parser.add_argument("-l", "--logdeltas", action="store_true")
	parser.add_argument("-c", "--compare", action="store_true")
	parser.add_argument("-j", "--logjson", action="store_true")
	args = parser.parse_args()

	# Comparison mode
	if args.compare:
		print(f"Comparing '{args.input_filename}' (PCM source) with '{args.output_filename}' (DPCM)...")
		input_buff = readFromFile(args.input_filename)
		input_buff_2 = runDecoder(args.output_filename)
		if input_buff.size != input_buff_2.size:
			print(f"WARNING! Number of samples don't match ({input_buff.size} != {input_buff_2.size})")
			input_buff_2 = np.append(input_buff_2, [input_buff_2[-1], input_buff_2[-1]])
		rmse = np.sqrt(np.mean(np.subtract(input_buff_2, input_buff, dtype=np.int16) ** 2))
		print(f'{{"rmse":{rmse:f}}}')

	# Default compression mode
	elif not args.decompress:
		print(f"Compressing '{args.input_filename}' (PCM) into '{args.output_filename}' (DPCM)...")

		input_buff = readFromFile(args.input_filename)

		algos = encode_algorithms if args.algorithm == -1 else (encode_algorithms[args.algorithm],)
		tables = deltaTables if args.table == -1 else (deltaTables[args.table],)

		best_rmse, best_rmse_index = 0x1000, -1
		results = []
		for (algorithm, (table_index, delta_table)) in product(algos, enumerate(tables)):
			print(f"#{len(results):d}: encoder={algorithm.__name__}, table={table_index:d}...")
			output_buff, rmse = algorithm(input_buff, delta_table)
			print(f"    rmse={rmse:f}")
			results.append((output_buff, rmse, table_index, algorithm.__name__))
			if rmse < best_rmse:
				best_rmse = rmse
				best_rmse_index = len(results)-1

		if not args.logjson:
			output_buff, rmse, table_index, _ = results[best_rmse_index]
			if len(results) > 1:
				print(f"Selecting result #{best_rmse_index:d}")
				print(f"rmse={rmse:f}")

			with open(args.output_filename, 'wb') as output_file:
				stream_len = output_buff.size
				output_file.write(b"DQ1")
				output_file.write(bytes([stream_len&0xFF0000<<16,stream_len&0xFF00<<8,stream_len&0xFF])) # stream size (Big-Endian)
				output_file.write(bytes([0, 0])) # sample rate
				output_file.write(bytes([table_index * 0x10])) # table type
				output_buff.tofile(output_file)

		else:
			with open(args.output_filename, 'w') as output_file:
				json.dump([
					{"rmse": rmse, "table_index": table_index, "encoder": encoder}
						for _, rmse, table_index, encoder in results
				], output_file, indent=2)

	# Decompression mode
	else:
		output_buff = runDecoder(args.input_filename)
		if args.logdeltas:
			output_deltas = np.diff(output_buff, prepend=0x80)
			np.savetxt(args.output_filename, output_deltas, fmt="%d")
		else:
			output_buff.tofile(args.output_filename)
