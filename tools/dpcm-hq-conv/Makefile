
CXX := g++
CXXFLAGS := -std=c++20 -Wall -Wextra -pedantic-errors

dpcm-hq-conv:	dpcm-hq-conv.cpp
	$(CXX) $(CXXFLAGS) -O2 $< -o $@

dpcm-hq-conv-dbg:	dpcm-hq-conv.cpp
	$(CXX) $(CXXFLAGS) -Og -g -fsanitize=address -fsanitize=leak -fsanitize=undefined $< -o $@

clean:
	rm -f dpcm-hq-conv dpcm-hq-conv-dbg
