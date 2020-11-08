import tables
import strutils
import math
import sequtils
import stats
import macros

import biquad
import histogram
import types
import primmacro


var
  funcTable: Table[string, seq[FuncDesc]]


proc argsMatch(fd: FuncDesc, args: openArray[Node]): bool =
  result = true
  if args.len != fd.argKinds.len:
    return false
  for i, n in args:
    let k = case n.kind:
      of nkCall: n.fd.retKind
      of nkVar: nkFloat
      of nkCol: nkString
      else: n.kind
    if k != fd.argKinds[i]:
      return false
  return true

# Find a matching function with the given name and argument types

proc newCall*(name: string, args: seq[Node]): Node =
  let sig = name & "(" & args.mapIt($it.kind).join(", ") & ")"

  if name notin funcTable:
    raise newException(ValueError, "Unknown function: " & sig)
  for fd in funcTable[name]:
    if fd.argsMatch(args):
      return Node(kind: nkCall, fd: fd, fn: fd.factory(), args: args)

  var err = "No matching arguments found for " & sig & "\n"
  err.add "candidates:\n"
  for fd in funcTable[name]:
    err.add "  " & $fd & "\n"
  raise newException(ValueError, err)

# Generate function with given name

template defUniOp(name: string, op: untyped) =
  prim:
    proc name(a: float): float = op(a)

template defBinOp(name: string, op: untyped) =
  prim:
    proc name(a: float, b: float): float = op(a, b)

template defBinOpInt(name: string, op: untyped) =
  prim:
    proc name(a: float, b: float): float = op(a.int, b.int).float


# Regular binary operators
defBinOp "+", `+`
defBinOp "-", `-`
defBinOp "*", `*`
defBinOp "/", `/`
defBinOp "%", `mod`
defBinOp "^", `pow`

# Bit arithmetic
defBinOpInt "&", `and`
defBinOpInt "and", `and`
defBinOpInt "|", `or`
defBinOpInt "or", `or`
defBinOpInt "xor", `xor`
defBinOpInt "<<", `shl`
defBinOpInt "shl", `shl`
defBinOpInt ">>", `shr`
defBinOpInt "shr", `shr`

# Logarithms
defUniOp "-", `-`
defUniOp "log2", log2
defUniOp "log10", log10
defUniOp "ln", ln
defUniOp "exp", exp
defBinOp "log", log
defBinOp "pow", pow

# Rounding
defUniOp "floor", floor
defUniOp "ceil", ceil
defUniOp "round", round

# Trigonometry
defUniOp "cos", cos
defUniOp "sin", sin
defUniOp "tan", tan
defUniOp "atan", arctan
defUniOp "arctan", arctan
defBinOp "atan2", arctan2
defBinOp "arctan2", arctan2
defBinOp "hypot",  hypot

# String

prim:
  proc repeat(s: string, n: int): string =
    s.repeat(n)

prim:
  proc `&`(a: string, b: string): string = a & b

prim:
  proc len(s: string): float = s.len.float

# Statistics

prim:
  var n = 0.0
  proc count(v: float): float =
    n += 1.0
    n

prim:
  var vMin = float.high
  proc min(v: float): float =
    vMin = min(vMin, v)
    vMin

prim:
  var vMax = float.low
  proc max(v: float): float =
    vMax = max(vMax, v)
    vMax

prim:
  var vTot, n: float
  proc mean(v: float): float =
    vTot += v
    n += 1
    vtot / n

prim:
  var rs: RunningStat
  proc variance(v: float): float =
    rs.push(v)
    rs.variance()

prim:
  var rs: RunningStat
  proc stddev(v: float): float =
    rs.push(v)
    rs.standardDeviation()

# Signal processing

prim:
  var vTot: float
  proc sum(v: float): float =
    vTot += v
    vTot

prim:
  var vTot: float
  proc int(v: float): float =
    vTot += v
    vTot

prim:
  var vPrev: float
  proc diff(v: float): float =
    result = v - vPrev
    vPrev = v

prim:
  var biquad = initBiquad(BiquadLowpass, 0.1)
  proc lowpass(v: float): float =
    biquad.config(BiquadLowpass, 0.1, 0.707)
    biquad.run(v)

prim:
  var biquad = initBiquad(BiquadLowpass, 0.1)
  proc lowpass(v: float, alpha: float): float =
    biquad.config(BiquadLowpass, alpha, 0.707)
    biquad.run(v)

prim:
  var biquad = initBiquad(BiquadLowpass, 0.1)
  proc lowpass(v: float, alpha: float, Q: float): float =
    biquad.config(BiquadLowpass, alpha, Q)
    biquad.run(v)

# Utilities

prim:
  var vals: seq[float]
  proc histogram(v: float): float =
    vals.add v
    drawHistogram(vals)
    v

prim:
  var vals: seq[float]
  proc histogram(v: float, width: float): float =
    vals.add v
    drawHistogram(vals, width)
    v

