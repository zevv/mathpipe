
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
  Function = proc(val: float): float

  Operator = proc(a, b: float): float

  NodeKind = enum
    nkConst, nkVar, nkCall, nkOp

  Node = ref object
    case kind: NodeKind
    of nkConst:
      val: float
    of nkVar:
      varIdx: int
    of nkCall:
      fn: Function
    of nkOp:
      op: Operator
    else:
      discard
    s: string
    kids: seq[Node]

proc newAvg(): Function =
  var vTot, n: float
  return proc(v: float): float =
    vTot += v
    n += 1
    vTot / n

proc newMin(): Function =
  var vMin = float.high
  return proc(v: float): float =
    vMin = min(vMin, v)
    vMin

proc newMax(): Function =
  var vMax = float.low
  return proc(v: float): float =
    vMax = max(vMax, v)
    vMax

proc newIntegrate(): Function =
  var vTot: float
  return proc(v: float): float =
    vTot += v
    v

proc newDiff(): Function =
  var vPrev: float
  return proc(v: float): float =
    result = v - vPrev
    vPrev = v

proc newLog(): Function =
  return proc(v: float): float =
    ln(v)

proc newLowpass(): Function =
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(v: float): float =
    biquad.run(v)

proc newVariance(): Function =
  # Rolling variance deviation using Welford's algorithm
  var n, mOld, mNew, sOld, sNew: float
  return proc(v: float): float =
    n += 1
    if n == 1:
      mOld = v
      mNew = v
      result = 0
    else:
      mNew = mOld + (v - mOld) / n
      sNew = sOld + (v - mOld) * (v - mNew)
      mOld = mNew
      sOld = sNew
      result = sNew / (n - 1)

proc newStddev(): Function =
  let fnVariance = newVariance()
  return proc(v: float): float =
    sqrt(fnVariance(v))

proc newStddev2(): Function =
  var rs: RunningStat
  return proc(v: float): float =
    rs.push(v)
    return rs.standardDeviation()

proc newHistogram(): Function =
  var vals: seq[float]
  return proc(v: float): float =
    result = v
    vals.add v
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
  "+": proc(a, b: float): float = a + b,
  "-": proc(a, b: float): float = a - b,
  "*": proc(a, b: float): float = a * b,
  "/": proc(a, b: float): float = a / b,
  "%": proc(a, b: float): float = a mod b,
  "^": proc(a, b: float): float = pow(a, b),
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

  args <- exp

  parenExp <- ( "(" * exp * ")" ) ^ 0

  uniMinus <- '-' * exp:
    let a = st.pop
    proc neg(v: float): float = -v
    st.add Node(kind: nkCall, s: "-", fn: neg, kids: @[a])

  prefix <- variable | number | call | parenExp | uniMinus

  infix <- >{'+','-'}     * exp ^  1 |
           >{'*','/','%'} * exp ^  2 |
           >{'^'}         * exp ^^ 3 :

    let (a2, a1) = (st.pop, st.pop)
    st.add Node(kind: nkOp, s: $1, op: opTable[$1], kids: @[a1, a2])

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
    of nkCall:  n.fn(aux(n.kids[0]))
    of nkOp:    n.op(aux(n.kids[0]), aux(n.kids[1]))

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

