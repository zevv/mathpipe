
mp: mp.nim misc.nim biquad.nim
	nim c -d:release mp.nim

clean:
	rm -f mp
