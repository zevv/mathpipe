import tables
import strutils
import math
import sequtils
import stats

import biquad
import histogram
import types


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
      else: n.kind
    if k != fd.argKinds[i]:
      stdout.write("Type mismatch for " & fd.name & " argument " & $i & ": expected " & $fd.argKinds[i] & ", got " & $k & "\n")
      return false

  return true

# Find a matching function with the given name and argument types

proc findFunc*(name: string, args: openArray[Node]=[]): Func =
  if name notin funcTable:
    raise newException(ValueError, "Unknown function: " & name)
  for fd in funcTable[name]:
    if fd.argsMatch(args):
      return fd.factory()
  let tmp = args.mapIt($it.kind).join(", ")
  raise newException(ValueError, "No matching arguments found for " & name & "(" & tmp & ")")

# Generate function with given name

template def(iname: string, iargKinds: openArray[NodeKind], iretKind: NodeKind, body: untyped) =
  if iname notin funcTable:
    funcTable[iname] = @[]
  funcTable[iname].add FuncDesc(
    name: iname,
    argKinds: @iargKinds,
    retKind: iretKind,
    factory: proc(): Func = body
  )

template defUniOp(iname: string, op: untyped) =
  def iname, [nkFloat], nkFloat:
    return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat)

template defBinOp(iname: string, op: untyped) =
  def iname, [nkFloat, nkFloat], nkFloat:
    return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getFloat, vs[1].getFloat)

template defBinOpInt(iname: string, op: untyped) =
  def iname, [nkFloat, nkFloat], nkFloat:
    return proc(vs: openArray[Node]): Node = newFloat op(vs[0].getInt, vs[1].getInt).float

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
defUniOp "neg", `-`
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
    newFloat vTot

def "int", [nkFloat], nkFloat:
  var vTot: float
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getfloat
    vTot += v
    newFloat vTot

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


def "histogram", [nkFloat], nkFloat:
  var vals: seq[float]
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    vals.add v
    drawHistogram(vals)
    newFloat v

def "histogram", [nkFloat, nkFloat], nkFloat:
  var vals: seq[float]
  return proc(vs: openArray[Node]): Node =
    let v = vs[0].getFloat
    vals.add v
    drawHistogram(vals, vs[1].getFloat)
    newFloat v



