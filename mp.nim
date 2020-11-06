
import npeg
import tables
import strutils
import math
import os
import sequtils
import strformat
import stats

import biquad
import misc

type
  Function = proc(val: openArray[float]): float

  NodeKind = enum
    nkConst, nkVar, nkCall

  Node = ref object
    case kind: NodeKind
    of nkConst:
      val: float
    of nkVar:
      varIdx: int
    of nkCall:
      fn: Function
    else:
      discard
    s: string
    kids: seq[Node]

proc newAvg(): Function =
  var vTot, n: float
  return proc(vs: openArray[float]): float =
    vTot += vs[0]
    n += 1
    vTot / n

proc newMin(): Function =
  var vMin = float.high
  return proc(vs: openArray[float]): float =
    vMin = min(vMin, vs[0])
    vMin

proc newMax(): Function =
  var vMax = float.low
  return proc(vs: openArray[float]): float =
    vMax = max(vMax, vs[0])
    vMax

proc newIntegrate(): Function =
  var vTot: float
  return proc(vs: openArray[float]): float =
    vTot += vs[0]
    vs[0]

proc newDiff(): Function =
  var vPrev: float
  return proc(vs: openArray[float]): float =
    result = vs[0] - vPrev
    vPrev = vs[0]

proc newLog(): Function =
  return proc(vs: openArray[float]): float =
    ln(vs[0])

proc newLowpass(): Function =
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[float]): float =
    echo len(vs)
    biquad.run(vs[0])

proc newVariance(): Function =
  # Rolling variance deviation using Welford's algorithm
  var n, mOld, mNew, sOld, sNew: float
  return proc(vs: openArray[float]): float =
    n += 1
    if n == 1:
      mOld = vs[0]
      mNew = vs[0]
      result = 0
    else:
      mNew = mOld + (vs[0] - mOld) / n
      sNew = sOld + (vs[0] - mOld) * (vs[0] - mNew)
      mOld = mNew
      sOld = sNew
      result = sNew / (n - 1)

proc newStddev(): Function =
  let fnVariance = newVariance()
  return proc(vs: openArray[float]): float =
    sqrt(fnVariance(vs))

proc newStddev2(): Function =
  var rs: RunningStat
  return proc(vs: openArray[float]): float =
    rs.push(vs[0])
    return rs.standardDeviation()

proc newHistogram(): Function =
  var vals: seq[float]
  return proc(vs: openArray[float]): float =
    result = vs[0]
    vals.add vs[0]
    drawHistogram(vals)


const funcTable = {
  "avg": newAvg,
  "min": newMin,
  "max": newMax,
  "integrate": newIntegrate,
  "diff": newDiff,
  "log": newLog,
  "lowpass": newLowpass,
  "stddev": newStddev,
  "stddev2": newStddev2,
  "variance": newVariance,
  "histogram": newHistogram,
}.toTable()


# Operator primitives

var opTable = {
  "+": proc(vs: openArray[float]): float = vs[0] + vs[1],
  "-": proc(vs: openArray[float]): float = vs[0] - vs[1],
  "*": proc(vs: openArray[float]): float = vs[0] * vs[1],
  "/": proc(vs: openArray[float]): float = vs[0] / vs[1],
  "%": proc(vs: openArray[float]): float = vs[0] mod vs[1],
  "^": proc(vs: openArray[float]): float = pow(vs[0], vs[1]),
}.toTable()



proc `$`(n: Node, prefix=""): string =
  result.add prefix & $n.kind & ":" & n.s & "\n"
  for nc in n.kids:
    result.add `$`(nc, prefix & "  ")


# Expression -> AST parser

let exprParser1 = peg(exprs, st: seq[Node]):

  S <- *Space

  number <- >(+Digit * ?( '.' * +Digit)) * S:
    st.add Node(kind: nkConst, s: $1, val: parseFloat($1))
  
  variable <- '$' * >+Digit * S:
    st.add Node(kind: nkVar, s: $1, varIdx: parseInt($1))

  functionName <- Alpha * *Alnum
    
  call <- >functionName * "(" * args * ")":
    let a = st.pop
    st.add Node(kind: nkCall, s: $1, fn: funcTable[$1](), kids: @[a])

  args <- exp * *( "," * S * exp)

  parenExp <- ( "(" * exp * ")" ) ^ 0

  uniMinus <- '-' * exp:
    let a = st.pop
    proc neg(vs: openArray[float]): float = -vs[0]
    st.add Node(kind: nkCall, s: "-", fn: neg, kids: @[a])

  prefix <- variable | number | call | parenExp | uniMinus

  infix <- >{'+','-'}     * exp ^  1 |
           >{'*','/','%'} * exp ^  2 |
           >{'^'}         * exp ^^ 3 :

    let (a2, a1) = (st.pop, st.pop)
    st.add Node(kind: nkCall, s: $1, fn: opTable[$1], kids: @[a1, a2])

  exp <- S * prefix * *infix * S

  exprs <- exp * *( ',' * S * exp) * !1



let inputParser = peg line:
  line <- *@number
  number <- >(+Digit * ?( '.' * +Digit))


# Evaluate AST tree

proc eval(root: Node, args: seq[float]): float =

  proc aux(n: Node): float =
    case n.kind
    of nkConst: n.val
    of nkVar:   args[n.varIdx-1]
    of nkCall:  n.fn(n.kids.map(aux))

  result = aux(root)




let expr = paramStr(1)
var root: seq[Node]
let r = exprParser1.match(expr, root)

if not r.ok:
  echo "Error parsing expression at: ", expr[r.matchMax .. ^1]
  quit 1

for n in root:
  echo n


for l in lines("/dev/stdin"):
  let r = inputParser.match(l)
  if r.ok:
    let vars = r.captures.mapIt(it.parseFloat)
    echo root.mapIt(it.eval(vars)).join(" ")

