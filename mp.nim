
import npeg
import tables
import strutils
import math
import os
import sequtils

import biquad

type
  Function = proc(val: float): float


proc newAvg(): Function =
  var vTotal, vCount: float
  return proc(v: float): float =
    vTotal += v
    vCount += 1
    vTotal / vCount

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

proc newInt(): Function =
  var vTot: float
  return proc(v: float): float =
    vTot += v
    v

proc newDiff(): Function =
  var vPrev: float
  return proc(v: float): float =
    result = v - vPrev
    vPrev = v

proc newLp(): Function =
  var biquad = initBiquad(BiquadLowpass, 0.1)
  return proc(v: float): float =
    biquad.run(v)


const funcTable = {
  "avg": newAvg,
  "min": newMin,
  "max": newMax,
  "int": newInt,
  "diff": newDiff,
  "lp": newLp,
}.toTable()


var opTable = {
  "+": proc(a, b: float): float = a + b,
  "-": proc(a, b: float): float = a - b,
  "*": proc(a, b: float): float = a * b,
  "/": proc(a, b: float): float = a / b,
  "^": proc(a, b: float): float = pow(a, b),
}.toTable()


type
  Data = object
    st: seq[float]
    variable: seq[float]
    functions: seq[Function]
    callNum: int


let exprParser = peg(exprs, data: Data):

  S <- *Space

  number <- >(+Digit * ?( '.' * +Digit)) * S:
    data.st.add parseFloat($1)
  
  variable <- '$' * >+Digit * S:
    let n = parseInt($1)
    data.st.add data.variable[n-1]

  call <- >+Alpha * "(" * args * ")":
    if data.functions.len <= data.callNum:
      if $1 in funcTable:
        data.functions.add funcTable[$1]()
      else:
        echo "Unknown function ", $1
        quit 1
    data.st.add data.functions[data.callnum](data.st.pop)
    inc data.callNum

  args <- exp

  parenExp <- ( "(" * exp * ")" ) ^ 0

  uniMinus <- '-' * exp:
    data.st.add(-data.st.pop)

  prefix <- variable | number | call | parenExp | uniMinus

  infix <- >{'+','-'}    * exp ^  1 |
           >{'*','/'}    * exp ^  2 |
           >{'^'}        * exp ^^ 3 :

    let (f2, f1) = (data.st.pop, data.st.pop)
    data.st.add opTable[$1](f1, f2)

  exp <- S * prefix * *infix * S

  exprs <- exp * *( ',' * S * exp) * !1



let inputParser = peg(line, data: Data):
  line <- *@number
  number <- >(+Digit * ?( '.' * +Digit)):
    data.variable.add parseFloat($1)


let expr = paramStr(1)

var data = Data()

for l in lines("/dev/stdin"):

  data.variable.setLen 0
  data.st.setlen 0
  data.callNum = 0

  # TODO: AST instead of reparse for every line
 
  let r = inputParser.match(l, data)

  try:
    let r = exprParser.match(expr, data)
    if r.ok:
      echo data.st.mapIt($it).join(", ")
    else:
      echo "Error parsing expression at: ", expr[r.matchMax .. ^1]
      quit 1
  except:
    echo "booo"
    discard

