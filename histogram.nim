import strformat
import terminal
import stats
import algorithm
import math
import strutils

proc siFmt*(v: SomeNumber, align=false): string =
  
  let f = abs(v.float)

  proc format(s: float, suffix: string): string =
    var fs = ($f)[0..4]
    #fs.trimZeros()
    #if align:
    #  fs = fs.align(5)
    var sign = " "
    if v < 0: sign = "-"
    &"{sign}{fs}{suffix}"

  if f == 0.0:
    format(0, "")
  elif f < 1000e-9:
    format(1e9, "n")
  elif f < 1000e-6:
    format(1e6, "µ")
  elif f < 1000e-3:
    format(1e3, "m")
  elif f < 1000:
    format(1.0, if align: " " else: "")
  elif f < 1000e3:
    format(1e-3, "K")
  elif f < 1000e6:
    format(1e-6, "M")
  else:
    format(1e-9, "G")

   
proc drawHistogram*(vals: openArray[float], width=2.0, log=false) =

  if vals.len <= 1:
    return

  let
    w = terminalWidth() - 10
    h = terminalHeight() - 3
    median = 0.5 * (vals[vals.high div 2] + vals[vals.len div 2])
    stddev = vals.standardDeviation
    bins = min(vals.len, h)
    min = median - stddev * width
    max = median + stddev * width
    binsize = (2 * stddev * width) / bins.float
  if binsize == 0.0:
    return
  var bin = newSeq[float](bins)
  var binMax = 0.0
  for v in vals:
    let idx = int((v - min) / binsize)
    if idx >= 0 and idx < bin.len:
      bin[idx] += 1
      binMax = max(binMax, bin[idx])
  echo "\e[H"
  for i, b in bin:
    let binavg = min + (i.float + 0.5) * binsize
    let l = int(w.float * b / binMax)
    echo siFmt(binAvg, true) & " [" & repeat("■", l) & repeat(" ", w-l) & "]"
