
import npeg
import tables
import strutils
import math
import os
import sequtils
import strformat
import stats
import strutils

import primitives

const debug = false

type

  NodeKind = enum
    nkConst, nkVar, nkCall

  Node = ref object
    case kind: NodeKind
    of nkConst:
      val: float
    of nkVar:
      varIdx: int
    of nkCall:
      fn: Func
    kids: seq[Node]

# Common grammar

proc parseNumber(s: string): float =
  if s.len > 2 and s[1] in {'x','X'}:
    result = s.parseHexInt.float
  else:
    result = s.parseFloat


grammar numbers:

  exponent <- {'e','E'} * ?{'+','-'} * +Digit

  fraction <- '.' * +Digit * ?exponent

  number <- '0' * ({'x','X'} * Xdigit | ?fraction) |
            {'1'..'9'} * *Digit * ?fraction |
            fraction


# Expression -> AST parser

const exprParser = peg(exprs, st: seq[Node]):

  S <- *Space

  number <- >numbers.number:
    st.add Node(kind: nkConst, val: parseNumber($1))

  variable <- {'$','%'} * >+Digit:
    st.add Node(kind: nkVar, varIdx: parseInt($1))

  call <- functionName * ( "(" * args * ")" | args)

  functionName <- Alpha * *Alnum:
    st.add Node(kind: nkCall, fn: makeFunc($0))

  args <- arg * *( "," * S * arg)

  arg <- exp:
    st[^2].kids.add st.pop

  uniMinus <- '-' * exp:
    st.add Node(kind: nkCall, fn: makeFunc("neg"), kids: @[st.pop])

  prefix <- (variable | number | call | parenExp | uniMinus) * S

  parenExp <- ( "(" * exp * ")" )                                 ^   0

  infix <- >("|" | "or" | "xor")                            * exp ^   3 |
           >("&" | "and")                                   * exp ^   4 |
           >("+" | "-")                                     * exp ^   8 |
           >("*" | "/" | "%" | "<<" | ">>" | "shl" | "shr") * exp ^   9 |
           >("^")                                           * exp ^^ 10 :

    let (a2, a1) = (st.pop, st.pop)
    st.add Node(kind: nkCall, fn: makeFunc($1), kids: @[a1, a2])

  exp <- S * prefix * *infix * S

  exprs <- exp * *( ',' * S * exp) * !1


# Input parser: finds all numbers in a line

const inputParser = peg line:
  line <- *@>numbers.number


# Dump AST tree

when debug:
  proc `$`(n: Node, prefix=""): string =
    result.add prefix & $n.kind & " "
    result.add case n.kind
    of nkConst: $n.val
    of nkVar: "$" & $n.varIdx
    else: ""
    result.add "\n"
    for nc in n.kids:
      result.add `$`(nc, prefix & "  ")


# Evaluate AST tree

proc eval(root: Node, args: seq[float]): float =
  proc aux(n: Node): float =
    case n.kind
    of nkConst: n.val
    of nkVar:args[n.varIdx-1]
    of nkCall: n.fn(n.kids.map(aux))
  result = aux(root)


# Main code

proc main() =

  # Parse all expressions from the command line

  var root: seq[Node]
  let expr = commandLineParams().join(" ")
  try:
    let r = exprParser.match(expr, root)
    if not r.ok:
      echo "Error: ", expr
      echo "       " & repeat(" ", r.matchMax) & "^"
      quit 1
  except:
    stderr.write getCurrentExceptionMsg() & "\n"
    quit 1

  when debug:
    for n in root:
      echo n

  # Parse stdin to find all numbers, and for each line evaluate the
  # expressions

  for l in lines(stdin):
    let r = inputParser.match(l)
    if r.ok:
      try:
        let vars = r.captures.mapIt(it.parseNumber)
        proc format(v: float): string = &"{v:g}"
        echo root.mapIt(it.eval(vars).format).join(" ")
      except:
        discard

main()
