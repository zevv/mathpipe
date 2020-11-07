import tables
import strutils
import math
import stats

import biquad
import histogram
import types

type

  FuncDesc = object
    name: string
    args: string
    factory: proc(): Func

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

template unOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat)
 
template binOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat, vs[1].getFloat)

template binOpInt(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getInt, vs[1].getInt).float


# Regular binary operators
def "+": binOp `+`
def "-": binOp `-`
def "*": binOp `*`
def "/": binOp `/`
def "%": binOp `mod`
def "^": binOp `pow`

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

# String

def "repeat":
  return proc(vs: openArray[Node]): Node =
    let s = vs[0].getString
    let n = vs[1].getInt
    newString s.repeat(n)

# Statistics

def "min":
  var vMin = float.high
  return proc(vs: openArray[Node]): Node =
    vMin = min(vMin, vs[0].getfloat)
    newFloat vMin

def "max":
  var vMax = float.low
  return proc(vs: openArray[Node]): Node =
    vMax = max(vMax, vs[0].getfloat)
    newFloat vMax

def "mean":
  var vTot, n: float
  return proc(vs: openArray[Node]): Node =
    vTot += vs[0].getfloat
    n += 1
    newFloat vTot / n

def "variance":
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.variance()

def "stddev":
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.standardDeviation()

# Signal processing

def "sum":
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "int":
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "diff":
  var vPrev: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    result = newFloat v - vPrev
    vPrev = v

def "lowpass":
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[Node]): Node =
    let alpha = if vs.len >= 2: vs[1].getFloat else: 0.1
    let Q = if vs.len >= 3: vs[2].getFloat else: 0.707
    biquad.config(BiquadLowpass, alpha, Q)
    newFloat biquad.run(vs[0].getFloat)

# Utilities

def "histogram":
  var vals: seq[float]
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    vals.add v
    let width = if vs.len > 1: vs[1].getFloat else: 4.0
    drawHistogram(vals, width)
    newFloat v


