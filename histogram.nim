import strformat
import terminal
import stats
import strutils

proc siFmt*(v: SomeNumber, align=false): string =
  
  let f = abs(v.float)

  proc format(s: float, suffix: string): string =
    var fs = &"{f*s:.4g}"
    #fs.trimZeros()
    #if align:
    #  fs = fs.align(5)
    var sign = " "
    if v < 0: sign = "-"
    &"{sign}{fs}{suffix}"

  if f == 0.0:
    format(0, "")
  elif f < 999e-9:
    format(1e9, "n")
  elif f < 999e-6:
    format(1e6, "µ")
  elif f < 999e-3:
    format(1e3, "m")
  elif f < 999:
    format(1.0, if align: " " else: "")
  elif f < 999e3:
    format(1e-3, "K")
  elif f < 999e6:
    format(1e-6, "M")
  else:
    format(1e-9, "G")

   
proc drawHistogram*(vals: openArray[float]) =

  if vals.len <= 1:
    return

  let
    w = terminalWidth() - 10
    h = terminalHeight() - 2
    avg = vals.mean
    stddev = vals.standardDeviation
    width = 4.0
    bins = min(vals.len, h)
    min = avg - stddev * width
    max = avg + stddev * width
    binsize = (max - min) / bins.float
  var bin = newSeq[float](bins)
  var binMax = 0.0
  for v in vals:
    let idx = int((v - min) / binsize)
    bin[idx] += 1
    binMax = max(binMax, bin[idx])
  echo "\e[H"
  for i, b in bin:
    let binavg = min + (i.float + 0.5) * binsize
    let l = int(w.float * b / binMax)
    echo siFmt(binAvg, true) & " [" & repeat("■", l) & repeat(" ", w-l) & "]"
