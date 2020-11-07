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
    argKinds: seq[NodeKind]
    factory: proc(): Func

var
  funcTable: Table[string, seq[FuncDesc]]


proc argsMatch(fd: FuncDesc, args: openArray[Node]): bool =

  result = true

  if args.len > fd.argKinds.len:
    return false

  for i, a in args:
    var k = a.kind
    if k == nkVar: k = nkFloat
    if k != fd.argKinds[i]:
      return false

  return true


# Generate function with given name

proc makeFunc*(name: string, args: openArray[Node]=[]): Func =

  if name notin funcTable:
    raise newException(ValueError, "Unknown function: " & name)

  for fd in funcTable[name]:
    if fd.argsMatch(args):
      return fd.factory()
  
  raise newException(ValueError, "No matching arguments found for " & name)


# Generic helper functions

template def(iname: string, iargKinds: openArray[NodeKind], body: untyped) =
  if iname notin funcTable:
    funcTable[iname] = @[]

  funcTable[iname].add FuncDesc(
    name: iname,
    argKinds: @iargKinds,
    factory: proc(): Func = body
  )

template unOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat)
 
template binOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat, vs[1].getFloat)

template binOpInt(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getInt, vs[1].getInt).float


# Regular binary operators
def "+", [nkFloat, nkFloat]: binOp `+`
def "-", [nkFloat, nkFloat]: binOp `-`
def "*", [nkFloat, nkFloat]: binOp `*`
def "/", [nkFloat, nkFloat]: binOp `/`
def "%", [nkFloat, nkFloat]: binOp `mod`
def "^", [nkFloat, nkFloat]: binOp `pow`

# Bit arithmetic
def "&", [nkFloat, nkFloat]: binOpInt `and`
def "and", [nkFloat, nkFloat]: binOpInt `and`
def "|", [nkFloat, nkFloat]: binOpInt `or`
def "or", [nkFloat, nkFloat]: binOpInt `or`
def "xor", [nkFloat, nkFloat]: binOpInt `xor`
def "<<", [nkFloat, nkFloat]: binOpInt `shl`
def "shl", [nkFloat, nkFloat]: binOpInt `shl`
def ">>", [nkFloat, nkFloat]: binOpInt `shr`
def "shr", [nkFloat, nkFloat]: binOpInt `shr`

# Logarithms
def "neg", [nkFloat]: unOp `-`
def "log", [nkFloat, nkFloat]: binOp log
def "log2", [nkFloat]: unOp log2
def "log10", [nkFloat]: unOp log10
def "ln", [nkFloat, nkFloat]: unOp ln
def "exp", [nkFloat, nkFloat]: unOp exp

# Rounding
def "floor", [nkFloat]: unOp floor
def "ceil", [nkFloat]: unOp ceil
def "round", [nkFloat]: unOp round

# Trigonometry
def "cos", [nkFloat]: unOp cos
def "sin", [nkFloat]: unOp cos
def "tan", [nkFloat]: unOp cos
def "atan", [nkFloat]: unOp cos
def "hypot", [nkFloat, nkFloat]: binOp hypot

# String

def "repeat", [nkString, nkFloat]:
  return proc(vs: openArray[Node]): Node =
    let s = vs[0].getString
    let n = vs[1].getInt
    newString s.repeat(n)

def "&", [nkString, nkString]:
  return proc(vs: openArray[Node]): Node =
    newString vs[0].getString & vs[1].getString

# Statistics

def "min", [nkFloat]:
  var vMin = float.high
  return proc(vs: openArray[Node]): Node =
    vMin = min(vMin, vs[0].getfloat)
    newFloat vMin

def "max", [nkFloat]:
  var vMax = float.low
  return proc(vs: openArray[Node]): Node =
    vMax = max(vMax, vs[0].getfloat)
    newFloat vMax

def "mean", [nkFloat]:
  var vTot, n: float
  return proc(vs: openArray[Node]): Node =
    vTot += vs[0].getfloat
    n += 1
    newFloat vTot / n

def "variance", [nkFloat]:
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.variance()

def "stddev", [nkFloat]:
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.standardDeviation()

# Signal processing

def "sum", [nkFloat]:
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "int", [nkFloat]:
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "diff", [nkFloat]:
  var vPrev: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    result = newFloat v - vPrev
    vPrev = v

def "lowpass", [nkFloat]:
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[Node]): Node =
    let alpha = if vs.len >= 2: vs[1].getFloat else: 0.1
    let Q = if vs.len >= 3: vs[2].getFloat else: 0.707
    biquad.config(BiquadLowpass, alpha, Q)
    newFloat biquad.run(vs[0].getFloat)

# Utilities

def "histogram", [nkFloat, nkFloat, nkBool]:
  var vals: seq[float]
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    vals.add v
    let width = if vs.len > 1: vs[1].getFloat else: 4.0
    drawHistogram(vals, width)
    newFloat v


