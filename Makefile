

mp: mp.nim histogram.nim biquad.nim primitives.nim types.nim
	nim c mp.nim

clean:
	rm -f mp
