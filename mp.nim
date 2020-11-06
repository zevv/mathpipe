
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

const

  debug = false

type

  FuncDesc = object
    name: string
    argsMin: int
    argsMax: int
    factory: FuncFactory

  Func = proc(val: openArray[float]): float

  FuncFactory = proc(): Func
  
  NodeKind = enum
    nkConst, nkVar, nkCall

  Node = ref object
    case kind: NodeKind
    of nkConst:
      val: float
    of nkVar:
      varIdx: int
    of nkCall:
      fd: FuncDesc
      fn: Func
    kids: seq[Node]


var funcTable: Table[string, FuncDesc]

template def(funcName: string, body: untyped) =
  let factory = proc(): Func =
    body

  funcTable[funcName] = FuncDesc(
    name: funcName,
    factory: factory,
  )

template unOp(op: untyped) =
  return proc(vs: openArray[float]): float = op(vs[0])
 
template binOp(op: untyped) =
  return proc(vs: openArray[float]): float = op(vs[0], vs[1])

# Primitive operations and functions

def "+", binOp `+`
def "-", binOp `-`
def "*", binOp `*`
def "/", binOp `/`
def "%", binOp `mod`
def "^", binOp `pow`

def "cos", unOp cos
def "sin", unOp cos
def "tan", unOp cos
def "atan", unOp cos
def "hypot", binOp hypot
def "neg": unOp `-`
def "log": binOp log
def "log2": unOp log2
def "log10": unOp log10
def "floor": unOp floor
def "ceil": unOp ceil
def "round": unOp round

# Stateful primitives, implemented as closures

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

def "ln":
  return proc(vs: openArray[float]): float =
    ln(vs[0])

def "lowpass":
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(vs: openArray[float]): float =
    let alpha = if vs.len >= 2: vs[1] else: 0.1
    let Q = if vs.len >= 3: vs[2] else: 0.707
    biquad.config(BiquadLowpass, alpha, Q)
    biquad.run(vs[0])

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

def "stddef":
  var rs: RunningStat
  return proc(vs: openArray[float]): float =
    rs.push(vs[0])
    return rs.standardDeviation()

def "histogram":
  var vals: seq[float]
  return proc(vs: openArray[float]): float =
    result = vs[0]
    vals.add vs[0]
    drawHistogram(vals)


# Dump AST tree

when debug:
  proc `$`(n: Node, prefix=""): string =
    result.add prefix & $n.kind & " "
    result.add case n.kind
    of nkConst: $n.val
    of nkVar: "$" & $n.varIdx
    of nkCall: n.fd.name
    result.add "\n"
    for nc in n.kids:
      result.add `$`(nc, prefix & "  ")


# Evaluate AST tree

proc eval(root: Node, args: seq[float]): float =
  proc aux(n: Node): float =
    case n.kind
    of nkConst: n.val
    of nkVar: args[n.varIdx-1]
    of nkCall: n.fn(n.kids.map(aux))
  result = aux(root)


# Expression -> AST parser

const exprParser = peg(exprs, st: seq[Node]):

  S <- *Space

  number <- >(+Digit * ?( '.' * +Digit)) * S:
    st.add Node(kind: nkConst, val: parseFloat($1))
  
  variable <- {'%','$'} * >+Digit * S:
    st.add Node(kind: nkVar, varIdx: parseInt($1))

  call <- functionName * "(" * args * ")"
  
  functionName <- Alpha * *Alnum:
    let fd = funcTable[$0]
    st.add Node(kind: nkCall, fd: fd, fn: fd.factory())

  args <- arg * *( "," * S * arg)

  arg <- exp:
    st[^2].kids.add st.pop

  uniMinus <- '-' * exp:
    let fd = funcTable["neg"]
    st.add Node(kind: nkCall, fd: fd, fn: fd.factory(), kids: @[st.pop])

  prefix <- variable | number | call | parenExp | uniMinus
  
  parenExp <- ( "(" * exp * ")" ) ^ 0

  infix <- >{'+','-'}     * exp ^  1 |
           >{'*','/','%'} * exp ^  2 |
           >{'^'}         * exp ^^ 3 :

    let fd = funcTable[$1]
    let (a2, a1) = (st.pop, st.pop)
    st.add Node(kind: nkCall, fd: fd, fn: fd.factory(), kids: @[a1, a2])

  exp <- S * prefix * *infix * S

  exprs <- exp * *( ',' * S * exp) * !1


# Input parser: finds numbers in a line

const inputParser = peg line:
  line <- *@number
  number <- >(+Digit * ?( '.' * +Digit))


# Main code

proc main() =

  # Parse all expressions from the command line

  var root: seq[Node]
  for expr in commandLineParams():
    let r = exprParser.match(expr, root)
    if not r.ok:
      echo "Error parsing expression at: ", expr[r.matchMax .. ^1]
      quit 1

  when debug:
    for n in root:
      echo n

  # Parse stdin to find all numbers, and for each line evaluate the
  # expressions

  for l in lines("/dev/stdin"):
    let r = inputParser.match(l)
    if r.ok:
      let vars = r.captures.mapIt(it.parseFloat)
      proc format(v: float): string = &"{v:g}"
      echo root.mapIt(it.eval(vars).format).join(" ")

main()
