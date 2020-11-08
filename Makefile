

mp: mp.nim histogram.nim biquad.nim primitives.nim types.nim primmacro.nim
	nim c mp.nim

clean:
	rm -f mp
