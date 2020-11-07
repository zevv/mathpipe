import tables

import biquad
import histogram
import strutils
import math
import stats

type

  FuncDesc = object
    name: string
    args: string
    factory: proc(): Func

  Func* = proc(val: openArray[float]): float

var
  funcTable: Table[string, FuncDesc]


# Generate function with given name

proc makeFunc*(name: string): Func =

  if name notin funcTable:
    raise newException(ValueError, "Unknown function: " & name)

  return funcTable[name].factory()


# Generic helper functions

template def(iname: string, body: untyped) =
  funcTable[iname] = FuncDesc(
    name: iname,
    factory: proc(): Func = body
  )

proc asInt(f: float): int =
  result = f.int
  if result.float != f:
    raise newException(ValueError, "Value " & $f & " has no integer representation")

template unOp(op: untyped) =
  return proc(vs: openArray[float]): float = op(vs[0])
 
template binOp(op: untyped) =
  return proc(vs: openArray[float]): float = op(vs[0], vs[1])

template binOpInt(op: untyped) =
  return proc(vs: openArray[float]): float = op(vs[0].asInt, vs[1].asInt).float


# Binary and unary operators

def "+": binOp `+`
def "-": binOp `-`
def "*": binOp `*`
def "/": binOp `/`
def "%": binOp `mod`
def "^": binOp `pow`

# Logarithms
def "neg": unOp `-`
def "log": binOp log
def "log2": unOp log2
def "log10": unOp log10
def "ln": unOp ln
def "exp": unOp exp

# Rounding
def "floor": unOp floor
def "ceil": unOp ceil
def "round": unOp round

# Trigonometry
def "cos", unOp cos
def "sin", unOp cos
def "tan", unOp cos
def "atan", unOp cos
def "hypot", binOp hypot

# Bit arithmetic
def "&", binOpInt `and`
def "and", binOpInt `and`
def "|", binOpInt `or`
def "or", binOpInt `or`
def "xor", binOpInt `xor`
def "<<", binOpInt `shl`
def "shl", binOpInt `shl`
def ">>", binOpInt `shr`
def "shr", binOpInt `shr`


# Statistics

def "min":
  var vMin = float.high
  return proc(vs: openArray[float]): float =
    vMin = min(vMin, vs[0])
    vMin

def "max":
  var vMax = float.low
  return proc(vs: openArray[float]): float =
    vMax = max(vMax, vs[0])
    vMax

def "mean":
  var vTot, n: float
  return proc(vs: openArray[float]): float =
    vTot += vs[0]
    n += 1
    vTot / n

def "variance":
  var rs: RunningStat
  return proc(vs: openArray[float]): float =
    rs.push(vs[0])
    return rs.variance()

def "stddev":
  var rs: RunningStat
  return proc(vs: openArray[float]): float =
    rs.push(vs[0])
    return rs.standardDeviation()

# Signal processing

def "sum":
  var vTot: float
  return proc(vs: openArray[float]): float =
    vTot += vs[0]
    vs[0]

def "int":
  var vTot: float
  return proc(vs: openArray[float]): float =
    vTot += vs[0]
    vs[0]

def "diff":
  var vPrev: float
  return proc(vs: openArray[float]): float =
    result = vs[0] - vPrev
    vPrev = vs[0]

def "lowpass":
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[float]): float =
    let alpha = if vs.len >= 2: vs[1] else: 0.1
    let Q = if vs.len >= 3: vs[2] else: 0.707
    biquad.config(BiquadLowpass, alpha, Q)
    biquad.run(vs[0])

# Utilities

def "histogram":
  var vals: seq[float]
  return proc(vs: openArray[float]): float =
    result = vs[0]
    vals.add vs[0]
    let width = if vs.len > 1: vs[1] else: 4.0
    drawHistogram(vals, width)


