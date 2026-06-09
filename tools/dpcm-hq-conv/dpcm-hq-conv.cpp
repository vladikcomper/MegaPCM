
/*
 * DPCM-HQ Encoder and Decoder v.1.0
 *
 * - Encodes PCM or WAV files to DPCM-HQ
 * - Decodes DPCM or DPCM-HQ to WAV
 *
 * Copyright (c) 2025-2026 Vladikcomper
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <array>
#include <future>
#include <optional>
#include <vector>
#include <cmath>
#include <cstdlib>
#include <format>
#include <cstring>
#include <string>
#include <string_view>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <stdexcept>

using namespace std;
namespace fs = std::filesystem;

/* Basic logging */
namespace Logger {
	enum class Level { DEBUG, INFO, WARN, ERROR, QUIET };
	Level logLevel = Level::INFO;

	inline void debug(const string& msg) {
		if (logLevel > Level::DEBUG) return;
		cerr << format("[DEBUG] {}\n", msg);
	}

	inline void info(const string& msg) {
		if (logLevel > Level::INFO) return;
		cerr << format("{}\n", msg);
	}

	inline void warn(const string& msg) {
		if (logLevel > Level::WARN) return;
		cerr << format("[WARN] {}\n", msg);
	}

	inline void error(const string& msg) {
		if (logLevel > Level::ERROR) return;
		cerr << format("[ERROR] {}\n", msg);
	}
}

/* Program arguments handling */
struct Arguments {
	enum class Mode { ENCODE_TO_DPCM, DECODE_TO_WAV };
	static constexpr string_view ModeToString[] = { "AUTO", "ENCODE_TO_DPCM", "DECODE_TO_WAV" };

	fs::path inputPath = "";
	fs::path outputPath = "";
	optional<Mode> mode;
	optional<Logger::Level> logLevel;
	optional<size_t> forcedSampleRate;
	optional<int> deltaTableIndex;
	optional<float> k;

	static constexpr char programUsageString[] =
		"DPCM-HQ Encoder and Decoder v.1.0.1\n"
		"(c) 2026, Vladikcomper\n"
		"\n"
		"USAGE:\n"
		"	dpcm-hq-conv [OPTIONS]... INPUT_FILE [OUTPUT_FILE]\n"
		"\n"
		"EXAMPLES:\n"
		"\n"
		"	Encode mysample.wav to mysample.dpcmq (if input is .wav, output is .dpcmq by default):\n"
		"		dpcm-hq-conv mysample.wav\n"
		"\n"
		"	Same command, but displays most of default encode options (optional):\n"
		"		dpcm-hq-conv --mode auto --table best --log info mysample.wav mysample.dpcmq\n"
		"\n"
		"	Decode mysample.dpcmq to mysample.dpcmq.wav (if input is .dpcmq, output is .dpcmq.wav by default):\n"
		"		dpcm-hq-conv mysample.dpcmq\n"
		"\n"
		"	Decode mysample.dpcm (classic DPCM) to mysample-decoded.wav:\n"
		"		dpcm-hq-conv mysample.dpcm mysample-decoded.wav\n"
		"\n"
		"	Encode rawsample.pcm (headless) to sample.dpcmq with 16 kHz rate:\n"
		"		dpcm-hq-conv --rate 16000 rawsample.pcm sample.dpcmq\n"
		"\n"
		"OPTIONS:\n"
		"	-m|--mode [MODE]\n"
		"		Sets operation MODE. Possible values:\n"
		"			a|auto (default) - auto-detect based on input file extension (.dpcmq or .dpcm implies decode, everything else implies encode)\n"
		"			e|encode - encode WAV or raw PCM file to DPCM-HQ file\n"
		"			d|decode - decode DPCM or DPCM-HQ file to WAV file\n"
		"\n"
		"	-t|--table [DELTA_INDEX_TABLE]\n"
		"		When in 'encode' MODE, selects the preferred delta table for the encoder. Possible values:\n"
		"			b|best (default) - try all tables, try to pick the best one based on certain stats\n"
		"			0, 1, 2 - specify table number manually (higher numbers results in more muffled sounds, but less noise)\n"
		"\n"
		"	-r|--rate [FORCED_RATE_HZ]\n"
		"		Forces the given sample rate on the output file (WAV or DPCM-HQ). This DOES NOT re-sample audio, just overwrites the original rate.\n"
		"\n"
		"	-l|--log [LOG_LEVEL]\n"
		"		Sets the logging level, useful for debugging or silencing the output.\n"
		"		Possible values: d|debug, i|info, w|warn, e|error, q|quiet. Default is i|info.\n"
		"\n";

	static Arguments fromCliArgs(int argc, char* argv[]) {
		enum class ParserState { OPTION_NAME_OR_PATH, OPTION_MODE, OPTION_LOG_LEVEL, OPTION_DELTA_TABLE_INDEX, OPTION_SAMPLE_RATE, OPTION_K };
		Arguments arguments;

		ParserState state = ParserState::OPTION_NAME_OR_PATH;
		for (int i = 0; i < argc; ++i) {
			switch (state) {
			case ParserState::OPTION_NAME_OR_PATH:				
				/* Parse arguments starting with "-" as options (option value to be parsed up next) */
				if (argv[i][0] == '-') {
					const char * argStart = argv[i] + 1;
					if (*argStart == '-') ++argStart;
					if (*argStart == 'm') state = ParserState::OPTION_MODE;
					else if (*argStart == 't') state = ParserState::OPTION_DELTA_TABLE_INDEX;
					else if (*argStart == 'l') state = ParserState::OPTION_LOG_LEVEL;
					else if (*argStart == 'r') state = ParserState::OPTION_SAMPLE_RATE;
					else if (*argStart == 'k') state = ParserState::OPTION_K; // `-k|--k` option is undocumented
					else throw runtime_error(format("Unknown option: {}", argv[i]));
				}

				/* Everything else is input/output path */
				else if (arguments.inputPath.empty()) arguments.inputPath = argv[i];
				else if (arguments.outputPath.empty()) arguments.outputPath = argv[i];
				else throw runtime_error(format("Unexpected argument: {}", argv[i]));

				break;

			case ParserState::OPTION_MODE:
				/* -m|--mode option value */
				if (argv[i][0] == 'a') arguments.mode = nullopt;
				else if (argv[i][0] == 'e') arguments.mode = Arguments::Mode::ENCODE_TO_DPCM;
				else if (argv[i][0] == 'd') arguments.mode = Arguments::Mode::DECODE_TO_WAV;
				else throw runtime_error(format("Unknown value for -m|--mode: {} (expected: a|auto, e|encode, d|decode)", argv[i]));
		        state = ParserState::OPTION_NAME_OR_PATH;
				break;

			case ParserState::OPTION_LOG_LEVEL:
				/* -l|--log option value */
				if (argv[i][0] == 'd') arguments.logLevel = Logger::Level::DEBUG;
				else if (argv[i][0] == 'i') arguments.logLevel = Logger::Level::INFO;
				else if (argv[i][0] == 'w') arguments.logLevel = Logger::Level::WARN;
				else if (argv[i][0] == 'e') arguments.logLevel = Logger::Level::ERROR;
				else if (argv[i][0] == 'q') arguments.logLevel = Logger::Level::QUIET;
				else throw runtime_error(format("Unknown value for -l|--log: {} (expected: d|debug, i|info, w|warn, e|error, q|quiet)", argv[i]));
		        state = ParserState::OPTION_NAME_OR_PATH;
				break;

	        case ParserState::OPTION_DELTA_TABLE_INDEX:
	        	/* -t|--table option value */
				if (argv[i][0] == 'b') arguments.deltaTableIndex = nullopt;
				else if (argv[i][0] == '0') arguments.deltaTableIndex = 0;
				else if (argv[i][0] == '1') arguments.deltaTableIndex = 1;
				else if (argv[i][0] == '2') arguments.deltaTableIndex = 2;
				else throw runtime_error(format("Unknown value for -t|--table: {} (expected: b|best, 0, 1, 2)", argv[i]));
		        state = ParserState::OPTION_NAME_OR_PATH;
				break;

			case ParserState::OPTION_SAMPLE_RATE:
				try {
					arguments.forcedSampleRate = stol(argv[i]);
				}
				catch (...) {
					throw runtime_error(format("Failed to parse value for -r|--rate: {} (expected a decimal number)", argv[i]));
				}
		        state = ParserState::OPTION_NAME_OR_PATH;
				break;

			case ParserState::OPTION_K:
				try {
					arguments.k = stof(argv[i]);
				}
				catch (...) {
					throw runtime_error(format("Failed to parse value for -k|--k: {} (expected a float, e.g. 0.5)", argv[i]));
				}
		        state = ParserState::OPTION_NAME_OR_PATH;
				break;
	        }
	    }
	    if (state != ParserState::OPTION_NAME_OR_PATH) throw runtime_error(format("Value expected after option: {}", argv[argc-1]));
	    return arguments;
	}
};

/* Delta tables for the encoder */
constexpr array<array<int8_t,16>, 3> deltaTables = {{
	// Table type 0x00
	{ 0, 1, 2, 4, 8, 16, 32, 64, -128, -1, -2, -4, -8, -16, -32, -64 },
	// Table type 0x10
	{ -34, -21, -13, -8, -5, -3, -2, -1, 0, 1, 2, 3, 5, 8, 13, 21 },
	// Table type 0x20
	{ -20, -12, -8, -6, -4, -3, -2, -1, 0, 1, 2, 3, 4, 6, 8, 12 }
}};

/* Numerically stable RMSE implementation for large moving windows */
struct RMSE {
	size_t count = 0;
	double mse = 0.0f;

	inline void addError(double err) {
		mse += ((err * err) - mse) / ++count;
	}
	inline double get() const {
		return sqrt(mse);
	}
};

/* Structural representation of DPCM-HQ stream with header + file read/write functions */
struct EncodedStream {
	size_t sampleRate;
	size_t deltaTableIndex;
	vector<uint8_t> data;

	void writeToFile(const string& filePath) const {
		ofstream file(filePath, ios::binary);
		if (!file.good()) throw runtime_error("Failed to open output file");
		file.exceptions(ios_base::failbit | ios_base::badbit);

		const auto streamLength = data.size();
		const char header[9] = {
			/* DPCM-HQ V1 magic string */
			'D', 'Q', '1',
			/* Stream length (Big Endian) */
			static_cast<char>((streamLength >> 16) & 0xFF),
			static_cast<char>((streamLength >> 8) & 0xFF),
			static_cast<char>(streamLength & 0xFF),
			/* Sample rate (Big Endian) */
			static_cast<char>((sampleRate >> 8) & 0xFF),
			static_cast<char>(sampleRate & 0xFF),
			/* Table type */
			static_cast<char>(deltaTableIndex * 0x10)
		};
		file.write(header, 9);
		file.write(reinterpret_cast<const char*>(data.data()), data.size());
	}

	static EncodedStream readFromFile(const string& filePath) {
		ifstream file(filePath, ios::binary);
		if (!file.good()) throw runtime_error("Failed to open input file");

		uint8_t maybeHeader[9];
		file.read(reinterpret_cast<char*>(maybeHeader), 9);

		size_t sampleRate = 0;
		size_t deltaTableIndex = 0;
		size_t streamLength = 0;

		/* If file is a DPCM-HQ file, fill-in the header */
		if (file.good() && maybeHeader[0] == 'D' && maybeHeader[1] == 'Q') {
			Logger::info("Detected DPCM-HQ header");
			sampleRate = (maybeHeader[6] << 8) | maybeHeader[7];
			streamLength = (maybeHeader[3] << 16) | (maybeHeader[4] << 8) | maybeHeader[5];
			deltaTableIndex = maybeHeader[8] / 0x10;
		}
		/* Otherwise, assume classic DPCM */
		else {
			file.clear();
			file.seekg(0, ios::end);
			streamLength = file.tellg();
			file.seekg(0, ios::beg);
		}

		file.exceptions(ios_base::failbit | ios_base::badbit);
		vector<uint8_t> data(streamLength);
		file.read(reinterpret_cast<char*>(data.data()), streamLength);

		return EncodedStream {
			.sampleRate = sampleRate,
			.deltaTableIndex = deltaTableIndex,
			.data = data
		};
	}

	string dumpDebugInfo() const {
	    return format(
	        "{{ .sampleRate = {}, .deltaTableIndex = {}, .data.size = {} }}",
	        sampleRate, deltaTableIndex, data.size()
	    );
	}
};

/* Structural representation of WAVE or RAW stream with header + file read/write functions */
struct DecodedStream {
	size_t sampleRate;
	vector<uint8_t> data;

	struct RIFFHeader {
		char fileTypeBlockId[4];
		uint32_t fileSize;
		char fileFormatId[4];

		string dumpDebugInfo() const {
			return format(
                "{{ .fileTypeBlockId = '{}', fileSize = {}, fileFormatId = '{}' }}",
                string(fileTypeBlockId, 4), fileSize, string(fileFormatId, 4)
            );
		}
	};
	struct RIFFFmtChunk {
		char chunkId[4];
		uint32_t chunkSize;
		uint16_t audioFormat;
		uint16_t numChannels;
		uint32_t sampleRate;
		uint32_t bytesPerSec;
		uint16_t bytesPerBlock;
		uint16_t bitsPerSample;

		string dumpDebugInfo() const {
			return format(
				"{{ .chunkId = '{}', chunkSize = {}, audioFormat = {}, numChannels = {}, sampleRate = {}, bytesPerSec = {}, bytesPerBlock = {}, bitsPerSample = {} }}",
                string(chunkId, 4), chunkSize, audioFormat, numChannels, sampleRate, bytesPerSec, bytesPerBlock, bitsPerSample
            );
		}
	};
	struct RIFFDataChunk {
		char chunkId[4];
		uint32_t chunkSize;

		string dumpDebugInfo() const {
		    return format(
		    	"{{ .chunkId = '{}', chunkSize = {} }}",
                string(chunkId, 4), chunkSize
            );
		}
	};

	void writeToFile(const string& filePath) const {
		ofstream file(filePath, ios::binary);
		if (!file.good()) throw runtime_error("Failed to open output file");
		file.exceptions(ios_base::failbit | ios_base::badbit);
		RIFFHeader header {
			.fileTypeBlockId = {'R','I','F','F'},
			.fileSize = static_cast<uint32_t>(sizeof(RIFFHeader) + sizeof(RIFFFmtChunk) + sizeof(RIFFDataChunk) + data.size() - 8),
			.fileFormatId = {'W','A','V','E'}
		};
		RIFFFmtChunk fmtChunk {
			.chunkId = {'f','m','t',' '},
			.chunkSize = sizeof(RIFFFmtChunk) - 8,
			.audioFormat = 1,
			.numChannels = 1,
			.sampleRate = static_cast<uint32_t>(sampleRate),
			.bytesPerSec = static_cast<uint32_t>(sampleRate),
			.bytesPerBlock = 1,
			.bitsPerSample = 8
		};
		RIFFDataChunk dataChunk {
			.chunkId = {'d','a','t','a'},
			.chunkSize = static_cast<uint32_t>(data.size())
		};
		file.write(reinterpret_cast<const char*>(&header), sizeof(header));
		file.write(reinterpret_cast<const char*>(&fmtChunk), sizeof(fmtChunk));
		file.write(reinterpret_cast<const char*>(&dataChunk), sizeof(dataChunk));
		file.write(reinterpret_cast<const char*>(data.data()), data.size());
	}

	static DecodedStream readFromFile(const string& filePath) {
		ifstream file(filePath, ios::binary);
		if (!file.good()) throw runtime_error("Failed to open input file");

		size_t sampleRate = 0;
		size_t streamLength = 0;

		RIFFHeader maybeHeader;
		file.read(reinterpret_cast<char*>(&maybeHeader), sizeof(maybeHeader));

		/* If file is a WAVE file, parse the header */
		if (file.good() && strncmp(maybeHeader.fileTypeBlockId, "RIFF", 4) == 0) {
			Logger::info("Detected WAVE header");
			Logger::debug(format("RIFFHeader = {}", maybeHeader.dumpDebugInfo()));
			if (strncmp(maybeHeader.fileFormatId, "WAVE", 4) != 0) throw runtime_error("Invalid WAVE header");

			RIFFFmtChunk fmtChunk;
			file.exceptions(ios_base::failbit | ios_base::badbit);
			file.read(reinterpret_cast<char*>(&fmtChunk), sizeof(fmtChunk));
			Logger::debug(format("RIFFFmtChunk = {}", fmtChunk.dumpDebugInfo()));
			if (strncmp(fmtChunk.chunkId, "fmt ", 4) != 0) throw runtime_error("Invalid WAVE: Missing 'fmt' chunk");
			if (fmtChunk.audioFormat != 1 && fmtChunk.audioFormat != 0xFFFE) throw runtime_error("Invalid WAVE: Not in PCM format");
			if (fmtChunk.numChannels != 1) throw runtime_error("Invalid WAVE: Audio must be mono");
			if (fmtChunk.bitsPerSample != 8) throw runtime_error("Invalid WAVE: Audio must 8-bit unsigned PCM");

			RIFFDataChunk maybeDataChunk;
			bool locatedDataChunk = false;
			while (!locatedDataChunk && !file.fail()) {
				file.read(reinterpret_cast<char*>(&maybeDataChunk), sizeof(maybeDataChunk));
				locatedDataChunk = strncmp(maybeDataChunk.chunkId, "data", 4) == 0;
				if (!locatedDataChunk) {
					Logger::debug(format("Skipping chunk: {}", maybeDataChunk.dumpDebugInfo()));
					file.seekg(maybeDataChunk.chunkSize, ios::cur);
				}
			}
			if (!locatedDataChunk) throw runtime_error("Invalid WAVE: Couldn't locate 'data' chunk");
			Logger::debug(format("RIFFDataChunk = {}", maybeDataChunk.dumpDebugInfo()));

			sampleRate = fmtChunk.sampleRate;
			streamLength = maybeDataChunk.chunkSize;
		}
		/* Otherwise, assume raw stream */
		else {
			file.clear();
			file.exceptions(ios_base::failbit | ios_base::badbit);
			file.seekg(0, ios::end);
			streamLength = file.tellg();
			file.seekg(0, ios::beg);			
		}

		vector<uint8_t> data(streamLength);
		file.read(reinterpret_cast<char*>(data.data()), streamLength);

		return DecodedStream {
			.sampleRate = sampleRate,
			.data = data
		};
	}

	string dumpDebugInfo() const {
		return format(
			"{{ .sampleRate = {}, .data.size = {} }}",
			sampleRate, data.size()
		);
	}
};

/* DPCM-HQ encoder implementation */
namespace Encoder {
	struct EncodingResult {
		size_t deltaTableIndex;
		RMSE rmse;
		vector<uint8_t> data;

		string dumpDebugInfo() const {
			return format(
				"{{ .deltaTableIndex = {}, .RMSE = {}, .data.size = {} }}",
				deltaTableIndex, rmse.get(), data.size()
			);
		} 
	};

	constexpr auto deltaClickFactors = [](){
		array<array<uint16_t,16>, 3> deltaClickFactors{};
	    for (size_t i = 0; i < deltaTables.size(); ++i) {
	        for (size_t j = 0; j < deltaTables[i].size(); ++j) {
	        	// FIXME: Turn the threshold of 0x20 into a parameter
	        	const int16_t threshold = (deltaTables[i][j] < 0 ? -deltaTables[i][j] : deltaTables[i][j]) - 0x20;
	            deltaClickFactors[i][j] = threshold > 0 ? threshold * threshold : 0;
	        }
	    }
		return deltaClickFactors;
	}();

	EncodingResult encode(const vector<uint8_t>& samples, size_t deltaTableIndex, float k = 0.5f) {
		if (samples.size() % 2) throw runtime_error("Buffer should contain even number of samples");
		vector<uint8_t> outDeltas(samples.size() / 2);

	    const auto deltaTable = deltaTables.at(deltaTableIndex);
	    const auto deltaClickFactor = deltaClickFactors.at(deltaTableIndex);

	    uint8_t currentSample = 0x80;
	    array<uint8_t, 16> predictedSamples;
	    array<int32_t, 16> errorCost;
	    RMSE rmse;
	    for (size_t t = 0; t < samples.size(); ++t) {
	    	const auto actualSample = samples[t];
	    	for (size_t i = 0; i < 16; ++i) {
	    		predictedSamples[i] = currentSample + deltaTable[i];
	    	}
	    	for (size_t i = 0; i < 16; ++i) {
	    		errorCost[i] = (int32_t)actualSample - predictedSamples[i];
	    		errorCost[i] *= errorCost[i];
	    		errorCost[i] += deltaClickFactor[i] * k;
	    	}
	    	size_t bestDeltaIndex = 0;
	    	auto minErrorCost = errorCost[0];
	    	for (size_t i = 1; i < 16; ++i) {
	    		if (errorCost[i] < minErrorCost) {
	    			minErrorCost = errorCost[i];
	    			bestDeltaIndex = i;
	    		}
	    	}
	    	currentSample = predictedSamples[bestDeltaIndex];
	    	outDeltas[t / 2] |= t % 2 ? bestDeltaIndex : bestDeltaIndex * 16;
	    	rmse.addError((double)actualSample-currentSample);
	    }

	    return {
	    	.deltaTableIndex = deltaTableIndex,
	    	.rmse = rmse,
	    	.data = outDeltas
	    };
	}
}

namespace Decoder {
	vector<uint8_t> decode(const vector<uint8_t>& data, size_t deltaTableIndex) {
		uint8_t currentSample = 0x80;
		vector<uint8_t> output(data.size() * 2);
		const auto deltaTable = deltaTables.at(deltaTableIndex);
		size_t i = 0;
		for (const auto byte : data) {
			currentSample += deltaTable[byte>>4];
			output[i++] = currentSample;
			currentSample += deltaTable[byte&0xF];
			output[i++] = currentSample;
		}
		return output;
	}
}

/* Main program stars here */
int main(int argc, char* argv[]) {
	if (argc < 2) {
		cout << Arguments::programUsageString;
		exit(-1);
	}

	/* Parse and setup command-line arguments */
	auto arguments = [&](){
		try {
			auto arguments = Arguments::fromCliArgs(argc-1, argv+1);

			Logger::logLevel = arguments.logLevel.value_or(Logger::Level::INFO);

			if (arguments.inputPath.empty()) {
				throw runtime_error("Missing input file path");
			}

			/* Auto-detect mode (encode or decode) if not specified */
			if (!arguments.mode.has_value()) {
				const auto extension = arguments.inputPath.extension().string();
				if (extension == ".dpcm" || extension == ".dpcmq") arguments.mode = Arguments::Mode::DECODE_TO_WAV;
				else arguments.mode = Arguments::Mode::ENCODE_TO_DPCM;
			}

			/* Auto-fill output file extension if empty */
			if (arguments.outputPath.empty()) {
				if (arguments.mode == Arguments::Mode::DECODE_TO_WAV) {
					arguments.outputPath = fs::path(arguments.inputPath).concat(".wav");
				}
				else {
					arguments.outputPath = fs::path(arguments.inputPath).replace_extension(".dpcmq");
				}
			}

			return arguments;
		}
		catch (const runtime_error& err) {
			Logger::error(format("Failed to parse command line arguments: {}", err.what()));
			exit(1);
		}
		catch (...) {
			Logger::error("Failed to parse command line arguments: Generic failure");
			exit(1);
		}
	}();

	/* Do the thing */
	try {
		Logger::info("DPCM-HQ Encoder and Decoder v.1.0\n(c) 2026, Vladikcomper\n");

		switch (arguments.mode.value()) {
			case Arguments::Mode::ENCODE_TO_DPCM: {
				Logger::info("Initiating encoding from WAV/PCM to DPCM-HQ...");

				Logger::info(format("Reading input file: {}...", arguments.inputPath.string()));
				auto decodedStream = DecodedStream::readFromFile(arguments.inputPath.string());
				Logger::debug(format("decodedStream = {}", decodedStream.dumpDebugInfo()));

				if (decodedStream.data.size() % 2 != 0) {
					Logger::info("Padding decoded stream to even number of samples");
					decodedStream.data.push_back(0x80);
				}
				if (arguments.forcedSampleRate.has_value()) decodedStream.sampleRate = arguments.forcedSampleRate.value();
				else if (!decodedStream.sampleRate) {
					Logger::warn("Sample rate of input file is not specified, defaulting to 16000 Hz (use --rate to override)");
					decodedStream.sampleRate = 16000;
				}

				Logger::info("Invoking encoder...");
				Encoder::EncodingResult encodingResult;
				const auto k = arguments.k.value_or(0.5f);
				const auto encodeTask = [](const vector<uint8_t>& samples, size_t deltaTableIndex, float k) -> Encoder::EncodingResult {
					return Encoder::encode(samples, deltaTableIndex, k);
				};

				/* If user manually specified delta table, use it */
				if (arguments.deltaTableIndex.has_value()) {
					encodingResult = encodeTask(decodedStream.data, arguments.deltaTableIndex.value(), k);
				}

				/* Otherwise, run encoder against all tables in parallel and guess the best one */
				else {
					array<future<Encoder::EncodingResult>, 3> tasks = {
						async(launch::async, encodeTask, cref(decodedStream.data), 0, k),
						async(launch::async, encodeTask, cref(decodedStream.data), 1, k),
						async(launch::async, encodeTask, cref(decodedStream.data), 2, k),
					};
				    const std::array<Encoder::EncodingResult, 3> results = {
				    	tasks[0].get(), tasks[1].get(), tasks[2].get()
				    };

					Logger::debug(format("candidateResult[0] = {}", results[0].dumpDebugInfo()));
					Logger::debug(format("candidateResult[1] = {}", results[1].dumpDebugInfo()));
					Logger::debug(format("candidateResult[2] = {}", results[2].dumpDebugInfo()));

					/* Select the preferable encoding result (biased) */
					encodingResult = results[0];
					if (encodingResult.rmse.get() > 0.2f) {
						if (results[1].rmse.get() - 1.2f <= encodingResult.rmse.get()) { // table 1 has RMSE bias of -1.2
							encodingResult = results[1];
						}
						if (results[2].rmse.get() - 0.6f <= encodingResult.rmse.get()) { // table 2 has RMSE bias of -0.6
							encodingResult = results[2];
						}
					}
				}

				Logger::debug(format("encodingResult = {}", encodingResult.dumpDebugInfo()));

				const auto encodedStream = EncodedStream {
					.sampleRate = decodedStream.sampleRate,
					.deltaTableIndex = encodingResult.deltaTableIndex,
					.data = encodingResult.data
				};
				Logger::debug(format("encodedStream = {}", encodedStream.dumpDebugInfo()));

				Logger::info(format("Writing to output file: {}...", arguments.outputPath.string()));
				encodedStream.writeToFile(arguments.outputPath.string());
				break;
			}

			case Arguments::Mode::DECODE_TO_WAV: {
				Logger::info("Initiating decoding of DPCM or DPCM-HQ to WAV...");

				if (arguments.deltaTableIndex.has_value()) {
					Logger::warn("-t|--table option has no effect in decode mode");
				}
				if (arguments.k.has_value()) {
					Logger::warn("-k|--k option has no effect in decode mode");
				}

				Logger::info(format("Reading input file: {}...", arguments.inputPath.string()));
				auto encodedStream = EncodedStream::readFromFile(arguments.inputPath.string());
				Logger::debug(format("encodedStream = {}", encodedStream.dumpDebugInfo()));

				if (arguments.forcedSampleRate.has_value()) encodedStream.sampleRate = arguments.forcedSampleRate.value();
				else if (!encodedStream.sampleRate) {
					Logger::warn("Sample rate of input file is not specified, defaulting to 16000 Hz (use --rate to override)");
					encodedStream.sampleRate = 16000;
				}

				Logger::info("Invoking decoder...");
				const auto decodedStream = DecodedStream {
					.sampleRate = encodedStream.sampleRate,
					.data = Decoder::decode(encodedStream.data, encodedStream.deltaTableIndex)
				};
				Logger::debug(format("decodedStream = {}", decodedStream.dumpDebugInfo()));

				Logger::info(format("Writing to output file: {}...", arguments.outputPath.string()));
				decodedStream.writeToFile(arguments.outputPath.string());
				break;
			}

			default:
				throw runtime_error("Unexpected mode value.");
		};
	}
	catch (const runtime_error& err) {
		Logger::error(format("Operation failed: {}", err.what()));
		exit(2);
	}
	catch (...) {
		Logger::error("Operation failed: Generic failure");
		exit(2);
	}

	Logger::info("Operation complete");
	return 0;
}