
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
import types


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
    st.add newFloat parseNumber($1)

  variable <- {'$','%'} * >+Digit:
    st.add Node(kind: nkVar, varIdx: parseInt($1))

  call <- >functionName * ( "(" * args * ")" | args):
    st[^1].fn = findFunc($1, st[^1].args)

  functionName <- Alpha * *Alnum:
    st.add Node(kind: nkCall)

  args <- *(arg * ?"," * S)

  arg <- exp:
    st[^2].args.add st.pop

  uniMinus <- '-' * exp:
    let args = @[st.pop]
    st.add Node(kind: nkCall, fn: findFunc("neg", args), args: args)

  bool <- "true" | "false":
    st.add newBool($0 == "true")

  string <- '"' * >*(1 - '"') * '"':
    st.add newString $1

  atom <- (variable | number | bool | string | call | parenExp | uniMinus) * S

  parenExp <- ( "(" * exp * ")" )                                 ^   0

  binop <- >("|" | "or" | "xor")                            * exp ^   3 |
           >("&" | "and")                                   * exp ^   4 |
           >("+" | "-")                                     * exp ^   8 |
           >("*" | "/" | "%" | "<<" | ">>" | "shl" | "shr") * exp ^   9 |
           >("^")                                           * exp ^^ 10 :

    let (a2, a1) = (st.pop, st.pop)
    let args = @[a1, a2]
    st.add Node(kind: nkCall, fn: findFunc($1, args), args: args)

  exp <- S * atom * *binop * S

  exprs <- exp * *( ',' * S * exp) * !1


# Input parser: finds all numbers in a line

const inputParser = peg line:
  line <- *@>numbers.number


# Evaluate AST tree

proc eval(n: Node, args: seq[float]): Node =
  proc aux(n: Node): Node =
    case n.kind
    of nkVar: newFloat args[n.varIdx-1]
    of nkCall: n.fn(n.args.map(aux))
    else: n
  result = aux(n)


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

  # Parse stdin to find all numbers, and for each line evaluate the
  # expressions

  for l in lines(stdin):
    let r = inputParser.match(l)
    if r.ok:
      let vars = r.captures.mapIt(it.parseNumber)
      echo root.mapIt($it.eval(vars)).join(" ")

main()
