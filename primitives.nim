import tables
import strutils
import math
import stats

import biquad
import histogram
import types


var
  funcTable: Table[string, seq[FuncDesc]]


proc argsMatch(fd: FuncDesc, args: openArray[Node]): bool =

  result = true

  if args.len > fd.argKinds.len:
    return false

  for i, n in args:
    let k = case n.kind:
      of nkCall: n.fd.retKind
      of nkVar: nkFloat
      else: n.kind

    if k != fd.argKinds[i]:
      stdout.write("Type mismatch for " & fd.name & " argument " & $i & ": expected " & $fd.argKinds[i] & ", got " & $k & "\n")
      return false

  return true


# Generate function with given name

proc findFunc*(name: string, args: openArray[Node]=[]): Func =

  if name notin funcTable:
    raise newException(ValueError, "Unknown function: " & name)

  for fd in funcTable[name]:
    if fd.argsMatch(args):
      return fd.factory()
  
  raise newException(ValueError, "No matching arguments found for " & name)


# Generic helper functions

template def(iname: string, iargKinds: openArray[NodeKind], iretKind: NodeKind, body: untyped) =
  if iname notin funcTable:
    funcTable[iname] = @[]

  funcTable[iname].add FuncDesc(
    name: iname,
    argKinds: @iargKinds,
    retKind: iretKind,
    factory: proc(): Func = body
  )

template unOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat)
 
template binOp(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat, vs[1].getFloat)

template binOpInt(op: untyped) =
  return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getInt, vs[1].getInt).float


# Regular binary operators
def "+", [nkFloat, nkFloat], nkFloat: binOp `+`
def "-", [nkFloat, nkFloat], nkFloat: binOp `-`
def "*", [nkFloat, nkFloat], nkFloat: binOp `*`
def "/", [nkFloat, nkFloat], nkFloat: binOp `/`
def "%", [nkFloat, nkFloat], nkFloat: binOp `mod`
def "^", [nkFloat, nkFloat], nkFloat: binOp `pow`

# Bit arithmetic
def "&",   [nkFloat, nkFloat], nkFloat: binOpInt `and`
def "and", [nkFloat, nkFloat], nkFloat: binOpInt `and`
def "|",   [nkFloat, nkFloat], nkFloat: binOpInt `or`
def "or",  [nkFloat, nkFloat], nkFloat: binOpInt `or`
def "xor", [nkFloat, nkFloat], nkFloat: binOpInt `xor`
def "<<",  [nkFloat, nkFloat], nkFloat: binOpInt `shl`
def "shl", [nkFloat, nkFloat], nkFloat: binOpInt `shl`
def ">>",  [nkFloat, nkFloat], nkFloat: binOpInt `shr`
def "shr", [nkFloat, nkFloat], nkFloat: binOpInt `shr`

# Logarithms
def "neg",   [nkFloat], nkFloat: unOp `-`
def "log2",  [nkFloat], nkFloat: unOp log2
def "log10", [nkFloat], nkFloat: unOp log10
def "ln",    [nkFloat], nkFloat: unOp ln
def "exp",   [nkFloat], nkFloat: unOp exp
def "log",   [nkFloat, nkFloat], nkFloat: binOp log
def "pow",   [nkFloat, nkFloat], nkFloat: binOp pow

# Rounding
def "floor", [nkFloat], nkFloat: unOp floor
def "ceil",  [nkFloat], nkFloat: unOp ceil
def "round", [nkFloat], nkFloat: unOp round

# Trigonometry
def "cos",   [nkFloat], nkFloat: unOp cos
def "sin",   [nkFloat], nkFloat: unOp cos
def "tan",   [nkFloat], nkFloat: unOp cos
def "atan",  [nkFloat], nkFloat: unOp cos
def "hypot", [nkFloat, nkFloat], nkFloat: binOp hypot

# String

def "repeat", [nkString, nkFloat], nkString:
  return proc(vs: openArray[Node]): Node =
    let s = vs[0].getString
    let n = vs[1].getInt
    newString s.repeat(n)

def "&", [nkString, nkString], nkString:
  return proc(vs: openArray[Node]): Node =
    newString vs[0].getString & vs[1].getString

# Statistics

def "min", [nkFloat], nkFloat:
  var vMin = float.high
  return proc(vs: openArray[Node]): Node =
    vMin = min(vMin, vs[0].getfloat)
    newFloat vMin

def "max", [nkFloat], nkFloat:
  var vMax = float.low
  return proc(vs: openArray[Node]): Node =
    vMax = max(vMax, vs[0].getfloat)
    newFloat vMax

def "mean", [nkFloat], nkFloat:
  var vTot, n: float
  return proc(vs: openArray[Node]): Node =
    vTot += vs[0].getfloat
    n += 1
    newFloat vTot / n

def "variance", [nkFloat], nkFloat:
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.variance()

def "stddev", [nkFloat], nkFloat:
  var rs: RunningStat
  return proc(vs: openArray[Node]): Node =
    rs.push(vs[0].getfloat)
    newFloat rs.standardDeviation()

# Signal processing

def "sum", [nkFloat], nkFloat:
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "int", [nkFloat], nkFloat:
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat v

def "diff", [nkFloat], nkFloat:
  var vPrev: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    result = newFloat v - vPrev
    vPrev = v

def "lowpass", [nkFloat], nkFloat:
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[Node]): Node =
    let alpha = if vs.len >= 2: vs[1].getFloat else: 0.1
    let Q = if vs.len >= 3: vs[2].getFloat else: 0.707
    biquad.config(BiquadLowpass, alpha, Q)
    newFloat biquad.run(vs[0].getFloat)

# Utilities

def "histogram", [nkFloat, nkFloat, nkBool], nkFloat:
  var vals: seq[float]
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    vals.add v
    let width = if vs.len > 1: vs[1].getFloat else: 4.0
    drawHistogram(vals, width)
    newFloat v


