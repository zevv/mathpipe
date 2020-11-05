
import npeg
import tables
import strutils
import math
import os
import sequtils

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

const funcTable = {
  "avg": newAvg,
  "min": newMin,
  "max": newMax,
  "int": newInt,
  "diff": newDiff
}.toTable()



var binOps = {
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

  call <- >+Alpha * parenExp:
    if data.functions.len <= data.callNum:
      data.functions.add funcTable[$1]()
    data.st.add data.functions[data.callnum](data.st.pop)
    inc data.callNum

  parenExp <- ( "(" * exp * ")" ) ^ 0

  uniMinus <- '-' * exp:
    data.st.add(-data.st.pop)

  prefix <- variable | number | call | parenExp | uniMinus

  infix <- >{'+','-'}    * exp ^  1 |
           >{'*','/'}    * exp ^  2 |
           >{'^'}        * exp ^^ 3 :

    let (f2, f1) = (data.st.pop, data.st.pop)
    data.st.add binOps[$1](f1, f2)

  exp <- S * prefix * *infix * S

  exprs <- exp * *( ',' * S * exp)



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

  let r = inputParser.match(l, data)
  if r.ok:
    try:
      let r = exprParser.match(expr, data)
      if r.ok:
        echo data.st.mapIt($it).join(", ")
    except:
      discard

